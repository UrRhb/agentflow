# AgentFlow vs Alternatives

> A detailed comparison of AI-powered software development tools. How AgentFlow's Kanban-orchestrated pipeline compares to CLI-based, prompt-based, and desktop-based approaches.

## Overview

| Tool | Approach | Orchestration | Observability | Quality Gates |
|------|----------|---------------|---------------|---------------|
| **AgentFlow** | Kanban-as-state-machine | PM tool (Asana/Linear/Jira) | Full (phone, web, desktop) | Deterministic + adversarial AI |
| **GSD** | CLI wave executor | Terminal commands | Terminal only | None built-in |
| **Superpowers** | Methodology-as-prompt | CLAUDE.md file | File-based | Prompt-driven |
| **Aperant** | Desktop agent manager | Electron app + SQLite | Desktop app only | None built-in |

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

### Quality & Safety

**AgentFlow** implements a multi-layer quality system:
1. Deterministic gates (tsc + eslint + tests) run BEFORE AI review — catches ~60% of issues at near-zero cost
2. Adversarial AI review with mandatory issue-finding ("list 3 things wrong before passing")
3. Coverage gates (80% on new files)
4. Integration testing on main after every merge
5. Automatic revert on integration failure (new commit, never force-push)
6. Scope creep detection (diff vs predicted files)

**GSD, Superpowers, Aperant** rely on the AI's own judgment for quality. No deterministic pre-screening, no adversarial review protocol, no post-merge integration testing.

### Cost Management

**AgentFlow** tracks costs per-task with stage cost ceilings, automatic warnings at $5, and hard stops at $15. The orchestrator reports total pipeline cost in the status dashboard.

**GSD, Superpowers, Aperant** have no built-in cost tracking or guardrails.

### Learning & Improvement

**AgentFlow** implements system-level learning:
- Every retry carries accumulated context (what was tried, what failed, what to change)
- Every 10 completed tasks, common failure patterns are extracted to LEARNINGS.md
- Builders and reviewers read LEARNINGS.md before starting work
- Different workers are assigned on retry 2+ to avoid repeated blind spots

**GSD, Superpowers, Aperant** don't have cross-task learning mechanisms.

### Failure Recovery

| Scenario | AgentFlow | GSD | Superpowers | Aperant |
|----------|-----------|-----|-------------|---------|
| Agent crashes | Heartbeat timeout → reassign in 10 min | Restart manually | Re-run command | Restart app |
| Integration breaks main | Auto-revert (git revert) | Manual fix | Manual fix | Manual fix |
| Task impossible | Auto-detect after 2 failures → human escalation | Fails silently | Fails silently | Fails silently |
| Spec changes | SHA-256 hash detection → pause + flag all tasks | No detection | No detection | No detection |
| Cost runaway | Auto-stop at $15 threshold | No detection | No detection | No detection |

### Setup Complexity

| Tool | Setup Time | Requirements |
|------|-----------|-------------|
| **AgentFlow** | ~30 min | Claude Code + Asana/Linear MCP + crontab |
| **GSD** | ~10 min | Claude Code + config file |
| **Superpowers** | ~5 min | Claude Code + copy CLAUDE.md |
| **Aperant** | ~15 min | Download Electron app |

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
