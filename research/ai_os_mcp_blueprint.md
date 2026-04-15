# Research Project: Building a Modular AI OS with MCP

This guide outlines the research path for creating a decentralized AI Operating System on Linux. We are moving away from hard-coded functions and toward a **Model Context Protocol (MCP)** architecture.

---

## 1. System Requirements & Logic
We will use **Gemma 2 2B** as the central intelligence and **Dart** for the system services.

### The Stack
* **LLM Engine:** `llama.cpp` (serving GGUF models).
* **Protocol:** MCP (Model Context Protocol).
* **Language:** Dart (for both Host and Server).
* **Database:** SQLite.

---

## 2. Infrastructure Setup

### 2.1 Inference Server
Build `llama.cpp` and start the server with the smallest Gemma model.

```bash
# Build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp && cmake -B build && cmake --build build --config Release -j $(nproc)

# Start the server (Assuming model is in ~/models)
./llama-server -m ~/models/gemma-2-2b-it-Q4_K_M.gguf --port 8080
```

### 2.2 Database Initialization
Prepare the SQLite database manually to prevent "file not found" errors during testing.

```bash
# Create and seed the database
sqlite3 contacts.db "CREATE TABLE contacts (id INTEGER PRIMARY KEY, name TEXT, phone TEXT);"
sqlite3 contacts.db "INSERT INTO contacts (name, phone) VALUES ('Alice', '555-0101');"
sqlite3 contacts.db "INSERT INTO contacts (name, phone) VALUES ('Bob', '555-0202');"
```

> **Gotcha:** Place `contacts.db` in a known, fixed path (e.g. `~/ai-os/apps/contact-book/data/contacts.db`) and reference that absolute path in your server code. If you compile the binary and run it from a different working directory, a relative path like `./contacts.db` will silently create a second empty database in whatever directory you're in, and you'll get empty results with no error.

---

## 3. The 'test-contact-book' (MCP Server)
This application acts as a service provider. It tells the AI what it can do with the database.

### Implementation Logic (contact_server.dart)
Use the `mcp_server` package. You must define "Tools" that describe themselves.

```dart
// Example Tool Definition in the Server
final listContactsTool = Tool(
  name: 'list_contacts',
  description: 'Returns a list of all contact names in the database.',
  inputSchema: {
    'type': 'object',
    'properties': {},
  },
);
```

---

## 4. The 'test-agent' (MCP Host)
This is your main terminal binary. It connects to the servers and manages the conversation with Gemma.

### Discovery Logic
When the agent starts, it performs an MCP handshake with the `contact-server`.
1. It requests the list of tools.
2. It sends these tools to Gemma as part of the system prompt.
3. When Gemma wants to use a tool, the agent executes the call on the server and returns the result.

### 4.1 MCP Configuration

The agent needs to know which MCP servers exist and how to launch them. Rather than hard-coding server paths in your binary, externalise this into a JSON config file that the agent reads on startup. This is what makes future expansion painless — adding a new app means adding one entry to the config, not recompiling the agent.

Create the config file at `~/.config/ai-os/mcp_config.json`:

```json
{
  "mcpServers": {
    "contact-book": {
      "command": "/home/YOUR_USER/ai-os/apps/contact-book/bin/contact-server",
      "args": [],
      "env": {
        "DB_PATH": "/home/YOUR_USER/ai-os/apps/contact-book/data/contacts.db"
      }
    }
  }
}
```

Each key under `mcpServers` is an arbitrary label. `command` is the absolute path to the compiled server binary. Use `env` to pass configuration (like the DB path) instead of baking it into the binary — this keeps each server portable and independently configurable.

In your agent code, load this file at startup and spawn each listed server as a subprocess, then perform the MCP handshake over stdio:

```dart
// Pseudocode: load config and spawn servers
final configFile = File('${Platform.environment['HOME']}/.config/ai-os/mcp_config.json');
final config = jsonDecode(configFile.readAsStringSync());

for (final entry in config['mcpServers'].entries) {
  final process = await Process.start(
    entry.value['command'],
    List<String>.from(entry.value['args'] ?? []),
    environment: Map<String, String>.from(entry.value['env'] ?? {}),
  );
  // Attach MCP stdio transport to process.stdin / process.stdout
}
```

> **Gotcha:** MCP communication happens over **stdio** (stdin/stdout of the spawned subprocess). Make sure your server never writes anything other than valid MCP JSON to stdout — debug `print()` statements will corrupt the protocol stream and cause silent failures. Use stderr for all logging in server code.

> **Gotcha:** Spawn servers with their working directory explicitly set (or use absolute paths everywhere). A server launched by the agent inherits the agent's working directory, which may not be what you expect.

---

## 5. Execution & Testing

### 5.1 Compilation
Compile both components into native Linux binaries.

```bash
# Compile the Server
dart compile exe bin/contact_server.dart -o contact-server

# Compile the Agent
dart compile exe bin/test_agent.dart -o test-agent
sudo mv test-agent /usr/local/bin/
```

> **Gotcha:** `dart compile exe` bundles the Dart runtime, so the output binary is self-contained. However, it is architecture-specific. A binary compiled on `x86_64` will not run on `arm64`. Compile on the target machine.

### 5.2 The "What functions are available?" Test
Run your binary from anywhere in the terminal:

```bash
test-agent
```

**Interaction Flow:**
* **User:** "What functions are available?"
* **Agent:** (Queries MCP Servers for tools...)
* **Gemma:** "I have access to your Contact Book. I can list your contacts, fetch specific phone numbers, or add new entries to your database."

---

## 6. Scalable Folder Structure

To avoid everything accumulating in your home directory, organise the project as follows. This structure separates the agent (the host), individual apps (MCP servers), shared config, models, and data — so adding a new application is always the same process: create a new folder under `apps/`, build its binary into `bin/`, and add one entry to `mcp_config.json`.

```
~/ai-os/
│
├── agent/                        # The test-agent (MCP Host)
│   ├── bin/
│   │   └── test_agent.dart
│   ├── lib/
│   │   └── mcp_client.dart       # MCP client/transport logic
│   └── pubspec.yaml
│
├── apps/                         # One folder per MCP Server application
│   ├── contact-book/
│   │   ├── bin/
│   │   │   └── contact_server.dart
│   │   ├── lib/
│   │   │   └── db.dart
│   │   ├── data/
│   │   │   └── contacts.db       # SQLite database lives here
│   │   └── pubspec.yaml
│   │
│   ├── container-manager/        # Future app (stub)
│   │   ├── bin/
│   │   │   └── container_server.dart
│   │   ├── lib/
│   │   └── pubspec.yaml
│   │
│   └── code-editor/              # Future app (stub)
│       ├── bin/
│       │   └── editor_server.dart
│       ├── lib/
│       └── pubspec.yaml
│
├── build/                        # Compiled binaries land here
│   ├── contact-server
│   ├── container-server
│   └── test-agent
│
├── models/                       # GGUF model files
│   └── gemma-2-2b-it-Q4_K_M.gguf
│
├── scripts/                      # Helper shell scripts
│   ├── build_all.sh              # Compiles all apps + agent
│   └── seed_db.sh                # Creates and seeds databases
│
└── ~/.config/ai-os/              # User config (outside the project tree)
    └── mcp_config.json           # MCP server registry (agent reads this at startup)
```

### build_all.sh (starter template)

```bash
#!/bin/bash
set -e
BASE="$HOME/ai-os"

echo "Building contact-server..."
dart compile exe "$BASE/apps/contact-book/bin/contact_server.dart" \
  -o "$BASE/build/contact-server"

echo "Building test-agent..."
dart compile exe "$BASE/agent/bin/test_agent.dart" \
  -o "$BASE/build/test-agent"

echo "Done. Binaries in $BASE/build/"
```

When you add a new app, add one `dart compile exe` line to this script and one entry to `mcp_config.json`. The agent itself does not change.

---

## 7. Future Expansion
To add the **Container Manager** or **Code Editor**, you simply create a new MCP server under `apps/`. You do not need to rewrite or recompile `test-agent`. Add the new server's compiled binary path to `mcp_config.json` and restart the agent.

---

**References:**
- MCP Specification: https://modelcontextprotocol.io
- Dart MCP SDK: https://pub.dev/packages/mcp_dart