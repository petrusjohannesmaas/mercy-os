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
    print(response)