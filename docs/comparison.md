# AgentFlow vs Alternatives

> A detailed comparison of AI-powered software development tools. How AgentFlow's Kanban-orchestrated pipeline compares to CLI-based, prompt-based, and desktop-based approaches.

## Overview

| Tool | Approach | Orchestration | Observability | Quality Gates |
|------|----------|---------------|---------------|---------------|
| **AgentFlow** | Kanban-as-state-machine | PM tool (Asana/Linear/Jira) | Full (phone, web, desktop) | Deterministic + adversarial AI |
| **GSD** | CLI wave executor | Terminal commands | Terminal only | None built-in |
| **Superpowers** | Methodology-as-prompt | CLAUDE.md file | File-based | Prompt-driven |
| **Aperant** | Desktop agent manager | Electron app + SQLite | Desktop app only | None built-in |
| **oh-my-claudecode** | Specialized agent library | 32 agents via skills | Terminal + file-based | Agent-specific |
| **Vibe Kanban** | Kanban + coding agents | Standalone product | Web UI | Built-in (product-specific) |

## Detailed Comparison

### Orchestration Layer

**AgentFlow** uses your existing project management tool as the distributed state machine. Tasks are Kanban cards. Stages are columns. Agent communication happens through comments. This means:
- State survives crashes (lives in Asana/Linear, not in memory)
- Humans intervene by dragging cards
- Pipeline monitoring from any device including mobile
- No custom infrastructure to maintain

**GSD** uses wave-based CLI execution. You define waves of tasks in configuration, and GSD executes them sequentially or in parallel. State lives in the terminal session.

**Superpowers** uses a methodology-as-prompt approach via CLAUDE.md. The "orchestration" is the AI following instructions in a markdown file. State lives in the local filesystem.

**Aperant** uses an Electron desktop app with SQLite for state management. Agents are managed through a GUI. State lives in the local database.

**oh-my-claudecode** provides a library of 32 specialized agents (code review, refactoring, testing, documentation, etc.) as Claude Code skills. There is no central orchestrator -- you invoke individual agents as needed. State is managed per-agent in the filesystem.

**Vibe Kanban** is a standalone product that combines a kanban board with AI coding agents. It provides its own web UI for task management and agent monitoring. It is a hosted/self-hosted product rather than an open framework.

### Quality & Safety

**AgentFlow** implements a multi-layer quality system:
1. Deterministic gates (tsc + eslint + tests) run BEFORE AI review — catches ~60% of issues at near-zero cost
2. Adversarial AI review with mandatory issue-finding ("list 3 things wrong before passing")
3. Coverage gates (80% on new files)
4. Integration testing on main after every merge
5. Automatic revert on integration failure (new commit, never force-push)
6. Scope creep detection (diff vs predicted files)

**GSD, Superpowers, Aperant** rely on the AI's own judgment for quality. No deterministic pre-screening, no adversarial review protocol, no post-merge integration testing.

**oh-my-claudecode** has agent-specific quality checks (e.g., the code review agent has its own standards), but no pipeline-level deterministic gates or integration testing. Quality depends on which agents you invoke and in what order.

**Vibe Kanban** has built-in quality checks as part of its product, but these are product-specific and not customizable at the same level as AgentFlow's pipeline.

### Cost Management

**AgentFlow** tracks costs per-task with stage cost ceilings, automatic warnings and hard stops (configurable per cost profile: $3/$10 for Sonnet, $8/$20 for Opus). The orchestrator reports total pipeline cost in the status dashboard.

**GSD, Superpowers, Aperant, oh-my-claudecode** have no built-in cost tracking or guardrails.

**Vibe Kanban** may include usage tracking as part of its product, but details depend on the specific version/plan.

### Learning & Improvement

**AgentFlow** implements system-level learning:
- Every retry carries accumulated context (what was tried, what failed, what to change)
- Every 10 completed tasks, common failure patterns are extracted to LEARNINGS.md
- Builders and reviewers read LEARNINGS.md before starting work
- Different workers are assigned on retry 2+ to avoid repeated blind spots

**GSD, Superpowers, Aperant, oh-my-claudecode, Vibe Kanban** don't have cross-task learning mechanisms.

### Failure Recovery

| Scenario | AgentFlow | GSD | Superpowers | Aperant | oh-my-claudecode | Vibe Kanban |
|----------|-----------|-----|-------------|---------|-----------------|-------------|
| Agent crashes | Heartbeat timeout → reassign in 10 min | Restart manually | Re-run command | Restart app | Re-run agent | Product-managed |
| Integration breaks main | Auto-revert (git revert) | Manual fix | Manual fix | Manual fix | Manual fix | Product-specific |
| Task impossible | Auto-detect after 2 failures → human escalation | Fails silently | Fails silently | Fails silently | Fails silently | Unknown |
| Spec changes | SHA-256 hash detection → pause + flag all tasks | No detection | No detection | No detection | No detection | No detection |
| Cost runaway | Auto-stop at configurable threshold | No detection | No detection | No detection | No detection | Product-specific |

### Setup Complexity

| Tool | Setup Time | Requirements |
|------|-----------|-------------|
| **AgentFlow** | ~30 min | Claude Code + Asana/Linear MCP + crontab |
| **GSD** | ~10 min | Claude Code + config file |
| **Superpowers** | ~5 min | Claude Code + copy CLAUDE.md |
| **Aperant** | ~15 min | Download Electron app |
| **oh-my-claudecode** | ~10 min | Claude Code + install skills |
| **Vibe Kanban** | ~20 min | Account signup + project setup |

AgentFlow has the most involved setup, but this reflects its deeper integration with project management infrastructure.

### Multi-Project Support

**AgentFlow** natively supports multiple projects through the PM tool's portfolio/workspace features. Each project is an independent pipeline with its own Kanban board, status dashboard, and cost tracking.

**GSD** focuses on single-project execution.

**Superpowers** can be adapted per-project but doesn't have native multi-project orchestration.

**Aperant** manages agents per-project but without cross-project features.

## When to Choose AgentFlow

Choose AgentFlow when you need:
- **Full pipeline observability** — monitor and intervene from your phone
- **Deterministic quality gates** — machine-verifiable checks before AI review
- **Cost tracking and guardrails** — prevent runaway spending on stuck tasks
- **System-level learning** — mistakes in early tasks prevent mistakes in later ones
- **Multi-project management** — run multiple autonomous pipelines simultaneously
- **Crash resilience** — pipeline state survives agent failures without data loss
- **Audit trail** — every agent decision documented in task comments
- **Team collaboration** — multiple humans can monitor and intervene through the PM tool

## When to Choose Alternatives

- **GSD**: Quick prototyping, single-project focus, comfortable with CLI-only workflow
- **Superpowers**: Minimal setup, methodology-driven approach, single-developer workflow
- **Aperant**: Prefer desktop GUI, visual workflow management, local-first approach
- **oh-my-claudecode**: Want a library of specialized agents to invoke on-demand without full pipeline orchestration. Good for teams that want agent tooling without committing to a lifecycle framework.
- **Vibe Kanban**: Want a turnkey product with kanban + AI agents built in, without configuring your own pipeline. Good for teams that prefer a hosted solution over an open framework.
