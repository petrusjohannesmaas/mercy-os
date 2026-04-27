# Mercy OS — Test Build Walkthrough

This guide builds the first working end-to-end loop of Mercy OS on your NixOS VM: natural language in, structured tool execution out. By the end, typing "add 2 and 2" into the shell will route through a local Gemma model via llama.cpp, discover the calculator tool, call it over MCP, and display the result.

The shell is a terminal client for this phase — no display server required, runs cleanly over SSH into your KVM VM.

---

## What We're Building

```
Shell (terminal)  →  Router  →  Tool Registry  →  MCP Client  →  Tool  →  Result
                         |
                   Gemma (local, llama.cpp)
```

Two tools to validate the architecture: `calculator` (arithmetic) and `greeter` (string output). If both work without touching the router, the architecture is confirmed.

---

## Project Structure

```
mercy-os/
├── flake.nix
├── configuration.nix
│
├── apps/
│   ├── calculator/
│   │   ├── logic.py
│   │   ├── mcp_server.py
│   │   ├── manifest.json
│   │   └── module.nix
│   └── greeter/
│       ├── logic.py
│       ├── mcp_server.py
│       ├── manifest.json
│       └── module.nix
│
└── core/
    ├── shell/
    │   ├── shell.py
    │   └── module.nix
    ├── router/
    │   ├── router.py
    │   ├── mcp_client.py
    │   └── tool_registry.py
    └── runtime/
        └── model.nix
```

---

## Step 1 — Calculator Tool

### `apps/calculator/logic.py`

```python
def add(a, b): return a + b
def subtract(a, b): return a - b
```

### `apps/calculator/mcp_server.py`

```python
from fastmcp import MCPServer
import logic

server = MCPServer("calculator")

@server.tool()
def add(a: int, b: int) -> int:
    return logic.add(a, b)

@server.tool()
def subtract(a: int, b: int) -> int:
    return logic.subtract(a, b)

if __name__ == "__main__":
    server.run()
```

### `apps/calculator/manifest.json`

```json
{
  "name": "calculator",
  "binary": "mercy-calculator-mcp",
  "description": "Perform arithmetic operations",
  "tools": [
    {
      "name": "add",
      "description": "Add two numbers",
      "input_schema": {
        "type": "object",
        "properties": {
          "a": { "type": "number" },
          "b": { "type": "number" }
        },
        "required": ["a", "b"]
      }
    },
    {
      "name": "subtract",
      "description": "Subtract two numbers",
      "input_schema": {
        "type": "object",
        "properties": {
          "a": { "type": "number" },
          "b": { "type": "number" }
        },
        "required": ["a", "b"]
      }
    }
  ]
}
```

### `apps/calculator/module.nix`

```nix
{ config, pkgs, lib, ... }:

let
  calculatorMcp = pkgs.python3Packages.buildPythonApplication {
    pname = "mercy-calculator-mcp";
    version = "0.1";
    src = ./.;
    propagatedBuildInputs = [ pkgs.python3Packages.fastmcp ];
    installPhase = ''
      mkdir -p $out/bin
      cp mcp_server.py $out/bin/mercy-calculator-mcp
      chmod +x $out/bin/mercy-calculator-mcp
    '';
  };
in {
  options.mercy.tools.calculator.enable =
    lib.mkEnableOption "Mercy calculator tool";

  config = lib.mkIf config.mercy.tools.calculator.enable {
    environment.systemPackages = [ calculatorMcp ];
    environment.etc."mercy/tools/calculator.json".source = ./manifest.json;
  };
}
```

---

## Step 2 — Greeter Tool

The greeter validates that the router selects the correct tool without any changes to routing logic.

### `apps/greeter/logic.py`

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"
```

### `apps/greeter/mcp_server.py`

```python
from fastmcp import MCPServer
import logic

server = MCPServer("greeter")

@server.tool()
def greet(name: str) -> str:
    return logic.greet(name)

if __name__ == "__main__":
    server.run()
```

### `apps/greeter/manifest.json`

```json
{
  "name": "greeter",
  "binary": "mercy-greeter-mcp",
  "description": "Greets a user by name",
  "tools": [
    {
      "name": "greet",
      "description": "Return a greeting for a given name",
      "input_schema": {
        "type": "object",
        "properties": {
          "name": { "type": "string" }
        },
        "required": ["name"]
      }
    }
  ]
}
```

### `apps/greeter/module.nix`

```nix
{ config, pkgs, lib, ... }:

let
  greeterMcp = pkgs.python3Packages.buildPythonApplication {
    pname = "mercy-greeter-mcp";
    version = "0.1";
    src = ./.;
    propagatedBuildInputs = [ pkgs.python3Packages.fastmcp ];
    installPhase = ''
      mkdir -p $out/bin
      cp mcp_server.py $out/bin/mercy-greeter-mcp
      chmod +x $out/bin/mercy-greeter-mcp
    '';
  };
in {
  options.mercy.tools.greeter.enable =
    lib.mkEnableOption "Mercy greeter tool";

  config = lib.mkIf config.mercy.tools.greeter.enable {
    environment.systemPackages = [ greeterMcp ];
    environment.etc."mercy/tools/greeter.json".source = ./manifest.json;
  };
}
```

---

## Step 3 — Core System

### `core/router/tool_registry.py`

```python
import json, os

TOOLS_PATH = "/etc/mercy/tools"

def load_tools():
    tools = []
    for file in os.listdir(TOOLS_PATH):
        if file.endswith(".json"):
            with open(os.path.join(TOOLS_PATH, file)) as f:
                tools.append(json.load(f))
    return tools
```

### `core/router/mcp_client.py`

```python
import subprocess, json

def call(binary, tool, arguments):
    proc = subprocess.Popen(
        [binary],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE
    )
    request = json.dumps({"tool": tool, "arguments": arguments}).encode()
    stdout, _ = proc.communicate(request)
    return json.loads(stdout)
```

### `core/router/router.py`

The router uses `llama-cpp-python` to run a local Gemma model. The model is loaded once at import time. `response_format` with an enum constraint pins the model to only output a tool name that exists in the registry, which is more reliable than prompt-only enforcement — especially important for a small 2B model.

`n_gpu_layers=0` is set explicitly for the test build since the KVM VM runs CPU-only. Update this if you move to hardware with a compatible GPU.

```python
import json
from llama_cpp import Llama
from tool_registry import load_tools
from mcp_client import call

MODEL_PATH = "/etc/mercy/models/gemma.gguf"

llm = Llama(
    model_path=MODEL_PATH,
    n_ctx=2048,
    n_gpu_layers=0,       # CPU-only for KVM VM test build
    chat_format="gemma"
)

tools = load_tools()

def route(query: str):
    messages = [
        {"role": "system", "content": "You are a tool router. Return JSON with 'tool' and 'arguments'."},
        {"role": "user", "content": f"Tools: {json.dumps(tools)}\n\nQuery: {query}"}
    ]

    response = llm.create_chat_completion(
        messages=messages,
        response_format={
            "type": "json_object",
            "schema": {
                "type": "object",
                "properties": {
                    "tool": {"type": "string", "enum": [t["name"] for t in tools]},
                    "arguments": {"type": "object"}
                },
                "required": ["tool", "arguments"]
            }
        },
        temperature=0.0
    )

    decision = json.loads(response["choices"][0]["message"]["content"])

    for t in tools:
        if t["name"] == decision["tool"]:
            return call(t["binary"], decision["tool"], decision["arguments"])

    return "No tool matched."
```

### `core/shell/shell.py`

The shell is a terminal REPL for the test phase — no display server, no GTK dependency. Runs directly over SSH into the VM.

```python
import sys
sys.path.insert(0, "/etc/mercy/core/router")
import router

def main():
    print("Mercy Shell — type 'exit' to quit\n")
    while True:
        try:
            query = input("> ").strip()
            if query.lower() == "exit":
                break
            if not query:
                continue
            result = router.route(query)
            print(result)
        except (KeyboardInterrupt, EOFError):
            break

if __name__ == "__main__":
    main()
```

### `core/shell/module.nix`

```nix
{ config, pkgs, lib, ... }:

let
  mercyShell = pkgs.python3Packages.buildPythonApplication {
    pname = "mercy-shell";
    version = "0.1";
    src = ./.;
    propagatedBuildInputs = [ pkgs.python3Packages.llama-cpp-python ];
    installPhase = ''
      mkdir -p $out/bin
      cp shell.py $out/bin/mercy-shell
      chmod +x $out/bin/mercy-shell
    '';
  };
in {
  options.mercy.core.shell.enable =
    lib.mkEnableOption "Mercy terminal shell";

  config = lib.mkIf config.mercy.core.shell.enable {
    environment.systemPackages = [ mercyShell ];
  };
}
```

---

## Step 4 — Model Module

The model is fetched as a fixed-output derivation and placed at a known system path. The router reads it from there — same pattern as the tool manifests.

Before adding this to your config, get the SHA-256 hash of your GGUF file:

```bash
nix-prefetch-url <your-huggingface-direct-download-url>
```

Paste the result into the `hash` field below.

### `core/runtime/model.nix`

```nix
{ config, pkgs, lib, ... }:

let
  gemmaModel = pkgs.fetchurl {
    url = "https://huggingface.co/<repo>/resolve/main/gemma-4-e2b-it-Q4_K_M.gguf";
    hash = "sha256-<paste-hash-here>";
  };
in {
  options.mercy.runtime.model.enable =
    lib.mkEnableOption "Mercy local Gemma model";

  config = lib.mkIf config.mercy.runtime.model.enable {
    environment.etc."mercy/models/gemma.gguf".source = gemmaModel;
  };
}
```

---

## Step 5 — Nix Configuration

### `flake.nix`

```nix
{
  description = "Mercy OS Test Build";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    nixosConfigurations.mercy = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ ./configuration.nix ];
    };
  };
}
```

### `configuration.nix`

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./apps/calculator/module.nix
    ./apps/greeter/module.nix
    ./core/shell/module.nix
    ./core/runtime/model.nix
  ];

  mercy.tools.calculator.enable = true;
  mercy.tools.greeter.enable = true;
  mercy.core.shell.enable = true;
  mercy.runtime.model.enable = true;

  environment.systemPackages = with pkgs; [
    python3Packages.llama-cpp-python
    python3Packages.fastmcp
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.mercy = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
}
```

Note: `services.xserver` and all GTK/Gemini dependencies are removed. The test build is headless — SSH in and run the shell directly.

---

## Step 6 — Build and Run

```bash
sudo nixos-rebuild switch --flake .#mercy
mercy-shell
```

---

## Expected Behaviour

**Query:** `add 2 and 2`

1. Shell passes query to router
2. Router loads `/etc/mercy/tools/*.json`
3. Gemma responds: `{"tool": "add", "arguments": {"a": 2, "b": 2}}`
4. MCP client spawns `mercy-calculator-mcp`, sends request
5. Shell prints: `4`

**Query:** `greet Alice`

1. Router selects `greeter` — no code changes required
2. Shell prints: `Hello, Alice!`

The second query confirming correct tool selection without router modification is the proof that the architecture works.

---

## Known Limitations (Acceptable for Test Build)

- No streaming
- No retry logic
- `n_gpu_layers=0` — CPU-only inference, expect slower response times
- `chat_format="gemma"` must match the installed version of `llama-cpp-python` — verify on first run
- No schema validation on MCP responses
- Model hash in `model.nix` must be populated manually before build
