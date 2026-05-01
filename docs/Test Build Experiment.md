# MERCY OS — End-to-End Experiment v1.1 (ADK + MCP Native)

> Open ADK Web UI → type prompt → ADK + Gemini decides → calls MCP tool via stdio → returns result
> Built with Nix, pure Python, using ADK's native MCP integration.

---

## 1. Project Structure

```
mercy-os/
│
├── flake.nix
├── configuration.nix
│
├── apps/
│   └── calculator/
│       ├── logic.py
│       ├── mcp_server.py
│       └── gui.py          # optional
│
└── mercy/
    └── agent/
        ├── agent.py
        ├── __init__.py
        └── .env
```

**What's gone vs v1.0:**

* `mercy/router/` — replaced by ADK
* `mercy/shell/` — replaced by `adk web`
* `apps/*/manifest.json` — no longer needed
* `/etc/mercy/tools/` — no longer needed

---

## 2. Calculator Logic

### `apps/calculator/logic.py`

```python
def add(a: int, b: int) -> int:
    return a + b

def subtract(a: int, b: int) -> int:
    return a - b
```

---

## 3. MCP Server

### `apps/calculator/mcp_server.py`

```python
from fastmcp import FastMCP
import logic

mcp = FastMCP("calculator")

@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers."""
    return logic.add(a, b)

@mcp.tool()
def subtract(a: int, b: int) -> int:
    """Subtract b from a."""
    return logic.subtract(a, b)

if __name__ == "__main__":
    mcp.run()
```

---

## 4. ADK Agent

### `mercy/agent/agent.py`

```python
from google.adk.agents import LlmAgent
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams
from mcp import StdioServerParameters

root_agent = LlmAgent(
    model="gemini-flash-latest",
    name="mercy_agent",
    instruction="You are a system agent. Route user requests to the correct tool and return the result.",
    tools=[
        McpToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command="mercy-calculator-mcp",
                    args=[],
                )
            )
        ),
    ],
)
```

### `mercy/agent/__init__.py`

```python
from . import agent
```

### `mercy/agent/.env`

```
GOOGLE_API_KEY="YOUR_API_KEY_HERE"
```

---

## 5. flake.nix

```nix
{
  description = "Mercy OS Experiment v1.1";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = {

      mercy-calculator-mcp = pkgs.python3Packages.buildPythonApplication {
        pname = "mercy-calculator-mcp";
        version = "0.1";
        src = ./apps/calculator;
        propagatedBuildInputs = [ pkgs.python3Packages.fastmcp ];
        installPhase = ''
          mkdir -p $out/bin
          cp mcp_server.py $out/bin/mercy-calculator-mcp
          chmod +x $out/bin/mercy-calculator-mcp
        '';
      };

    };

    nixosConfigurations.mercy = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = with pkgs; [
            self.packages.${system}.mercy-calculator-mcp
            pkgs.python3Packages.google-adk
          ];
        }
      ];
    };
  };
}
```

---

## 6. configuration.nix

```nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  services.xserver.enable = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

API key is managed via `mercy/agent/.env`, not system environment.

---

## How to Run

```fish
# Build system
sudo nixos-rebuild switch --flake .#mercy

# Run agent UI
cd mercy/agent
adk web --port 8000
```

Access at `http://localhost:8000`.

---

## End-to-End Flow

1. You type: `add 3 and 5`
2. ADK Runner receives the message and passes it to the `LlmAgent`
3. Gemini selects the `add` tool from the registered `McpToolset`
4. ADK spawns `mercy-calculator-mcp` as a subprocess over stdio
5. `mcp_server.py` calls `logic.add(3, 5)`
6. Result `8` is returned to ADK, relayed to the UI

---

## Adding Another Tool (e.g. Greeter)

### Files to create

```
apps/greeter/
├── logic.py
└── mcp_server.py
```

### `apps/greeter/logic.py`

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"
```

### `apps/greeter/mcp_server.py`

```python
from fastmcp import FastMCP
import logic

mcp = FastMCP("greeter")

@mcp.tool()
def greet(name: str) -> str:
    """Greet a user by name."""
    return logic.greet(name)

if __name__ == "__main__":
    mcp.run()
```

### Add to `flake.nix`

```nix
mercy-greeter-mcp = pkgs.python3Packages.buildPythonApplication {
  pname = "mercy-greeter-mcp";
  version = "0.1";
  src = ./apps/greeter;
  propagatedBuildInputs = [ pkgs.python3Packages.fastmcp ];
  installPhase = ''
    mkdir -p $out/bin
    cp mcp_server.py $out/bin/mercy-greeter-mcp
    chmod +x $out/bin/mercy-greeter-mcp
  '';
};
```

### Add to `mercy/agent/agent.py`

```python
McpToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command="mercy-greeter-mcp",
            args=[],
        )
    )
),
```

### Rebuild

```fish
sudo nixos-rebuild switch --flake .#mercy
```

---

## Key Point

> Adding a tool = **2 files + 1 flake entry + 1 McpToolset entry**

No router changes. No manifest files. No filesystem registration.

---

## Known Limitations (acceptable for test)

* No streaming
* No retries
* No persistent memory (future roadmap item)
* ADK Web UI is dev-only, not for production

---

## Assessment

### Correct

* ADK owns orchestration — no custom routing logic
* MCP protocol used correctly over stdio
* Tools are isolated binaries, spawned on demand
* Architecture is not a dead end — memory, multi-agent, and TUI layers can be added incrementally

### Removed complexity vs v1.0

* Custom `router.py` (~50 lines of LLM call + JSON parsing) → gone
* `tool_registry.py` (manifest scanning) → gone
* `mcp_client.py` (raw subprocess JSON) → gone
* `manifest.json` per tool → gone
* GTK shell + threading → gone
* `/etc/mercy/tools/` registration → gone
