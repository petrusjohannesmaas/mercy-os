# Mercy OS — Application Infrastructure & Dev Workflow

---

## Infrastructure Overview

### Execution Pipeline

```
Mercy Shell  (GTK UI)
      |
Mercy Router  (LLM decision layer)
      |
Tool Registry  (/etc/mercy/tools/*.json)
      |
MCP Client  (stdio JSON)
      |
MCP Tool Binary
      |
Shared Logic  (pure functions)
```

### Repository Structure

```
mercy-os/
├── flake.nix                        # entry point, dependency lock
├── configuration.nix                # machine config, imports all modules
│
├── apps/                            # user-facing tools
│   └── <tool-name>/
│       ├── logic.py                 # pure functions, no I/O
│       ├── mcp_server.py            # MCP wrapper
│       ├── manifest.json            # discovery schema
│       ├── module.nix               # Nix module (build + registration)
│       └── gui.py                   # optional
│
└── core/                            # system logic
    ├── shell/
    │   └── shell.py
    ├── router/
    │   ├── router.py
    │   ├── mcp_client.py
    │   └── tool_registry.py
    └── config/
```

### Key Properties

- Tools are **isolated binaries**, spawned on demand
- Discovery is **declarative via manifests**, not hardcoded
- The router is **tool-agnostic** — it never imports tools directly
- Logic is **reusable** across MCP and GUI layers
- Each tool owns its Nix integration via `module.nix`

---

## Layer Contracts

### 1. Logic layer (`logic.py`)

- Pure functions only
- No I/O, no side effects, no UI
- Deterministic inputs and outputs

### 2. MCP server (`mcp_server.py`)

- Wraps logic functions with MCP decorators
- Accepts structured input, returns structured output
- Stateless — no runtime state between calls

### 3. Manifest (`manifest.json`)

Defines the tool's name, binary, and function schemas for the router to discover.

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
    }
  ]
}
```

### 4. Nix module (`module.nix`)

Self-contained Nix integration. Declares the build, the enable option, and manifest registration. No changes to `flake.nix` internals are required when adding tools.

```nix
{ config, pkgs, lib, ... }:

let
  bin = pkgs.python3Packages.buildPythonApplication {
    pname = "mercy-<tool>-mcp";
    version = "0.1";
    src = ./.;
    propagatedBuildInputs = [ pkgs.python3Packages.fastmcp ];
    installPhase = ''
      mkdir -p $out/bin
      cp mcp_server.py $out/bin/mercy-<tool>-mcp
      chmod +x $out/bin/mercy-<tool>-mcp
    '';
  };
in {
  options.mercy.tools.<tool>.enable = lib.mkEnableOption "Mercy <tool> tool";

  config = lib.mkIf config.mercy.tools.<tool>.enable {
    environment.systemPackages = [ bin ];
    environment.etc."mercy/tools/<tool>.json".source = ./manifest.json;
  };
}
```

---

## Nix Layer Responsibilities

| Layer | File | Responsibility |
|---|---|---|
| Flake | `flake.nix` | Entry point, inputs, exposes `nixosConfigurations` |
| Base config | `configuration.nix` | Imports modules, sets enable flags, machine-specific config |
| Tool module | `apps/<tool>/module.nix` | Builds binary, registers manifest, owns all tool-level Nix logic |

`flake.nix` does not need to be edited when adding a tool. Only `configuration.nix` gains one `imports` line and one `enable = true`.

---

## Dev Workflow (SOP)

### Step 1 — Create the tool folder

```bash
mkdir -p apps/<tool-name>
```

### Step 2 — Write the logic layer

`apps/<tool-name>/logic.py` — pure functions, no dependencies on MCP or UI.

### Step 3 — Write the MCP server

`apps/<tool-name>/mcp_server.py` — wrap logic functions with `@server.tool()` decorators.

### Step 4 — Write the manifest

`apps/<tool-name>/manifest.json` — define tool name, binary name, and input schemas.

### Step 5 — Write the Nix module

`apps/<tool-name>/module.nix` — build the binary, declare the enable option, register the manifest.

### Step 6 — Register in configuration.nix

Add two lines:

```nix
imports = [
  ./apps/<tool-name>/module.nix   # add this
];

mercy.tools.<tool-name>.enable = true;   # add this
```

### Step 7 — Rebuild

```bash
sudo nixos-rebuild switch --flake .#mercy
```

### Step 8 — Test via Shell

```bash
mercy-shell
```

Type a natural language query that should trigger the tool. Verify the result.

---

## Definition of Done

A tool is complete when:

- It appears in `/etc/mercy/tools/`
- The router discovers it without any code changes
- The LLM selects it correctly from a natural language query
- It executes via MCP with structured input and returns structured output
- No files outside `apps/<tool>/` and `configuration.nix` were modified

---

## Anti-Patterns

- Router importing or referencing tool names directly
- Logic embedded in the MCP server layer
- Manual tool registration anywhere in code
- Long-running tool processes
- Stateful tool binaries
- Editing `flake.nix` internals to add a tool
