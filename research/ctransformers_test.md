Here’s the **bare‑minimum Python snippet** to load and chat with your `tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf` model using **ctransformers**.  

---

### 1. Install dependencies
```bash
pip install ctransformers
```

---

### 2. Minimal chat script
```python
from ctransformers import AutoModelForCausalLM

# Load the quantized GGUF model
llm = AutoModelForCausalLM.from_pretrained(
    "./models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
    model_type="llama"   # backend type; use "llama" for TinyLlama/Gemma/LLaMA family
)

# Simple interactive loop
while True:
    user_input = input("You: ")
    if user_input.strip().lower() in {"quit", "exit"}:
        break
    response = llm(user_input)
    print("AI:", response)
```

---

### 3. Run it
```bash
python chat.py
```

---

### 🔑 Notes
- The `model_type="llama"` argument tells `ctransformers` to use the **llama.cpp backend** under the hood.  
- Your GGUF file must be in the `./models/` folder as you described.  
- This is the **absolute minimum**: no streaming, no parameters. You can later add options like `max_new_tokens`, `temperature`, or streaming callbacks.  
- To stop chatting, type `quit` or `exit`.  