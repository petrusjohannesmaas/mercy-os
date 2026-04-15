# Research Project: Memory Layer & RAG for the AI OS

This guide is a continuation of the Modular AI OS research project. The scaffold, agent, and contact-book MCP server are assumed to already be in place. This project adds a persistent, semantic memory layer so Gemma can remember context across sessions, reason over your documents, and personalise its behaviour over time.

---

## 1. What We Are Building

A new MCP server — `memory-server` — that acts as the shared long-term memory for the entire AI OS. It sits alongside your other apps, exposes tools the agent and other servers can call, and stores everything in a single sqlite-vec database.

### The Three Namespaces

| Namespace | What gets stored | When it is written |
|---|---|---|
| `conversation` | Summaries of past exchanges | End of each session |
| `document` | Chunked text from files | When a file is added/saved in the code editor |
| `profile` | User preferences and habits | When a preference is detected or stated explicitly |

---

## 2. Stack Additions

No new services. Everything builds on what you already have.

| Component | Role |
|---|---|
| `sqlite-vec` extension | Vector storage and similarity search inside SQLite |
| `llama.cpp /embedding` endpoint | Generates embeddings from text (already running) |
| `memory_server.dart` | New MCP server that wraps both of the above |

### 2.1 Install sqlite-vec

Download the prebuilt shared library for your architecture and place it somewhere stable:

```bash
# Check your architecture first
uname -m  # x86_64 or aarch64

# Download the latest release from https://github.com/asg017/sqlite-vec/releases
# Example for x86_64 Linux:
wget https://github.com/asg017/sqlite-vec/releases/latest/download/sqlite-vec-linux-x86_64.tar.gz
tar -xzf sqlite-vec-linux-x86_64.tar.gz

# Place the shared library in a stable location
mkdir -p ~/ai-os/lib
cp vec0.so ~/ai-os/lib/
```

Load the extension at runtime in your Dart code (do not bake the path into the binary — read it from an env variable):

```dart
db.execute("SELECT load_extension('${Platform.environment['SQLITE_VEC_PATH']}')");
```

Add `SQLITE_VEC_PATH` to the memory server's entry in `mcp_config.json`:

```json
"memory": {
  "command": "/home/YOUR_USER/ai-os/build/memory-server",
  "args": [],
  "env": {
    "DB_PATH": "/home/YOUR_USER/ai-os/apps/memory/data/memory.db",
    "SQLITE_VEC_PATH": "/home/YOUR_USER/ai-os/lib/vec0.so",
    "EMBEDDING_URL": "http://localhost:8080/embedding"
  }
}
```

> **Gotcha:** sqlite-vec must be loaded before any vector operations, every time you open the database connection. If you close and reopen the connection, load the extension again.

---

## 3. Database Setup

```bash
sqlite3 ~/ai-os/apps/memory/data/memory.db "
CREATE TABLE memories (
  id          INTEGER PRIMARY KEY,
  namespace   TEXT NOT NULL,
  source      TEXT,
  content     TEXT NOT NULL,
  embedding   F32_BLOB(768),
  created_at  INTEGER DEFAULT (unixepoch())
);

CREATE INDEX idx_namespace ON memories(namespace);
CREATE INDEX idx_source    ON memories(source);
"
```

> **Note on embedding dimensions:** The dimension `768` above assumes llama.cpp is serving a model with a 768-dimension embedding output. Verify this by calling the `/embedding` endpoint and checking the length of the returned vector. If you later switch models, the dimension may differ and you will need to recreate the table.

---

## 4. The Memory MCP Server

### 4.1 Folder Structure

```
~/ai-os/apps/memory/
├── bin/
│   └── memory_server.dart     # Entry point, MCP tool definitions
├── lib/
│   ├── embedder.dart          # HTTP call to llama.cpp /embedding
│   ├── store.dart             # sqlite-vec read/write
│   └── chunker.dart           # Text splitting for documents
├── data/
│   └── memory.db
└── pubspec.yaml
```

### 4.2 Tools to Expose

Define these four tools in `memory_server.dart`. The agent and other MCP servers will call them.

```dart
// Store any piece of text with a namespace and optional source label
final storeMemoryTool = Tool(
  name: 'store_memory',
  description: 'Embeds and stores a piece of text in the memory database. '
               'Use namespace: conversation, document, or profile.',
  inputSchema: {
    'type': 'object',
    'properties': {
      'content':   {'type': 'string'},
      'namespace': {'type': 'string', 'enum': ['conversation', 'document', 'profile']},
      'source':    {'type': 'string', 'description': 'Session ID, filename, or user'},
    },
    'required': ['content', 'namespace'],
  },
);

// Retrieve the most semantically relevant memories for a given query
final recallRelevantTool = Tool(
  name: 'recall_relevant',
  description: 'Returns the most semantically relevant memories for a query. '
               'Optionally filter by namespace.',
  inputSchema: {
    'type': 'object',
    'properties': {
      'query':     {'type': 'string'},
      'namespace': {'type': 'string'},
      'limit':     {'type': 'integer', 'default': 5},
    },
    'required': ['query'],
  },
);

// Chunk and store an entire document
final storeDocumentTool = Tool(
  name: 'store_document',
  description: 'Splits a document into chunks, embeds each chunk, and stores '
               'them all under the document namespace.',
  inputSchema: {
    'type': 'object',
    'properties': {
      'content':  {'type': 'string', 'description': 'Full document text'},
      'filename': {'type': 'string'},
    },
    'required': ['content', 'filename'],
  },
);

// Delete all memories for a given source (e.g. when a file is deleted)
final forgetSourceTool = Tool(
  name: 'forget_source',
  description: 'Deletes all stored memories associated with a given source.',
  inputSchema: {
    'type': 'object',
    'properties': {
      'source': {'type': 'string'},
    },
    'required': ['source'],
  },
);
```

### 4.3 Embedder Logic

```dart
// lib/embedder.dart
Future<List<double>> embed(String text) async {
  final url = Platform.environment['EMBEDDING_URL']!;
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'content': text}),
  );
  final data = jsonDecode(response.body);
  return List<double>.from(data['embedding']);
}
```

> **Gotcha:** llama.cpp must be running with the `--embedding` flag enabled, otherwise the `/embedding` endpoint returns an error. Add `--embedding` to your llama-server startup command if it is not already there.

### 4.4 Vector Search Logic

```dart
// lib/store.dart — similarity search using sqlite-vec
List<Map> recallRelevant(Database db, List<double> queryVec, {String? namespace, int limit = 5}) {
  final vec = Float32List.fromList(queryVec).buffer.asUint8List();

  final filter = namespace != null ? "AND namespace = '$namespace'" : '';

  return db.select('''
    SELECT content, source, namespace,
           vec_distance_cosine(embedding, ?) AS distance
    FROM memories
    WHERE true $filter
    ORDER BY distance ASC
    LIMIT ?
  ''', [vec, limit]);
}
```

---

## 5. When and How Memory Gets Written

This is the most important design decision. Writing to the vector database has a cost — an HTTP call to llama.cpp for each embedding — so it should be triggered deliberately, not on every token.

### 5.1 Conversation Memory — End of Session

**Trigger:** The user ends the session (types `exit`, closes the terminal, or after a period of inactivity).

**What gets written:** Not the raw transcript. A short summary. Ask Gemma to summarise the session before shutting down:

```
System: Before closing, summarise this conversation in 3-5 sentences, 
focusing on decisions made, topics discussed, and any user preferences revealed.
```

Store that summary under `namespace: conversation`, `source: session_{timestamp}`.

**Why not write every message?** Raw conversation turns are noisy and redundant. Summaries are denser and retrieve better. Writing every message would also hammer the embedding endpoint continuously during a conversation.

### 5.2 Document Knowledge Base — On File Save

**Trigger:** The code editor MCP server detects a file save event (inotify watch on the workspace directory, or an explicit "index this file" command from the user).

**What gets written:** The file is chunked into ~400 token overlapping windows and each chunk is embedded and stored under `namespace: document`, `source: /absolute/path/to/file`.

```dart
// lib/chunker.dart — simple sliding window chunker
List<String> chunkText(String text, {int chunkSize = 400, int overlap = 50}) {
  final words = text.split(' ');
  final chunks = <String>[];
  var i = 0;
  while (i < words.length) {
    chunks.add(words.sublist(i, min(i + chunkSize, words.length)).join(' '));
    i += chunkSize - overlap;
  }
  return chunks;
}
```

Before re-indexing a file, call `forget_source` with the file path to delete the old chunks first. Otherwise you accumulate stale versions.

> **Gotcha:** Index files lazily (on save/change), not eagerly (on every read). Scanning an entire project directory on startup would block the agent and flood the embedding endpoint.

### 5.3 User Profile — On Explicit Statement or Detected Preference

**Trigger:** Two paths.

**Explicit:** The user says something like "always use 2-space indentation" or "I prefer short answers". The agent recognises this as a preference statement and calls `store_memory` with `namespace: profile`, `source: user`.

**Detected:** After a session, as part of the shutdown summary step, also ask Gemma a second pass:

```
System: Did the user reveal any preferences, habits, or constraints about 
how they work? If yes, state each one as a short declarative sentence. 
If no, respond with 'none'.
```

Store each returned sentence as a separate profile memory. Short, discrete statements embed and retrieve better than paragraphs.

> **Gotcha:** Profile memories accumulate over time and may become contradictory ("prefers dark mode" stored twice, or an old preference overridden by a new one). Add a `forget_source` call for `user` before re-writing profile entries from a session, or implement a deduplication step. The simplest approach early on: re-write the entire profile snapshot at the end of each session rather than appending.

---

## 6. How the Agent Uses Memory at Runtime

### 6.1 Session Startup Sequence

```
1. Agent starts
2. Agent calls recall_relevant(query="user preferences and habits", namespace="profile", limit=10)
3. Retrieved profile memories are injected into the system prompt
4. User sends first message
5. Agent calls recall_relevant(query=<user message>, namespace="conversation", limit=5)
6. Retrieved conversation memories are prepended to the context as "previous context"
7. Gemma responds with full personal context available
```

### 6.2 During a Conversation (RAG)

When the user asks something that might be answered by their documents:

```
1. User: "What does the authentication flow look like in my project?"
2. Agent calls recall_relevant(query="authentication flow", namespace="document", limit=5)
3. Retrieved chunks are inserted into the prompt:
   [RELEVANT DOCUMENTS]
   --- auth.dart (chunk 3) ---
   <chunk content>
   [END DOCUMENTS]
4. Gemma answers using both its own knowledge and the retrieved context
```

The agent should decide whether to trigger a document recall based on whether the query seems to reference the user's own work. A simple heuristic: if the message contains words like "my", "our", "the project", "the code", trigger a document recall.

### 6.3 Session Shutdown Sequence

```
1. User types 'exit'
2. Agent prompts Gemma for a conversation summary
3. Agent calls store_memory(content=<summary>, namespace="conversation", source=<session_id>)
4. Agent prompts Gemma for preference extraction
5. Agent calls store_memory for each detected preference (namespace="profile")
6. Agent exits cleanly
```

---

## 7. Folder Structure Update

```
~/ai-os/
├── agent/
├── apps/
│   ├── contact-book/
│   ├── memory/                        ← new
│   │   ├── bin/
│   │   │   └── memory_server.dart
│   │   ├── lib/
│   │   │   ├── embedder.dart
│   │   │   ├── store.dart
│   │   │   └── chunker.dart
│   │   ├── data/
│   │   │   └── memory.db
│   │   └── pubspec.yaml
│   └── code-editor/
├── build/
│   ├── contact-server
│   ├── memory-server                  ← new
│   └── test-agent
├── lib/
│   └── vec0.so                        ← sqlite-vec extension
├── models/
└── scripts/
    ├── build_all.sh                   ← add memory-server compile step
    └── seed_db.sh
```

---

## 8. Testing Sequence

Test each layer in isolation before connecting them.

```bash
# 1. Verify the embedding endpoint is working
curl http://localhost:8080/embedding -d '{"content": "hello world"}' | python3 -m json.tool

# 2. Verify sqlite-vec loads and can store a vector
sqlite3 ~/ai-os/apps/memory/data/memory.db \
  "SELECT load_extension('$HOME/ai-os/lib/vec0.so'); SELECT vec_version();"

# 3. Run the memory server standalone and call store_memory via MCP
./build/memory-server  # then test via MCP handshake

# 4. Run the full agent and verify session startup retrieves profile memories
test-agent
> "What do you remember about me?"
```

---

## 9. Gotchas Summary

| Gotcha | Mitigation |
|---|---|
| llama.cpp not started with `--embedding` | Add flag to startup command; memory server should fail loudly on first embed attempt |
| sqlite-vec not loaded after reconnect | Always load extension immediately after opening DB connection |
| Stale document chunks on file re-index | Call `forget_source` before re-indexing any file |
| Embedding dimension mismatch if model changes | Document the dimension used; recreate the table if switching models |
| Profile memories contradicting each other | Re-write full profile snapshot per session rather than appending |
| Embedding endpoint hammered during indexing | Index on save, not on read; consider a short queue with a delay between chunks |
| `print()` to stdout in server corrupts MCP stream | Use stderr for all logging in memory_server.dart |

---

**References:**
- sqlite-vec: https://github.com/asg017/sqlite-vec
- llama.cpp embedding docs: https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md
- RAG overview: https://arxiv.org/abs/2005.11401
- Previous guide: `ai_os_research.md`