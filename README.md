# Mercy OS

Mercy OS is an immutable, declarative, AI-native operating system designed to turn natural language into real, local actions — without sacrificing control, reproducibility, or security.

Rather than treating AI as an application layer, Mercy OS treats it as the primary interface. A local agent interprets user intent and routes it into isolated, structured tools — creating a system that is both powerful and predictable.

---

## What It Is

Most operating systems expose their capabilities through menus, windows, and file browsers. Mercy OS exposes them through natural language. You describe what you want. The system figures out which tool to call, calls it, and returns the result.

This is not a chatbot wrapper. The AI is the shell.

---

## How It Works

Mercy OS is built around four composable layers:

**Mercy Shell** — a lightweight GTK interface. The user's only interaction point. Accepts natural language input, displays results.

**Mercy Router** — a local daemon powered by an LLM (currently Gemini). Reads available tools, decides which one matches the user's intent, and dispatches a structured call.

**Mercy Tools** — isolated binaries that expose discrete capabilities via the Model Context Protocol (MCP). Each tool is self-contained: its own logic, its own schema, its own Nix module.

**Mercy Workflows** — LangGraph-based pipelines for multi-step tasks that require more than a single tool call. Planned for a later phase.

---

## Key Architecture Decisions

**NixOS as the foundation.** The entire system — OS, tools, dependencies, configuration — is declared in code. Builds are reproducible. There is no configuration drift. Rollback is trivial.

**Nix Modules for tool packaging.** Each tool ships as a self-contained Nix module alongside its Python source. Adding a tool to the system is a single `imports` line. No manual wiring. No global state changes.

**MCP as the tool protocol.** Tools communicate through a structured, schema-enforced interface. The router never calls tool logic directly. This keeps the agent layer decoupled from implementation details and makes tools independently testable.

**Declarative discovery.** Tools register themselves via JSON manifests placed at a known system path. The router discovers them at runtime — no hardcoded tool lists anywhere in the system.

**Strict isolation.** Tools are stateless binaries spawned on demand. They have no access to each other, no persistent runtime, and no knowledge of the agent layer.

---

## Project Status

Currently in **Testing Phase (Q2 2026)** — validating each subsystem in isolation before integration.

| Milestone | Target | Status |
|-----------|--------|--------|
| Testing Phase | Q2 2026 | In progress |
| Alpha — utilitarian distro with agentic dispatch and memory | Q4 2026 | Planned |
| Beta — satisfies the 5 pillars of an agentic OS | Q3 2027 | Planned |
| V1 — stable release | Q1 2028 | Planned |

---

## Repository Structure

```
mercy-os/
├── flake.nix
├── configuration.nix
├── apps/                  # user-facing tools
│   ├── calculator/
│   └── greeter/
└── core/                  # system logic
    ├── shell/
    ├── router/
    └── config/
```

---

## Philosophy

**Fast at the edge** — simple interactions return results immediately, no pipeline overhead.

**Strict at the boundary** — the AI layer and the tool layer are structurally separated. The agent decides; the tool executes. Neither crosses into the other's domain.

**Agentic when necessary** — workflows engage only when the task genuinely requires multi-step reasoning. The default is the simplest path that works.
