import json
from ctransformers import AutoModelForCausalLM

model = AutoModelForCausalLM.from_pretrained(
    "models",
    model_file="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
    model_type="llama",
)

prompt = """
<|system|>
You are an API that ONLY returns valid JSON.
</s>
<|user|>
Return a JSON object with:
- name
- occupation
- country
</s>
<|assistant|>
"""

response = model(prompt, max_new_tokens=120)

print("Raw model output:")
print(response)

try:
    parsed = json.loads(response)
    print("\nParsed JSON:")
    print(parsed)
except Exception as e:
    print("\nJSON parsing failed:", e)