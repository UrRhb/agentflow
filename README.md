<p align="center">
  <h1 align="center">AgentFlow</h1>
  <p align="center"><strong>Your Kanban board builds your code.</strong></p>
  <p align="center">
    The first AI development pipeline that uses your project management tool as the orchestration layer.<br/>
    Full observability. Deterministic quality gates. Zero custom infrastructure.
  </p>
  <p align="center">
    <a href="#quick-start">Quick Start</a> &bull;
    <a href="docs/architecture.md">Architecture</a> &bull;
    <a href="docs/getting-started.md">Getting Started</a> &bull;
    <a href="docs/gap-registry.md">Gap Registry</a> &bull;
    <a href="#comparison">Comparison</a>
  </p>
</p>

---

## What is AgentFlow?

AgentFlow turns your existing Kanban board (Asana, GitHub Projects, Linear, Jira) into a **fully autonomous AI development pipeline**. Instead of building custom orchestration infrastructure, AgentFlow treats your project management tool as a distributed state machine — tasks move through stages, AI agents read and write state via comments, and humans intervene through the same UI they already use.

**The result:** Complete pipeline observability from your phone. Crash recovery for free (state lives in your PM tool, not in memory). Human override at any point by dragging a card.

### Why AgentFlow?

Most AI coding tools either give you a chatbot or a black-box agent. AgentFlow gives you a **visible, auditable pipeline** where:

- Every decision is a comment on a task card
- Every stage transition is a card moving between columns
- Every retry carries accumulated context from previous attempts
- Every cost is tracked per-task with automatic guardrails
- Every failure pattern is captured and fed back into the system

You don't need to trust a black box. Open your Kanban board and watch the pipeline work.

## Key Features

### Pipeline Orchestration
- **7-stage Kanban pipeline**: Backlog → Research → Build → Review → Test → Integrate → Done
- **Stateless orchestrator**: One-shot sweep via crontab — no daemon, no session dependency, crash-proof
- **Transitive priority dispatch**: Tasks that unblock the most work get built first (automatic critical path)
- **Conflict-aware scheduling**: Parallel tasks touching the same files are serialized automatically

### Quality Gates
- **Deterministic before probabilistic**: `tsc + eslint + tests` run as hard gates before any AI review — catches ~60% of issues at near-zero cost
- **Adversarial AI review**: Reviewers must "list 3 things wrong before deciding to pass"
- **Coverage gate**: 80% threshold on new files before promotion to Test stage
- **Integration testing**: Full suite runs on `main` after every merge — auto-reverts on failure

### Observability & Cost Tracking
- **Full pipeline observability** from your phone — every task card shows current stage, assigned agent, retry count, and accumulated cost
- **Per-task cost tracking** with stage cost ceilings (Sonnet default: Research ~$0.10, Build ~$0.40, Review ~$0.10, Test ~$0.05, Integrate ~$0.03)
- **Automatic cost guardrails**: Warning at $3/$8, hard stop at $10/$20 (Sonnet/Opus) with human escalation
- **Real-time status dashboard** pinned to each project
- **Heartbeat monitoring**: Dead agents detected and reassigned within 10 minutes

### System Learning
- **Feedback loops with accumulated context**: Every retry carries what was tried, what failed, and what to do differently
- **System-level retrospectives**: Every 10 completed tasks, common failure patterns are extracted to `LEARNINGS.md`
- **Cross-task learning**: Builders and reviewers read `LEARNINGS.md` before starting work
- **Spec drift detection**: SHA-256 hash comparison catches requirement changes mid-sprint

### Safety & Recovery
- **Auto-revert on integration failure**: `git revert` (new commit, never force-push)
- **Graceful shutdown**: Active workers finish, unstarted tasks return to backlog
- **Blocked task detection**: After 2 failed attempts, tasks escalate to human review
- **Scope creep detection**: PR diff files compared against predicted files list
- **Secret management**: Mock values in tests, environment variables in code, manual verification flags for real API tasks

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │           Your Kanban Board (Asana)          │
                    │                                             │
  Crontab runs      │  Backlog → Research → Build → Review → ...  │
  every 15 min      │     ↑                            │          │
       │            │     │     Needs Human ←──────────┘          │
       ▼            │     │         (drag card to intervene)      │
  ┌──────────┐      └─────┼───────────────────────────────────────┘
  │Orchestrate│           │
  │ (sweep)   │───reads───┘
  └──────────┘
       │            ┌──────────┐  ┌──────────┐  ┌──────────┐
       └─dispatches─│ Worker T2 │  │ Worker T3 │  │ Worker T4 │ ...
                    │ (Build)   │  │ (Build)   │  │ (Review)  │
                    └──────────┘  └──────────┘  └──────────┘
                         │              │              │
                         └──── all state flows through Kanban ────┘
```

**Core principle:** The Kanban board IS the orchestration layer. No separate database, no message queue, no custom infrastructure. State lives where humans already look.

[Full architecture docs →](docs/architecture.md)

## Quick Start

### Prerequisites

- [Claude Code](https://claude.ai/code) (CLI)
- An Asana workspace with MCP integration (or GitHub Projects — adapter coming soon)
- Git + Node.js project

### Installation

```bash
# Clone the repo
git clone https://github.com/UrRhb/agentflow.git

# Copy skills and prompts to your Claude Code config
cp -r agentflow/skills/* ~/.claude/skills/
cp -r agentflow/prompts/* ~/.claude/sdlc/prompts/
cp agentflow/conventions.md ~/.claude/sdlc/conventions.md
```

### Plugin Installation (Recommended)

If you're using Claude Code, install AgentFlow as a native plugin for automatic worker spawning, instant handoffs, and infrastructure-level quality gates:

```bash
# Install the plugin
claude plugins install agentflow

# Or manually: clone and link
git clone https://github.com/UrRhb/agentflow.git
cp -r agentflow/plugin ~/.claude/plugins/agentflow
```

**Plugin mode gives you:**
- Automatic worker spawning (no iTerm tabs)
- Instant handoffs via SendMessage (seconds, not 15 minutes)
- Infrastructure-level quality gates (hooks enforce tsc/lint/test/coverage)
- Real-time progress tracking
- Clean team shutdown

**Quick start (plugin mode):**
```bash
# 1. Create your spec
# 2. Decompose into tasks
claude -p "/spec-to-board"

# 3. Start the pipeline (workers spawn automatically!)
claude -p "/sdlc-orchestrate"

# 4. Watch from your phone (Asana) or terminal
claude -p "/sdlc-health"
```

### Setup

**1. Create your spec**

Write a `SPEC.md` for your project — or use Claude to brainstorm one:

```
You: I want to build [your idea]
Claude: [brainstorms → produces SPEC.md]
```

**2. Decompose into tasks**

```
You: /spec-to-asana
Claude: Reading SPEC.md... Decomposing into atomic tasks...
        Created 14 tasks across 3 sub-phases in Asana.
        Dependencies mapped. Ready to build.
```

**3. Start workers**

Open 3-4 terminal windows, each as a worker slot:

```bash
# Terminal 2
claude -p "/sdlc-worker --slot T2"

# Terminal 3
claude -p "/sdlc-worker --slot T3"

# Terminal 4 (reviewer)
claude -p "/sdlc-worker --slot T4"

# Terminal 5 (tester)
claude -p "/sdlc-worker --slot T5"
```

**4. Start the orchestrator**

```bash
# Add to crontab (runs every 15 minutes)
crontab -e
# Add: */15 * * * * ~/.claude/sdlc/agentflow-cron.sh >> /tmp/agentflow-orchestrate.log 2>&1
```

**5. Watch from your phone**

Open Asana on your phone. Watch tasks flow through the pipeline. Drag any card to "Needs Human" to intervene.

### Stop the pipeline

```
You: /sdlc-stop
Claude: Graceful shutdown initiated. Active workers finishing...
        3 tasks returned to Backlog. System paused.
```

[Detailed getting started guide →](docs/getting-started.md)

## How It Works

### The 7-Stage Pipeline

| Stage | What Happens | Gate |
|-------|-------------|------|
| **Backlog** | Task waiting for dependencies + available slot | Dependencies resolved, no file conflicts |
| **Research** | Conditional — only runs if task has research triggers | Structured findings posted |
| **Build** | AI writes code, creates PR | `tsc + eslint + npm test` (deterministic) |
| **Review** | Different AI agent reviews adversarially | Must list 3 issues before passing |
| **Test** | Full test suite + visual validation + coverage check | 80% coverage on new files |
| **Integrate** | Merge to main, run full suite | All tests pass on main |
| **Done** | Task complete | — |

### Task Lifecycle

```
[SLOT:--] [STAGE:Backlog] [RETRY:0] [COST:~$0]
    │
    ├── Orchestrator assigns slot → [SLOT:T2] [STAGE:Build]
    │
    ├── Worker T2 builds → posts [BUILD:COMPLETE] with PR link
    │
    ├── Lint gate: tsc + eslint + tests → [LINT:PASS]
    │
    ├── Worker T4 reviews → finds 3 issues → all acceptable → [REVIEW:PASS]
    │
    ├── Coverage gate → [COV:PASS]
    │
    ├── Worker T5 tests → [TEST:PASS] → merges PR
    │
    ├── Integration check on main → [INTEGRATE:PASS]
    │
    └── [STAGE:Done] [COST:~$5.75]
```

### What Happens When Things Fail

```
[REVIEW:REJECT] "SQL injection in user input handler"
    │
    ├── Retry counter increments → [RETRY:1]
    ├── Accumulated context posted (what was tried, what failed, what to do differently)
    ├── Slot cleared → different worker assigned on retry 2+
    ├── Task moves back to Build
    │
    └── If cost exceeds hard stop threshold → [COST:CRITICAL] → moves to "Needs Human"
```

## Comparison

<a id="comparison"></a>

| Feature | **AgentFlow** | GSD | Superpowers | Aperant |
|---------|:------------:|:---:|:-----------:|:-------:|
| **Orchestration layer** | Your Kanban board (Asana/Linear/Jira) | CLI waves | CLAUDE.md prompts | Electron app |
| **Pipeline observability** | Full (phone, web, desktop) | Terminal only | File-based | Desktop app |
| **Deterministic quality gates** | tsc + lint + tests before AI review | None | None | None |
| **Per-task cost tracking** | Built-in with guardrails | None | None | None |
| **Adversarial review** | Different agent, must find 3 issues | Same agent | Same agent | Same agent |
| **Integration testing** | Auto-revert on main breakage | None | None | None |
| **System-level learning** | LEARNINGS.md retrospectives | None | None | None |
| **Crash recovery** | Free (state in PM tool) | Restart from scratch | Re-read files | Restart app |
| **Human intervention** | Drag a card | Kill process | Edit files | Click button |
| **Spec drift detection** | SHA-256 hash comparison | None | None | None |
| **Multi-project support** | Native (portfolio view) | Single project | Single project | Single project |
| **Parallel agents** | 4+ workers with conflict detection | Wave-based | Sequential | Sequential |
| **Custom infrastructure** | None (uses existing PM tool) | CLI tool | Markdown files | Electron + SQLite |
| **Adapter ecosystem** | Asana, GitHub Projects (planned), Linear (planned) | GitHub only | Any git repo | Local only |
| **Worker spawning** | Automatic (plugin) or manual (standalone) | Manual | Manual | Manual |

### When to Use What

- **AgentFlow**: You want full pipeline observability, deterministic quality gates, cost tracking, and the ability to monitor/intervene from your phone. Best for teams and solo devs running multiple projects.
- **AgentFlow + Superpowers**: You want the best of both — AgentFlow orchestrates across tasks, Superpowers optimizes each worker's methodology. [See integration guide below.](#superpowers-integration)
- **GSD**: You want a simple CLI tool for wave-based task execution. Good for quick prototyping.
- **Superpowers**: You want a methodology-as-prompt approach with minimal setup. Good for single-project focus.
- **Aperant**: You want a desktop GUI for agent management. Good for visual workflow preference.

## Superpowers Integration

<a id="superpowers-integration"></a>

AgentFlow and [Superpowers](https://github.com/obra/superpowers) operate at **different layers** and are designed to stack:

```
┌───────────────────────────────────────────────────────────┐
│  OUTER LOOP — AgentFlow                                    │
│  "Which task should which agent work on, and when?"        │
│  Kanban board • dispatch • transitions • cost gates        │
│                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  Worker T2   │  │  Worker T3   │  │  Worker T4   │       │
│  │  INNER LOOP  │  │  INNER LOOP  │  │  INNER LOOP  │       │
│  │  Superpowers │  │  Superpowers │  │  Superpowers │       │
│  │  brainstorm  │  │  brainstorm  │  │  code-review │       │
│  │  → plan      │  │  → plan      │  │  + adversary │       │
│  │  → execute   │  │  → execute   │  │    rules     │       │
│  │  → verify    │  │  → verify    │  │              │       │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└───────────────────────────────────────────────────────────┘
```

**AgentFlow** decides: *"Task APP-007 goes to Worker T2 now"*
**Superpowers** decides: *"Inside T2, I'll brainstorm → plan → execute with sub-agents → verify"*

### What Each Layer Controls

| Concern | AgentFlow (outer) | Superpowers (inner) |
|---------|-------------------|-------------------|
| Task assignment | Which worker gets which task | — |
| Build methodology | Lifecycle markers + heartbeats | brainstorm → plan → execute → verify |
| Parallelism | Across tasks (T2 builds one, T3 builds another) | Within a task (sub-agents write code in parallel) |
| Quality gates | Deterministic (tsc/lint/test) + adversarial review | Structured review methodology |
| Debugging | Retry context + worker rotation | Systematic debugging methodology |
| Cost tracking | Per-task with guardrails | — |

### Complexity Gating

Not every task needs Superpowers' full methodology. AgentFlow gates by task complexity:

| Complexity | Superpowers Methodology | Why |
|-----------|------------------------|-----|
| **S** (Simple, <30min) | Skip brainstorm + plan. Direct build. | Overkill adds ~$0.50-1.00 for zero quality gain |
| **M** (Medium, <1hr) | Skip brainstorm. Use plan → execute. | Planning helps, brainstorming doesn't |
| **L** (Complex, <2hr) | Full: brainstorm → plan → execute → verify | Worth the investment on complex tasks |

### Integration Gaps (24-31)

Stacking two systems creates 8 new failure modes. All are addressed in AgentFlow's design:

| # | Gap | Fix |
|---|-----|-----|
| 24 | Context window war (both systems load large prompts) | Lazy-load: only load Superpowers prompts matching task complexity |
| 25 | Two captains (conflicting workflow control) | AgentFlow owns lifecycle, Superpowers owns methodology |
| 26 | Sub-agents skip heartbeats (false dead-worker detection) | Parent worker posts heartbeats independently of sub-agents |
| 27 | Plan exceeds task scope (Superpowers plans freely) | Feed predicted files + acceptance criteria as hard constraints |
| 28 | Double cost tracking (sub-agents add hidden cost) | Adjusted ceilings: S=$3, M=$5, L=$8 when Superpowers active |
| 29 | Retry context fragmentation (sub-agent failures lost) | Parent aggregates all sub-agent outputs before posting |
| 30 | Brainstorm overkill on simple tasks | Complexity gating (table above) |
| 31 | Conflicting review standards | AgentFlow adversarial rules override; Superpowers provides methodology |

[Full details for all 45 gaps →](docs/gap-registry.md)

## Adapters

AgentFlow uses an adapter pattern to support multiple project management tools. Each adapter implements the same interface for reading/writing pipeline state.

| Adapter | Status | Notes |
|---------|--------|-------|
| **Asana** | Available | Full MCP integration, recommended for production |
| **GitHub Projects** | Planned | Free alternative, community priority |
| **Linear** | Planned | For teams already on Linear |
| **Jira** | Planned | Enterprise support |
| **Notion** | Planned | For Notion-native teams |

Want to build an adapter? See [CONTRIBUTING.md](CONTRIBUTING.md).

## The 45-Gap Registry

AgentFlow was designed by systematically identifying and closing 45 gaps in AI development pipelines — 23 for the core system, 8 for Superpowers integration, and 14 from production audit findings. Each gap represents a failure mode that existing tools don't address.

| # | Gap | Fix |
|---|-----|-----|
| 1 | AI review has shared blindness with AI builder | Deterministic gates (tsc/lint/test) before AI review |
| 2 | No decomposition quality standard | 9-field rubric with validation |
| 3 | No integration testing after merge | 7th stage: full suite on main, auto-revert on failure |
| 4 | Unconditional research wastes time/money | Trigger-based: only research when task needs external knowledge |
| 5 | No cost visibility | Per-task tracking with stage ceilings and automatic guardrails |
| 6 | Parallel tasks can conflict on shared files | Predicted files comparison, automatic serialization |
| 7 | Same mistakes repeated across tasks | LEARNINGS.md retrospective every 10 tasks |
| 8 | Dead agents block the pipeline | Heartbeat every 5 min, reassign after 10 min timeout |
| 9 | AI reviews are too lenient | Adversarial prompt: "list 3 things wrong before deciding to pass" |
| 10 | Integration failures leave main broken | Auto-revert via `git revert` (new commit, never force-push) |
| 11 | Asana custom fields are fragile | All metadata in description headers, parsed with regex |
| 12 | Session-based scheduling dies with session | Stateless orchestrator + real crontab (most critical gap) |
| 13 | No visibility into what agents are doing | Comment-thread-as-memory: every action is a tagged comment |
| 14 | Runaway costs on stuck tasks | Cost ceilings per stage, warning at $3/$8, hard stop at $10/$20 (Sonnet/Opus) |
| 15 | Uncontrolled external API usage | Source priority: codebase → docs → web → GitHub (opt-in only) |
| 16 | Circular dependencies in task graph | Topological sort validation during decomposition |
| 17 | PRs that exceed task scope | Diff files vs predicted files → `[SCOPE:WARNING]` |
| 18 | Impossible tasks retry forever | After 2 failures: evaluate → `[BUILD:BLOCKED]` escalation |
| 19 | Secrets leaked in code | Mock values in tests, env vars in code, `[NEEDS:MANUAL_VERIFY]` |
| 20 | Wrong task gets built first | Transitive priority: count downstream blocked tasks |
| 21 | No dashboard for pipeline status | Pinned Status task updated every sweep |
| 22 | No clean shutdown mechanism | `/sdlc-stop` drains workers, returns unstarted to backlog |
| 23 | Spec changes mid-sprint go unnoticed | SHA-256 hash comparison, `[SPEC:CHANGED]` flag |
| | **Superpowers Integration Gaps** | |
| 24 | Context window war (stacked prompts) | Lazy-load prompts by task complexity |
| 25 | Two captains (conflicting workflow control) | AgentFlow owns lifecycle, Superpowers owns methodology |
| 26 | Sub-agents skip heartbeats | Parent worker posts heartbeats independently |
| 27 | Plan exceeds task scope | Predicted files + acceptance criteria as hard constraints |
| 28 | Double cost tracking (hidden sub-agent cost) | Adjusted ceilings: S=$3, M=$5, L=$8 with Superpowers |
| 29 | Retry context fragmentation | Parent aggregates all sub-agent outputs |
| 30 | Brainstorm overkill on simple tasks | Complexity gating: S=skip, M=plan only, L=full |
| 31 | Conflicting review standards | AgentFlow adversarial rules override Superpowers |
| | **Audit Finding Gaps** | |
| 32 | No worktree cleanup | Worktree removed on Done transition |
| 33 | Prompt version skew | Version field in conventions.md, re-read per task |
| 34 | No merge lock | `[MERGE_LOCK]` on Status task, 10 min timeout |
| 35 | Sub-agent git conflicts | Non-overlapping file sets; sequential fallback |
| 36 | No orchestrator health monitoring | `[LAST_SWEEP]` timestamp + external watchdog |
| 37 | Comment thread pollution | Read only last 10-20 comments per task |
| 38 | Dual sweep collision | `[SWEEP:RUNNING]` mutual exclusion lock |
| 39 | Adversarial review ping-pong | PASS WITH NOTES for minor-only issues |
| 40 | Prompt injection | Input sanitization check at stage entry |
| 41 | LEARNINGS.md context bomb | 50-line cap with oldest-first rotation |
| 42 | Git revert can fail | `[INTEGRATE:REVERT_FAILED]` → Needs Human |
| 43 | Crontab environment/auth failure | Wrapper script sources shell environment |
| 44 | Cost ceilings assume wrong model | Dual cost profiles (Sonnet/Opus) |
| 45 | Orchestrator cost | Idle sweep optimization, doubles interval when idle |

[Full gap registry with details →](docs/gap-registry.md)

## Project Structure

```
agentflow/
├── core/                      # Shared logic (standalone + plugin)
│   ├── skills/                # Claude Code skill files (copy to ~/.claude/skills/)
│   │   ├── spec-to-asana.md   # Decompose spec → Kanban tasks
│   │   ├── sdlc-worker.md     # Execute pipeline stages
│   │   ├── sdlc-orchestrate.md# Stateless orchestration sweep
│   │   └── sdlc-stop.md       # Graceful shutdown
│   └── prompts/               # Stage-specific prompt templates
│       ├── decompose.md       # Spec → atomic tasks
│       ├── research.md        # Conditional research stage
│       ├── build.md           # Build with lint gate
│       ├── review.md          # Adversarial review
│       └── test.md            # Test + integration
├── plugin/                    # Claude Code native plugin
│   ├── plugin.json            # Plugin manifest
│   ├── .mcp.json              # MCP server configuration
│   ├── commands/              # Slash commands (/sdlc-orchestrate, etc.)
│   ├── agents/                # Subagent definitions (workers, reviewer)
│   ├── hooks/                 # Pre/post tool-use hooks (quality gates)
│   └── skills/                # Plugin-specific skills
├── bin/                       # CLI scripts and crontab wrapper
│   └── agentflow-cron.sh      # Crontab wrapper for standalone mode
├── skills/                    # Legacy skill files (symlinks to core/)
├── prompts/                   # Legacy prompt files (symlinks to core/)
├── conventions.md             # System conventions and protocols
├── adapters/                  # PM tool adapters
│   ├── asana/                 # Asana MCP adapter (available)
│   └── github-projects/       # GitHub Projects adapter (planned)
├── docs/                      # Documentation
│   ├── architecture.md        # System architecture deep-dive
│   ├── getting-started.md     # Step-by-step setup guide
│   ├── gap-registry.md        # All 45 gaps with full details
│   └── comparison.md          # Detailed competitive analysis
├── examples/                  # Example specs and configurations
│   └── starter-spec.md        # Template SPEC.md to get started
├── setup.sh                   # Setup script (detects plugin support)
├── CONTRIBUTING.md            # How to contribute
├── LICENSE                    # MIT
└── README.md                  # You are here
```

## Contributing

We welcome contributions! The highest-impact areas:

1. **GitHub Projects adapter** — makes AgentFlow free to use (no Asana required)
2. **Linear adapter** — popular with dev teams
3. **Stage prompt improvements** — better review/test prompts
4. **Documentation** — tutorials, examples, translations

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License. See [LICENSE](LICENSE).

## Automation Levels

AgentFlow operates on a spectrum from semi-automated to fully autonomous:

| Level | What You Do | What AgentFlow Does |
|-------|------------|-------------------|
| **Manual** | Write SPEC.md | — |
| **Semi-automated** | Run `/spec-to-asana`, open worker terminals, set crontab | Decomposes spec, creates board, validates tasks |
| **Autonomous** | Watch from your phone, handle "Needs Human" cards | Everything else — dispatch, build, review, test, merge, revert, retry, learn |

### What's autonomous today
- Orchestrator sweeps (crontab-driven, no human in the loop)
- Task dispatch with transitive priority and conflict detection
- Build → lint gate → review → coverage gate → test → merge → integration
- Feedback loops with accumulated context and worker rotation
- Cost tracking with automatic guardrails (warning at $3/$8, hard stop at $10/$20 per Sonnet/Opus profile)
- Dead worker detection and reassignment
- System-level learning (LEARNINGS.md retrospectives)
- Auto-revert on integration failure
- Spec drift detection
- Graceful shutdown

### What's still manual
- Starting worker terminals (you open 3-4 iTerm tabs)
- Writing the initial SPEC.md
- Handling "Needs Human" cards (blocked tasks, cost-critical, spec changes)
- Adjusting crontab frequency

## Roadmap

- [ ] **Auto-spawn workers**: Orchestrator detects empty slots and spawns worker sessions automatically via `claude -p "/sdlc-worker --slot T<N>"`
- [ ] **GitHub Projects adapter**: Free alternative to Asana — no paid PM tool required
- [ ] **Linear adapter**: For teams already on Linear
- [ ] **Web dashboard**: Real-time pipeline visualization beyond the Kanban board
- [ ] **Multi-language support**: Python, Go, Rust project conventions (currently Node.js/TypeScript focused)
- [ ] **Slack/Discord notifications**: Pipeline events pushed to team channels
- [ ] **Cost analytics**: Historical cost data, trends, and optimization suggestions

## Acknowledgments

- Built with [Claude Code](https://claude.ai/code) by Anthropic
- Inspired by the gaps in existing AI development tools
- Designed through systematic CTO-level review (45 gaps identified and addressed)

---

<p align="center">
  <strong>AgentFlow</strong> — Your Kanban board builds your code.
  <br/>
  <sub>Autonomous AI development pipeline with full observability, deterministic quality gates, and cost tracking.</sub>
  <br/><br/>
  <a href="https://github.com/UrRhb/agentflow/stargazers">
    <img src="https://img.shields.io/github/stars/UrRhb/agentflow?style=social" alt="GitHub Stars" />
  </a>
</p>
