# Mercy OS

Mercy lets an organisation's employees use AI assistants, which Mercy calls agents, on company data and infrastructure. The organisation decides who can use each agent, which data and infrastructure each agent can reach, and what it may do there. Mercy records every request an employee makes and every action an agent takes.

Mercy has four parts of its own: a locked-down operating system, a chat app, a governance server and the agents. It uses a separate identity provider for login. The governance server sits between every employee and every agent.

## Project status

Mercy is under active development and is not ready for production use. The design, the components and the tools behind them will change before the first alpha release, so this README describes what each part does rather than what it is built with.

I post progress updates on [LinkedIn](https://www.linkedin.com/in/petrus-maas/). If you want to talk about the project or contribute, contact me, Petrus Maas, there.

## The problem

Companies want staff to use AI on internal data, such as contracts, policies, support tickets and documentation. They also want staff to use it on internal infrastructure, such as servers, databases, deployments and monitoring. If they give employees a public chatbot or an unmanaged AI tool instead:

- Sensitive data leaves the company with no controls.
- An AI tool with infrastructure access can change systems without anyone approving or recording the change.
- Nobody records what was asked or answered.
- The company cannot say "support may use the ticket agent, but not the finance agent".
- The company cannot choose which model or provider processes its data.

With Mercy, a company can offer AI agents and still answer four questions at any time. Who used an agent? What did they ask? What data and infrastructure did the agent touch, and what did it change? Which policy allowed it?

## What it looks like in use

A single request, end to end:

1. An employee opens Mercy Shell, the chat app on their Mercy OS laptop.
2. They log in with the same single sign-on they use for other company systems.
3. Mercy Shell asks the governance server which agents this person may use. The server returns a list, for example, only the Document Q&A agent.
4. The employee types: *"Summarise the changes to our returns policy this quarter."*
5. Mercy Shell sends the message to the governance server. Mercy Shell never talks to an agent or a model directly.
6. The governance server checks that this person may use Document Q&A, logs the request and passes it to the Document Q&A agent.
7. The agent searches the company's documents for the relevant passages and sends them, with the question, to the AI model.
8. The agent returns the answer to the governance server, which logs it and sends it to the employee.

An infrastructure request follows the same path. An engineer who may use an operations agent asks, *"Why did the billing service restart overnight?"* The governance server checks that the engineer may use that agent and that the agent may read the billing service's logs. The agent reads the logs and answers. If the engineer then asks it to restart the service, policy decides whether the agent may do so. The audit log records the request and the outcome either way.

IT or compliance staff can later open the audit log and see who asked what, when, which agent handled it, and which data and infrastructure it touched.

---

## Architecture

```
Mercy Shell (desktop chat app)
    ↓ single sign-on
Identity provider
    ↓ identity token → internal session token
Governance server
    ├── Identity and authentication
    ├── Policy enforcement
    ├── Audit logging
    ├── Agent registry
    └── Routing (cloud or on-premises models)
        └── Agents
            ├── Company data sources
            └── Company infrastructure
```

Every employee action goes through the governance server. Mercy Shell never contacts a model, an agent, a data source or any infrastructure directly.

---

## Components

### 1. Mercy OS (client image)

Mercy OS is the locked-down operating system on employee laptops. Every laptop runs the same image, and employees cannot change it. Its only job is to run Mercy Shell. It is not a general-purpose computer.

- A CI pipeline builds it from a minimal base image and gives each build a version number.
- The root filesystem mounts read-only at boot.
- It contains no AI logic.
- Updates ship as new images. Rolling back means booting the previous image.
- It isolates applications from each other, following policy set on the governance server.

### 2. Mercy Shell (chat app)

Mercy Shell is a desktop chat app and the only way an employee reaches Mercy.

- It logs the employee in through the identity provider.
- It sends every message to the governance server and never contacts agents, models or infrastructure directly.
- It cannot read or write local files unless an allowlist permits it, and the default allowlist is empty.
- On login, it fetches from the governance server the list of agents the employee may use.

### 3. Identity provider

Mercy does not store or check passwords. A self-hosted identity provider handles login.

- The identity provider owns user credentials and authentication.
- It issues tokens to Mercy Shell. The governance server exchanges these for its own internal session tokens.
- It can connect to the company's existing user directory if the company has one.

### 4. Governance server

Every request passes through the governance server.

- **Identity and authentication.** It validates tokens from the identity provider, issues internal session tokens and manages sessions.
- **Policy enforcement.** It enforces the organisation's rules for which agents each role may use, which data and infrastructure each agent may reach, and which actions each agent may take there. It denies anything a policy does not allow.
- **Audit logging.** It writes every request, answer and agent action to an append-only log.
- **Agent registry.** It lists every approved agent with its version, the roles that may use it and whether it is enabled.
- **Routing.** It passes each request to the right agent and chooses which model provider, cloud or on-premises, that agent uses.

### 5. Agents

Each agent runs as an isolated service. Some agents answer questions from company data. Others read from or act on company infrastructure.

- A CI/CD pipeline builds, versions and registers each agent.
- The governance server sends no requests to an agent until the agent registry lists it and a policy permits it.
- An agent reaches only the data and infrastructure its policy grants.
- Model providers are interchangeable. A company can switch between cloud and on-premises providers without changing Mercy Shell.
- The first agent is Document Q&A. It searches company documents for passages relevant to a question and sends them to the model.
