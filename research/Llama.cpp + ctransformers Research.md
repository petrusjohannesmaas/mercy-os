Let’s walk this **end-to-end**, exactly how you’d do it with **llama.cpp via ctransformers**, keeping it _PoC-simple_ and _realistic_.

I’ll break it into:

1. **Mental model (what the AI is actually doing)**
    
2. **Architecture**
    
3. **Function schema**
    
4. **Prompt design (critical for small models)**
    
5. **Python example with ctransformers**
    
6. **What happens at runtime**
    
7. **Why this works with tiny local models**
    

---

## 1. Mental model: what “Ask Pete” really is

“Ask Pete” is **not** an autonomous agent.

It is:

> A UI + a function router + a text generator

Pete’s job is _not_ to be smart — it’s to:

1. Understand the request
    
2. Choose a function
    
3. Fill in arguments
    
4. Let **your app** do the real work
    

---

## 2. High-level architecture

```
User
 ↓
Ask Pete UI
 ↓
Prompt Builder
 ↓
Local LLM (ctransformers → llama.cpp)
 ↓
JSON Output (validated)
 ↓
Function Executor
 ↓
Notes App
```

No APIs. No internet. No orchestration frameworks.

---

## 3. Define the function Pete is allowed to call

This is _the most important part_.

### Example function registry (Python object)

```python
FUNCTIONS = [
    {
        "name": "notes.create_note",
        "description": "Create a new note in a folder",
        "parameters": {
            "folder": "string",
            "title": "string",
            "content": "string"
        }
    }
]
```

Pete can do **nothing else**.

This is your security boundary.

---

## 4. Prompt design (small-model friendly)

Small models **cannot** infer tool usage magically.  
You must be explicit.

### System prompt

```text
You are Pete, an assistant inside a desktop app.

Your job:
- Choose ONE function from the list.
- Fill in its arguments.
- Output ONLY valid JSON.
- Do NOT explain anything.

If the request cannot be handled, output:
{"function": "none"}

Available functions:
1. notes.create_note(folder, title, content)
```

### User input

```text
Create a new note in my jokes folder with a knock knock joke
```

---

## 5. Python implementation using ctransformers

### 5.1 Load the model

```python
from ctransformers import AutoModelForCausalLM

llm = AutoModelForCausalLM.from_pretrained(
    "phi-2.Q4_K_M.gguf",   # example small model
    model_type="phi",
    max_new_tokens=256,
    temperature=0.1,
    context_length=2048
)
```

Low temperature = better structure, less creativity _in routing_.

---

### 5.2 Build the full prompt

```python
def build_prompt(user_input):
    return f"""
You are Pete, an assistant inside a desktop app.

Rules:
- Choose ONE function
- Output ONLY valid JSON
- No markdown
- No explanations

Available function:
notes.create_note(folder, title, content)

User request:
{user_input}
"""
```

---

### 5.3 Call the model

```python
prompt = build_prompt(
    "Create a new note in my jokes folder with a knock knock joke"
)

raw_output = llm(prompt)
print(raw_output)
```

---

## 6. Expected model output

A _good_ output looks like this:

```json
{
  "function": "notes.create_note",
  "arguments": {
    "folder": "jokes",
    "title": "Knock Knock Joke",
    "content": "Knock knock.\nWho's there?\nBoo.\nBoo who?\nDon't cry, it's just a joke!"
  }
}
```

This is **all you want from the model**.

---

## 7. Validate and execute (never trust the model)

```python
import json

def execute(output):
    data = json.loads(output)

    if data["function"] == "notes.create_note":
        args = data["arguments"]
        create_note(
            folder=args["folder"],
            title=args["title"],
            content=args["content"]
        )
```

Your app handles:

- File system
    
- Folder creation
    
- Errors
    
- Permissions
    

The model never touches the OS.

---

## 8. What actually happens step-by-step

1. User types:
    
    > “Create a new note in my jokes folder with a knock knock joke”
    
2. Pete:
    
    - Recognizes _note creation_
        
    - Extracts:
        
        - folder = jokes
            
        - content = knock knock joke
            
    - Wraps it in JSON
        
3. App:
    
    - Parses JSON
        
    - Calls `notes.create_note(...)`
        
    - Writes the file
        

The model:

- Never opens files
    
- Never decides paths
    
- Never executes code
    

---

## 9. Why this works with llama.cpp + tiny models

### Why routing is easy

- Small vocabulary
    
- Clear intent
    
- Short prompt
    
- Low temperature
    

### Why generation still works

- Joke content is short
    
- No long reasoning
    
- Creativity happens _inside content only_
    

### Why this is stable

- One-shot generation
    
- No agent loops
    
- No tool retries
    
- No hidden state
    

---

## 10. Common failure modes (and fixes)

### ❌ Model adds text

```
Sure! Here's your note:
{
  ...
}
```

**Fix:**  
Add:

```
Output ONLY JSON. Any extra text is invalid.
```

---

### ❌ Model hallucinates function

```
"function": "notes.add_joke"
```

**Fix:**  
Reject and retry with:

```
Invalid function. Choose only from the list.
```

---

### ❌ Content is weak or repetitive

**Fix:**  
Increase temperature _slightly_ (0.2–0.4)  
Keep routing temperature low if you split calls.

---

## 11. Optional upgrade: split routing and content

For better reliability:

1. **Call 1**: Route + arguments (low temp)
    
2. **Call 2**: Generate note content (higher temp)
    

This is still local and fast.

---

## Key takeaway

You’re not building an “AI assistant”.

You’re building:

> **A controlled function dispatcher that happens to use a local language model for intent + text generation**

llama.cpp gives you the engine  
ctransformers gives you ergonomics  
Your app remains fully in control

---

If you want, next we can:

- Add **multiple apps** (calendar + notes + files)
    
- Add **confirmation steps**
    
- Add **multi-step requests**
    
- Harden JSON reliability for tiny models
    
- Compare **Phi-2 vs Qwen vs TinyLLaMA** for this exact use case
    

Just tell me where you want to go next.