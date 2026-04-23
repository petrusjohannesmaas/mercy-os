# Mercy OS — Test Build Walkthrough

This guide builds the first working end-to-end loop of Mercy OS on your NixOS VM: natural language in, structured tool execution out. By the end, typing "add 2 and 2" into the shell will route through an LLM, discover the calculator tool, call it over MCP, and display the result.

---

## What We're Building

```
Shell  →  Router  →  Tool Registry  →  MCP Client  →  Calculator  →  Result
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
    │   └── shell.py
    └── router/
        ├── router.py
        ├── mcp_client.py
        └── tool_registry.py
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

```python
import json, os
from tool_registry import load_tools
from mcp_client import call
from langchain_google_genai import ChatGoogleGenerativeAI

tools = load_tools()

llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-flash",
    temperature=0,
    google_api_key=os.getenv("GOOGLE_API_KEY")
)

def route(query: str):
    prompt = f"""
You are a system router.

Available tools:
{json.dumps(tools, indent=2)}

User query: {query}

Respond ONLY in JSON:
{{"tool": "...", "arguments": {{...}}}}
"""
    decision = json.loads(llm.invoke(prompt).content)

    for t in tools:
        if t["name"] == decision["tool"]:
            return call(t["binary"], decision["tool"], decision["arguments"])

    return "No valid tool found."
```

### `core/shell/shell.py`

```python
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib
import threading, sys
sys.path.insert(0, "/etc/mercy/core/router")
import router

class Shell(Gtk.Window):
    def __init__(self):
        super().__init__(title="Mercy Shell")
        self.set_default_size(400, 150)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(box)

        self.entry = Gtk.Entry()
        self.entry.connect("activate", self.on_enter)
        box.pack_start(self.entry, False, False, 0)

        self.label = Gtk.Label(label="Ready")
        box.pack_start(self.label, True, True, 0)

    def on_enter(self, widget):
        query = widget.get_text()
        self.label.set_text("Thinking...")
        threading.Thread(target=self.run, args=(query,), daemon=True).start()

    def run(self, query):
        result = router.route(query)
        GLib.idle_add(self.label.set_text, str(result))

win = Shell()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
```

---

## Step 4 — Nix Configuration

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
  ];

  mercy.tools.calculator.enable = true;
  mercy.tools.greeter.enable = true;

  services.xserver.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.enable = true;

  environment.variables.GOOGLE_API_KEY = "YOUR_API_KEY_HERE";

  environment.systemPackages = with pkgs; [
    python3Packages.pygobject3
    python3Packages.langchain
    python3Packages.langchain-google-genai
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

---

## Step 5 — Build and Run

```bash
sudo nixos-rebuild switch --flake .#mercy
mercy-shell
```

---

## Expected Behaviour

**Query:** `add 2 and 2`

1. Shell sends query to router
2. Router loads `/etc/mercy/tools/*.json`
3. LLM responds: `{"tool": "add", "arguments": {"a": 2, "b": 2}}`
4. MCP client spawns `mercy-calculator-mcp`, sends request
5. Shell displays: `4`

**Query:** `greet Alice`

1. Router selects `greeter` — no code changes required
2. Shell displays: `Hello, Alice!`

The second query confirming correct tool selection without router modification is the proof that the architecture works.

---

## Known Limitations (Acceptable for Test Build)

- No streaming
- No retry logic
- LLM prompt is minimal — will need hardening for ambiguous queries
- No schema validation on MCP responses
- `GOOGLE_API_KEY` set as a plain environment variable
