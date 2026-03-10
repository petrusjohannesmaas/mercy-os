from ctransformers import AutoModelForCausalLM

# --- Config ---
MODEL_ID   = "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF"
MODEL_FILE = "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"  # ~700MB, good quality/speed tradeoff
PROMPT     = "What is a function dispatcher in software?"

# --- Load model (downloads automatically on first run) ---
print("Loading model... (first run will download ~700MB)")
llm = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    model_file=MODEL_FILE,
    model_type="llama",
    max_new_tokens=256,
    temperature=0.7,
    context_length=2048,
    threads=4,        # safe for i5; increase to 6-8 if you have more cores free
)

# --- Run prompt ---
print(f"\nPrompt: {PROMPT}")
print("\nResponse:")
print("-" * 40)

output = llm(PROMPT)
print(output)

print("-" * 40)
print("\nTest complete.")