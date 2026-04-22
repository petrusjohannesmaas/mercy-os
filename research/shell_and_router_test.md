# Mercy OS — Shell & Router (LangChain + Gemini + MCP)

## 📂 Project Structure
```
apps/
  calculator/
    logic.py        # shared math functions
    gui.py          # GTK frontend (optional)
    mcp_server.py   # FastMCP wrapper (headless)
mercy/
  shell/
    shell.py        # GTK frontend (Mercy Shell)
  router/
    router.py       # LangChain agent (Mercy Router)
  config/
    tools.json      # MCP tool registry
flake.nix
configuration.nix
```

---

## 📝 tools.json (MCP Tool Registry)
```json
[
  {
    "name": "Calculator",
    "binary": "mercy-calculator-mcp",
    "description": "Perform basic math operations"
  },
  {
    "name": "Notes",
    "binary": "mercy-notes-mcp",
    "description": "Create and manage notes"
  }
]
```

This file defines all MCP tools available to the Router.  
Adding a new tool = add one JSON entry, no Router code changes.

---

## 📝 Mercy Shell (GTK Frontend)

`mercy/shell/shell.py`

```python
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib
import router
import threading

class MercyShell(Gtk.Window):
    def __init__(self):
        super().__init__(title="Mercy Shell")
        self.set_default_size(500, 150)
        self.set_border_width(10)

        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(self.vbox)

        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Ask Gemini to use a tool...")
        self.entry.connect("activate", self.on_enter)
        self.vbox.pack_start(self.entry, False, False, 0)

        self.label = Gtk.Label(label="Results will appear here")
        self.label.set_line_wrap(True)
        self.vbox.pack_start(self.label, True, True, 0)

    def on_enter(self, widget):
        query = widget.get_text()
        self.label.set_text("Thinking...")
        self.entry.set_sensitive(False)
        thread = threading.Thread(target=self.process_query, args=(query,))
        thread.start()

    def process_query(self, query):
        try:
            result = router.route(query)
            GLib.idle_add(self.update_ui, result)
        except Exception as e:
            GLib.idle_add(self.update_ui, f"Error: {str(e)}")

    def update_ui(self, result):
        self.label.set_text(result)
        self.entry.set_sensitive(True)
        self.entry.set_text("")

if __name__ == "__main__":
    win = MercyShell()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
```

---

## 📝 Mercy Router (LangChain + Gemini)

`mercy/router/router.py`

```python
import json
import subprocess
import os
from langchain.agents import initialize_agent, Tool
from langchain_google_genai import ChatGoogleGenerativeAI

# Load MCP tools from config
with open("mercy/config/tools.json") as f:
    tool_configs = json.load(f)

def make_tool(config):
    def call_tool(query: str) -> str:
        proc = subprocess.Popen(
            [config["binary"]],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE
        )
        request = json.dumps({"query": query}).encode()
        stdout, _ = proc.communicate(request)
        return stdout.decode()
    return Tool(
        name=config["name"],
        func=call_tool,
        description=config["description"]
    )

tools = [make_tool(cfg) for cfg in tool_configs]

# Initialize Gemini LLM
llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-flash",
    temperature=0,
    google_api_key=os.getenv("GOOGLE_API_KEY")
)

# Structured chat agent for Gemini
agent = initialize_agent(
    tools,
    llm,
    agent="structured-chat-zero-shot-react-description",
    verbose=True
)

def route(query: str) -> str:
    return agent.run(query)
```

---

## 📝 flake.nix

```nix
{
  description = "Mercy OS Shell + Router with Gemini";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system}.mercy-shell = pkgs.python3Packages.buildPythonApplication {
        pname = "mercy-shell";
        version = "0.1.0";
        src = ./mercy/shell;
        propagatedBuildInputs = [
          pkgs.python3Packages.pygobject3
          pkgs.python3Packages.langchain
          pkgs.python3Packages.langchain-google-genai
        ];
        installPhase = ''
          mkdir -p $out/bin
          cp shell.py $out/bin/mercy-shell
          chmod +x $out/bin/mercy-shell
        '';
      };

      packages.${system}.mercy-router = pkgs.python3Packages.buildPythonApplication {
        pname = "mercy-router";
        version = "0.1.0";
        src = ./mercy/router;
        propagatedBuildInputs = [
          pkgs.python3Packages.langchain
          pkgs.python3Packages.langchain-google-genai
        ];
        installPhase = ''
          mkdir -p $out/bin
          cp router.py $out/bin/mercy-router
          chmod +x $out/bin/mercy-router
        '';
      };

      nixosConfigurations.mercy = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          {
            environment.systemPackages = with pkgs; [
              self.packages.${system}.mercy-shell
              self.packages.${system}.mercy-router
            ];
          }
        ];
      };
    };
}
```

---

## 📝 configuration.nix

```nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Gemini API key
  environment.variables.GOOGLE_API_KEY = "set-your-key-here";
}
```

---

## 🔑 Instructions

- Build with Nix flake:  
  ```bash
  nix build .#mercy-shell
  nix build .#mercy-router
  ```

- Set your Gemini API key:  
  ```bash
  export GOOGLE_API_KEY="your-key"
  ```

- Run Shell:  
  ```bash
  mercy-shell
  ```

- Shell → Router → MCP tool → result displayed.

---

### Essence
- **Mercy Shell**: GTK Spotlight‑style frontend.  
- **Mercy Router**: LangChain agent with Gemini, dynamically loads MCP tools from JSON.  
- **MCP Tools**: Headless binaries spawned on demand.  
- **Nix packaging**: Flake builds Shell + Router, with Gemini API key injected via environment.  

