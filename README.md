# MERCY OS

Mercy OS is an immutable, declarative, AI-native operating system designed to turn natural language into real, local actions—without sacrificing control, security, or reproducibility.

Instead of treating AI as just another application, Mercy OS treats it as a first-class interface layer. A secure local agent interprets user intent and routes it into isolated tools and structured workflows, creating a system that feels both powerful and predictable.

## Core Components (Mental Model)

Mercy OS is built around four simple, composable parts:

-   Mercy Shell – GTK-based frontend (Spotlight / Run-style interface)    
-   Mercy Router – local daemon that classifies intent and routes requests
-   Mercy Tools – isolated, MCP-capable apps/containers exposing capabilities
-   Mercy Workflows – LangGraph-based pipelines for multi-step tasks

## Extended Architecture

Under the hood, these components are supported by a more structured system:

-   Immutable Base OS – minimal, reproducible, image-based foundation
-   Agent Runtime – LLM-powered reasoning layer (LangChain / LangGraph)
-   MCP Interface Layer – standardized protocol for tool discovery and execution
-   Container Runtime – rootless Podman for isolating tools and agents
-   Message Bus / IPC – communication layer between components (sockets, pub/sub, etc.)
-   Config & State Layer – persistent configs and runtime data (`/var`, user config)
-   Security Boundary – strict separation between AI, tools, and the base system


## Philosophy

Mercy OS follows three core principles:

-   **Fast at the edge**: immediate responses for simple interactions
-   **Strict at the boundary**: strong isolation between system and AI
-   **Agentic when necessary**: workflows only when the problem requires it

## Roadmap

### Testing Phase Q2 2026
**Goal:** Explore and validate each subsystem in isolation gaining insight into their behavior, capabilities, and limitations before moving toward integration.

1. Test local AI ✓
2. Build function dispatcher ✓
3. Test UI Frameworks ✓
	1. Test and demo GTK ✓
	2. Test and demo Dart & Flutter on Linux ✓
4. Test MCP
	1. Test existing MCP servers & clients ✓
	2. Build and test custom MCP server 
	3. Build and test custom MCP client
5. Test memory layer
	1. Test vector database with embedded models
	2. Test RAG system
6. Test agent frameworks
	1. Test Langchain
	2. Test LangGraph
	3. Build and test custom agent framework
7. Working test build
	1. Roll all test findings into a working test build
	2. Create a functional agent for the test build
	3. Add a persistent memory system to the test build

### Alpha Goal Q4 2026
**Goal:** A customizable, utilitarian Linux distro with bespoke productivity apps, agentic function dispatching and persistent memory.

### Beta Goal Q3 2027
**Goal:** Fully satisfied the 5 pillars of an agentic operating system

### V1 Goal Q1 2028
**Goal:** A Stable Release with Bespoke Productivity Apps, Agentic Function Dispatching, Persistent Memory and Advanced Security Features