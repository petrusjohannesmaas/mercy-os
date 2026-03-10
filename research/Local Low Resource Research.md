Below I’ll break this down into **practical options you can use right now**, from _no-LLM_ → _very lightweight local models_, and how each supports **agentic function execution**.

---

## First: clarify what “agentic” means in your PoC

Before choosing a model, it helps to be precise. Most agentic systems need only **three capabilities**:

1. **Intent recognition**
    
    - “Which app / function should handle this request?”
        
2. **Parameter extraction**
    
    - “What arguments does that function need?”
        
3. **Control flow**
    
    - “Call function → observe result → maybe call another function”
        

You do **not** need:

- Reasoning chains
    
- Planning trees
    
- Tool-use benchmarks
    
- Large models
    

For a PoC, you can fake or simplify 80% of “agent intelligence”.

---

## Option 1: No LLM at all (Rule-based + function registry)

This is the _fastest_ and most robust PoC.

### How it works

- Each app exposes:
    
    ```json
    {
      "name": "calendar.create_event",
      "description": "Create a calendar event",
      "parameters": ["date", "time", "title"]
    }
    ```
    
- You maintain:
    
    - Keyword rules
        
    - Regex patterns
        
    - Simple intent maps
        

### Example

```python
if "meeting" in user_input and "calendar" in user_input:
    call("calendar.create_event", params)
```

### Why this is valuable

- You validate:
    
    - App boundaries
        
    - Function schemas
        
    - Security model
        
    - Execution flow
        
- Later, you can _drop an LLM in_ without changing the architecture.
    

### When this is enough

- 3–5 apps
    
- Narrow command vocabulary
    
- Internal PoC
    

⚠️ Downsides:

- Brittle
    
- Not “AI-feeling”
    
- Hard to scale past PoC
    

---

## Option 2: Tiny local models (CPU-friendly, no Ollama)

If you want _some_ natural language flexibility but minimal infra.

### Model families to look at

These can run via:

- `llama.cpp`
    
- `ctransformers`
    
- `ggml / gguf` binaries
    
- Even raw ONNX in some cases
    

**Good candidates (1–3B range):**

- TinyLLaMA
    
- Phi-2 (very strong for size)
    
- Qwen 1.8B
    
- GPT-Neo 1.3B
    

These:

- Run on CPU
    
- Use <4GB RAM (quantized)
    
- Don’t require GPUs
    
- Don’t require Ollama specifically
    

### Agentic pattern to use

Instead of full agents, do **function classification**:

Prompt:

```
You are a router.
Choose ONE function from the list.
Return JSON only.

Functions:
- notes.create(text)
- calendar.create_event(date, time, title)
- files.search(query)

User request:
"Schedule a meeting tomorrow at 2pm"
```

Output:

```json
{
  "function": "calendar.create_event",
  "arguments": {
    "date": "2026-01-14",
    "time": "14:00",
    "title": "Meeting"
  }
}
```

### Why this works

- No planning
    
- No looping
    
- Deterministic structure
    
- Easy to validate JSON
    

⚠️ Downsides:

- Still some setup friction
    
- Prompt sensitivity
    
- Slower than rules
    

---

## Option 3: Hybrid approach (Rules + tiny model)

This is often the _sweet spot_ for PoCs.

### Architecture

1. **Rules first**
    
    - If confident → call function immediately
        
2. **LLM fallback**
    
    - Only when intent unclear
        
3. **Strict output schema**
    
    - Reject anything that doesn’t validate
        

### Benefits

- Fast
    
- Cheap
    
- More reliable than “LLM-only”
    
- Easier to debug
    

This also mirrors how _real production systems_ often work.

---

## Option 4: Classical NLP (no transformers)

Very underrated for PoCs.

### Tools

- spaCy
    
- NLTK
    
- scikit-learn (TF-IDF + classifier)
    

### What you can do

- Intent classification
    
- Entity extraction
    
- Slot filling
    

### Example

- Train a classifier:
    
    - Input: user text
        
    - Output: function name
        
- Use regex or NER for parameters
    

### Why consider this

- Tiny footprint
    
- Deterministic
    
- No hallucinations
    
- Zero “AI magic”, but very solid
    

⚠️ Downsides:

- Less flexible language
    
- More upfront work
    

---

## Option 5: “Fake agent” orchestration (state machine)

You can simulate agent behavior without any model:

```text
STATE: WAIT_FOR_INPUT
→ CLASSIFY_INTENT
→ CALL_FUNCTION
→ HANDLE_RESPONSE
→ ASK_FOLLOWUP (optional)
```

Each step is code, not inference.

This is **excellent** for validating:

- Multi-step flows
    
- App-to-app handoffs
    
- Error recovery
    

Later, an LLM can _replace only one state_.

---

## What I would recommend for _your_ PoC

Given:

- 3–5 apps
    
- Local only
    
- No APIs
    
- Limited resources
    

### Best starting stack

**Phase 1**

- Function registry (JSON schemas)
    
- Rule-based router
    
- Deterministic executor
    

**Phase 2**

- Add a tiny local model _only_ for:
    
    - Intent routing
        
    - Argument extraction
        

**Phase 3**

- Optional: simple loop for multi-step tasks
    

This keeps your PoC:

- Lightweight
    
- Honest about constraints
    
- Easy to evolve
    

---

## Key takeaway

You don’t need “agents” yet.

What you really need is:

> **A clean function interface + a decision layer**

Once that exists, _any_ intelligence (rules, classical NLP, tiny LLM, or future API) can slot in.

If you want, next we can:

- Sketch a **reference architecture**
    
- Design a **function schema standard**
    
- Pick a **specific tiny model + runtime**
    
- Or map this to your preferred language (Python, JS, etc.)