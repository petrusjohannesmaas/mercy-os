# Mercy OS – GUI + MCP Tool Pattern

## 📂 Folder Structure
```
apps/
  calculator/
    logic.py        # shared math functions
    gui.py          # GTK frontend (optional)
    mcp_server.py   # FastMCP wrapper (headless)
flake.nix
configuration.nix
```

---

## 📝 logic.py
```python
def add(a, b): return a + b
def subtract(a, b): return a - b
```

---

## 📝 gui.py
```python
import gi, logic
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

class CalculatorWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Calculator")
        button = Gtk.Button(label="2 + 2")
        button.connect("clicked", self.on_click)
        self.add(button)

    def on_click(self, widget):
        print("Result:", logic.add(2, 2))

if __name__ == "__main__":
    win = CalculatorWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
```

---

## 📝 mcp_server.py
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
    server.run()  # headless, no GUI
```

---

## 📝 flake.nix
```nix
{
  description = "Mercy OS with GUI + MCP apps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05"; # stable base
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system} = {
        mercy-calculator-gui = pkgs.python3Packages.buildPythonApplication {
          pname = "mercy-calculator-gui";
          version = "0.1.0";
          src = ./apps/calculator;
          propagatedBuildInputs = [ pkgs.gtk3 pkgs.python3Packages.pygobject3 ];
          installPhase = ''
            mkdir -p $out/bin
            cp gui.py $out/bin/mercy-calculator-gui
            chmod +x $out/bin/mercy-calculator-gui
          '';
        };

        mercy-calculator-mcp = pkgs.python3Packages.buildPythonApplication {
          pname = "mercy-calculator-mcp";
          version = "0.1.0";
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
              self.packages.${system}.mercy-calculator-gui
              self.packages.${system}.mercy-calculator-mcp
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

  # No systemd service here — MCP tools are spawned on demand
}
```

---

## 📝 Router Stub (Python)
```python
import subprocess, json

def call_tool(tool, args):
    proc = subprocess.Popen(
        ["mercy-calculator-mcp"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE
    )
    request = json.dumps({"tool": tool, "arguments": args}).encode()
    stdout, _ = proc.communicate(request)
    return json.loads(stdout)

# Example usage
result = call_tool("add", {"a": 2, "b": 2})
print("Result:", result["result"])
```

---

## 🔑 Key Points
- **GUI app** (`mercy-calculator-gui`) → user launches manually.  
- **MCP app** (`mercy-calculator-mcp`) → Router spawns headlessly when needed.  
- **Shared logic** → both entry points import `logic.py`.  
- **No systemd service** → tools run only on demand, not always‑on.  

---

This structure gives you exactly what you want: **apps usable as GUI frontends or headless MCP tools**, with the Router spawning them only when an agent needs them.  

