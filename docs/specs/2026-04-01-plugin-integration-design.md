# AgentFlow v2: Plugin Integration + Pattern Theft Design

> **Date:** 2026-04-01
> **Status:** Draft — awaiting approval
> **Approach:** Dual-Mode (Standalone + Claude Code Plugin)
> **Scope:** Restructure AgentFlow repo, add Claude Code plugin layer, integrate 6 patterns from Claude Code source

---

## 1. Problem Statement

AgentFlow v1 works but has friction:

1. **Manual worker spawning** — user opens 4 iTerm tabs and runs `claude -p "/sdlc-worker --slot T<N>"` manually
2. **15-minute handoff latency** — builder finishes, task sits until next orchestrator sweep moves it to Review
3. **Prompt-level gate enforcement** — deterministic gates (tsc/lint/test) are requested by prompts, not enforced by infrastructure
4. **No real-time progress** — heartbeats are Asana comments (slow, costly), no live telemetry
5. **Crude input sanitization** — regex-based pattern matching for injection detection
6. **Context window blowup on retries** — long retry chains accumulate comments that fill the context

All 6 problems have solutions in Claude Code's production source code (leaked 2026-03-31).

---

## 2. Solution Overview

**Dual-Mode architecture:**

- `core/` — portable logic (prompts, conventions, adapters). Works with any AI IDE.
- `plugin/` — Claude Code native integration (agents, hooks, skills, MCP config). Unlocks native spawning, hooks, teams, and real-time progress.
- `bin/` — standalone crontab script (current approach, unchanged).

**Plugin mode** solves all 6 problems:
1. Orchestrator spawns workers via `AgentTool` — no iTerm tabs
2. Workers hand off directly via `SendMessage` — seconds, not 15 minutes
3. Hooks enforce gates at the tool level — agents cannot bypass
4. Progress tracker streams live telemetry via `SendMessage`
5. Permission classifiers replace regex sanitization
6. Context compaction manages token budgets across retries

**Standalone mode** continues to work as-is, with improved prompts from pattern theft (A).

---

## 3. Repository Structure

```
agentflow/
├── core/                           # Portable (works with any AI IDE)
│   ├── prompts/                    # Stage prompts (unchanged content, minor upgrades)
│   │   ├── decompose.md
│   │   ├── research.md
│   │   ├── build.md                # Updated: context compaction instructions
│   │   ├── review.md
│   │   └── test.md
│   ├── conventions.md              # Updated: v2 with plugin-aware sections
│   └── adapters/
│       ├── interface.md            # Adapter contract definition
│       ├── asana/
│       │   └── README.md
│       └── github-projects/
│           └── README.md
│
├── plugin/                         # Claude Code native integration
│   ├── plugin.json                 # Plugin manifest
│   ├── agents/
│   │   ├── sdlc-orchestrator.md    # Orchestrator agent definition
│   │   ├── sdlc-builder.md         # Builder worker agent
│   │   ├── sdlc-reviewer.md        # Reviewer worker agent (no Edit/Write)
│   │   └── sdlc-tester.md          # Tester worker agent
│   ├── hooks/
│   │   ├── lint-gate.md            # PreToolUse: blocks commit without tsc+lint+test
│   │   ├── coverage-gate.md        # Stop: reviewer can't finish without coverage
│   │   └── scope-guard.md          # PreToolUse: warns/blocks unpredicted file edits
│   ├── skills/
│   │   ├── spec-to-board.md        # Decompose spec -> PM tasks
│   │   ├── sdlc-worker.md          # Unified worker skill (plugin-aware)
│   │   ├── sdlc-orchestrate.md     # Orchestration skill (plugin-aware)
│   │   ├── sdlc-stop.md            # Graceful shutdown
│   │   ├── sdlc-health.md          # Pipeline health check
│   │   └── sdlc-demo.md            # Demo/tutorial
│   └── .mcp.json                   # Auto-configure PM tool MCP
│
├── bin/
│   └── agentflow-cron.sh           # Standalone crontab orchestrator (unchanged)
│
├── docs/
│   ├── architecture.md             # Updated for v2
│   ├── patterns/                   # Reference: patterns from Claude Code source
│   │   ├── coordinator.md
│   │   ├── progress-tracker.md
│   │   ├── permission-classifiers.md
│   │   ├── streaming-status.md
│   │   ├── complexity-gating.md
│   │   └── context-compaction.md
│   ├── comparison.md
│   ├── gap-registry.md             # Updated: gaps 46-51 for plugin mode
│   └── getting-started.md          # Updated: plugin install path
│
├── examples/
│   └── starter-spec.md
├── .github/
│   └── ISSUE_TEMPLATE/
├── README.md                       # Updated: dual-mode installation
├── CONTRIBUTING.md
├── LICENSE
└── setup.sh                        # Updated: detects Claude Code, offers plugin install
```

### Key structural decisions:

1. **`core/prompts/` stays portable.** Prompts never reference Claude Code APIs. They use conditional language: "If SendMessage is available, use it. Otherwise, post to Asana."
2. **`plugin/skills/` is the primary skill source.** Standalone mode copies these skills manually. No symlinks (causes issues on some systems).
3. **`docs/patterns/` is reference-only.** These document what we learned from Claude Code's source. They inform how prompts and agents are written but are not loaded at runtime.
4. **No `standalone/` directory.** Standalone mode is just "copy skills + set crontab." It's a README section, not an architecture layer.

---

## 4. Agent Architecture: Team-Based Spawning

### 4.1 Agent Definitions

Each worker type has a dedicated agent definition in `plugin/agents/`. Format follows Claude Code's `BaseAgentDefinition` schema.

**sdlc-orchestrator.md:**
```yaml
---
name: sdlc-orchestrator
description: "AgentFlow orchestrator. Stateless sweep: reads Kanban state, creates sprint team, dispatches tasks, handles transitions, tracks costs."
whenToUse: "When running pipeline orchestration sweep"
model: haiku
maxTurns: 100
tools: [AgentTool, Read, Glob, Grep, Bash]
requiredMcpServers: [asana]
color: "#8B5CF6"
---
```

**sdlc-builder.md:**
```yaml
---
name: sdlc-builder
description: "AgentFlow builder. Executes Build stage: writes code, creates PR, runs lint gate."
whenToUse: "When the orchestrator dispatches a task to the Build stage"
model: sonnet
isolation: worktree
maxTurns: 50
tools: [Bash, Read, Edit, Write, Glob, Grep, AgentTool]
requiredMcpServers: [asana]
color: "#3B82F6"
---
```

**sdlc-reviewer.md:**
```yaml
---
name: sdlc-reviewer
description: "AgentFlow adversarial reviewer. Must find 3 issues before passing. Cannot modify code."
whenToUse: "When the orchestrator dispatches a task to the Review stage"
model: sonnet
isolation: worktree
maxTurns: 20
tools: [Read, Glob, Grep, Bash]
disallowedTools: [Edit, Write]
requiredMcpServers: [asana]
color: "#F59E0B"
---
```

**sdlc-tester.md:**
```yaml
---
name: sdlc-tester
description: "AgentFlow tester. Runs test suite, checks coverage, merges PR, runs integration check."
whenToUse: "When the orchestrator dispatches a task to the Test stage"
model: sonnet
isolation: worktree
maxTurns: 30
tools: [Bash, Read, Glob, Grep]
requiredMcpServers: [asana]
color: "#10B981"
---
```

### 4.2 Team-Based Spawning

The orchestrator creates a named team instead of spawning individual agents:

```
/sdlc-orchestrate (plugin mode)
    |
    +-- Step 0: Create sprint team (or reuse existing — check member health first)
    |   TeamCreate({
    |     name: "sprint-team",
    |     members: [
    |       { agent: "sdlc-builder",  name: "T2", isolation: "worktree" },
    |       { agent: "sdlc-builder",  name: "T3", isolation: "worktree" },
    |       { agent: "sdlc-reviewer", name: "T4", isolation: "worktree" },
    |       { agent: "sdlc-tester",   name: "T5", isolation: "worktree" }
    |     ]
    |   })
    |
    +-- Steps 1-5: Normal sweep (read state, heartbeats, transitions)
    |
    +-- Step 6: Dispatch via SendMessage
    |   SendMessage(to: "T2", "Build APP-007. <task context>")
    |   SendMessage(to: "T4", "Review APP-003. <PR link, diff>")
    |
    +-- Workers hand off directly:
    |   T2 -> SendMessage(to: "T4", "APP-007 build complete, PR #42")
    |   T4 -> SendMessage(to: "T5", "APP-007 review passed")
    |
    +-- Step 9: On shutdown
    |   TeamDelete("sprint-team")
    |
    +-- Workers ALSO post to Asana (durable state for humans)
```

### 4.3 Why Teams Over Individual Spawning

| Concern | Individual Spawning | Team Spawning |
|---|---|---|
| Communication | All through orchestrator (bottleneck) | Direct agent-to-agent via SendMessage |
| Handoffs | Wait for 15-min sweep cycle | Instant via SendMessage |
| Lifecycle | Orchestrator tracks each agent | Team manages member state |
| Scaling | Add more AgentTool calls | Add members to team |
| Shutdown | Kill each individually | TeamDelete — clean teardown |

### 4.4 Dual Communication Layer

```
+-----------------------------------------------------------+
|  SendMessage (fast, ephemeral, agent-to-agent)            |
|  T2 <-> T3 <-> T4 <-> T5                                 |
|  Used for: handoffs, progress %, live status, token usage |
+----------------------------+------------------------------+
                             |
                      (workers also write to)
                             |
+----------------------------v------------------------------+
|  Asana Comments (slow, durable, human-visible)            |
|  [BUILD:COMPLETE] -> [REVIEW:PASS] -> [TEST:PASS]        |
|  Used for: state of record, audit trail, phone monitoring |
+-----------------------------------------------------------+
```

**Write-ahead pattern:** SendMessage triggers immediate action. Asana comments are the durable record. If a worker crashes mid-handoff, the orchestrator's next sweep recovers from Asana state.

### 4.5 Standalone Fallback

In standalone mode:
- No teams or SendMessage
- Workers are separate terminal sessions
- Handoffs go through Asana only (15-min sweep latency)
- Prompts include: "If SendMessage is available, notify the next worker directly. Otherwise, post to Asana and wait."

---

## 5. Hooks: Deterministic Gates as Infrastructure

### 5.1 How Hooks Work

Claude Code hooks are shell commands that intercept tool calls:
- **PreToolUse:** runs BEFORE a tool executes, can BLOCK it
- **PostToolUse:** runs AFTER a tool executes, can reject the result
- **Stop:** runs when an agent tries to finish, can force it to continue

Hooks are enforced by the runtime. The agent cannot bypass them.

### 5.2 lint-gate (PreToolUse)

**Trigger:** Builder agent calls Bash with `git commit` or `gh pr create`
**Action:** Run `tsc --noEmit && eslint . && npm test`
**On failure:** Block the tool call. Return error to agent.
**On success:** Allow the tool call through.

```yaml
# plugin/hooks/lint-gate.md
---
name: agentflow-lint-gate
event: PreToolUse
tools: ["Bash"]
agent: ["sdlc-builder"]
---
```

**What this solves:** Gap #1 (shared AI blindness). Deterministic checks run whether the agent remembers to or not.

### 5.3 coverage-gate (Stop)

**Trigger:** Tester agent attempts to finish its turn (before merging PR)
**Action:** Run `npm test -- --coverage`. Check new file coverage >= 80%.
**On failure:** Force tester to continue. Inject "[COV:FAIL]" — tester posts failure and bounces task back to Build.
**On success:** Allow tester to proceed with merge.

```yaml
# plugin/hooks/coverage-gate.md
---
name: agentflow-coverage-gate
event: Stop
agent: ["sdlc-tester"]
---
```

**Why on tester, not reviewer:** In v1, the reviewer runs coverage after REVIEW:PASS (per conventions). But the tester is the one who merges — coverage should gate the merge, not the review. This aligns with the test prompt (Step 8) which already runs coverage. The hook makes it mandatory.

**Why Stop, not PostToolUse:** PostToolUse requires pattern-matching on Bash content (brittle). Stop triggers when the tester is done with all work — cleaner and guaranteed to fire before merge.

### 5.4 scope-guard (PreToolUse)

**Trigger:** Builder agent calls Edit or Write on any file
**Action:** Check if target file is in the task's Predicted Files list (read from Asana)
**Behavior:**
- 1st unpredicted file: ALLOW + post `[SCOPE:WARNING]` to Asana
- 2nd unpredicted file: ALLOW + post `[SCOPE:WARNING]` to Asana
- 3rd unpredicted file: BLOCK. "3 unpredicted files. Update task description or flag for human review."

```yaml
# plugin/hooks/scope-guard.md
---
name: agentflow-scope-guard
event: PreToolUse
tools: ["Edit", "Write"]
agent: ["sdlc-builder"]
---
```

**Why soft-then-hard:** Builders legitimately discover they need utility files or test fixtures not predicted during decomposition. Hard-blocking on the first file creates friction. Two warnings + block on third balances safety with practical flexibility.

### 5.5 Standalone Fallback

In standalone mode, no hooks exist. Gates are prompt-enforced (current behavior). The README clearly states:

> **Plugin mode:** Gates enforced by hooks (agent cannot bypass)
> **Standalone mode:** Gates enforced by prompts (agent should not bypass)

### 5.6 Gaps Solved by Hooks

| Gap | Before (v1) | After (v2 plugin) |
|---|---|---|
| #1 Shared AI blindness | Prompt says "run tsc" | Hook blocks commit without tsc passing |
| #9 Lenient reviews | Prompt says "be adversarial" | Reviewer can't use Edit/Write (disallowedTools). Tester can't merge without coverage (Stop hook). |
| #17 Scope creep | Prompt says "check predicted files" | Hook blocks writes to unpredicted files after 2 warnings |

---

## 6. Pattern Integration (Stolen from Claude Code Source)

### 6.1 Coordinator Mode Pattern

**Source:** `src/coordinator/coordinatorMode.ts`
**What it does:** Multi-agent teams with role assignment, session mode matching, inter-agent messaging.
**How AgentFlow uses it:** The orchestrator operates in coordinator mode. It creates teams, assigns roles (builder/reviewer/tester), and manages the communication topology.

**Integration:**
- Orchestrator agent definition sets `coordinatorMode: true`
- Team members are registered with role preferences matching slot conventions (T2/T3=build, T4=review, T5=test)
- Review tasks are NEVER assigned to the slot that built them (enforced by coordinator, not just convention)

**Standalone equivalent:** Worker prompts include role instructions. Enforcement is prompt-level.

### 6.2 Progress Tracker Pattern

**Source:** `src/tasks/LocalAgentTask/LocalAgentTask.tsx` — `ProgressTracker` type
**What it does:** Tracks `toolUseCount`, `latestInputTokens`, `cumulativeOutputTokens`, `recentActivities` (last 5) per agent.
**How AgentFlow uses it:** Replaces crude `[HEARTBEAT]` tags with real telemetry.

**Integration:**
- Workers stream progress via SendMessage to orchestrator:
  ```
  { toolUseCount: 12, outputTokens: 45000, activity: "Editing src/auth.ts", cost: "$0.23" }
  ```
- Orchestrator aggregates into the Status dashboard
- If `toolUseCount` stops incrementing for 10 minutes → dead worker detection (more accurate than comment timestamps)
- `[HEARTBEAT]` Asana comments still posted as durable backup (every 5 min)

**Standalone equivalent:** `[HEARTBEAT]` comments only (current behavior).

### 6.3 Permission Classifiers Pattern

**Source:** `src/utils/permissions/permissions.ts` — `BASH_CLASSIFIER`, `TRANSCRIPT_CLASSIFIER`
**What it does:** Speculative safety checks on bash commands before execution. Classifies commands as safe/unsafe/needs-review.
**How AgentFlow uses it:** Upgrades input sanitization from regex to multi-layer classification.

**Integration:**
- Layer 1 (deterministic): Regex patterns for known-bad commands (current behavior, kept)
- Layer 2 (classifier): Bash commands run through classifier before execution — catches obfuscated injection that regex misses
- Layer 3 (scope): Task description content classified before being fed to worker prompts
- If any layer flags: `[SECURITY:WARNING]` → Needs Human

**Standalone equivalent:** Layer 1 only (regex patterns in prompts).

### 6.4 Async Generator Streaming Pattern

**Source:** `src/QueryEngine.ts` — `submitMessage()` async generator yielding `SDKMessage`
**What it does:** Streaming responses via async generators with `yield*` composition.
**How AgentFlow uses it:** Real-time status updates from workers to orchestrator and UI.

**Integration:**
- Worker progress streams through SendMessage (see 6.2)
- Orchestrator can show live dashboard in terminal (not just Asana)
- Status skill (`/sdlc-health`) reads live progress from all team members
- Streaming enables "watch the pipeline work" in terminal — comparable to Asana phone monitoring

**Standalone equivalent:** No streaming. Status comes from Asana comments.

### 6.5 Feature Flag / Complexity Gating Pattern

**Source:** `src/main.tsx` — `import { feature } from 'bun:bundle'`
**What it does:** Build-time dead-code elimination based on feature flags.
**How AgentFlow uses it:** Formal complexity gating for Superpowers integration.

**Integration:**
- Task complexity (S/M/L) acts as a feature flag for each task
- Worker skill checks complexity before loading Superpowers prompts:
  ```
  if complexity == "Simple":    skip all Superpowers prompts (save ~$0.50)
  if complexity == "Medium":    load plan + execute only
  if complexity == "Complex":   load full brainstorm + plan + execute + verify
  ```
- In plugin mode, this is enforced by the agent definition: builder agents receive only the prompts appropriate for the task's complexity
- Prompts not loaded = tokens not spent = cost savings

**Standalone equivalent:** Prompt-level conditional ("Check complexity, skip brainstorm for Simple tasks"). Already in v1.

### 6.6 Context Compaction Pattern

**Source:** `src/query.ts` — reactive compaction, `src/services/compact/`
**What it does:** When context window fills past thresholds, automatically compresses older messages while preserving recent context and key decisions.
**How AgentFlow uses it:** Prevents context blowup on long retry chains.

**Integration:**
- Workers monitor their own context usage (token count tracking from progress tracker)
- At 50% context: compact old research findings and early retry contexts into summaries
- At 70% context: aggressive compaction — only keep latest retry context + current work
- At 90% context: post full state as Asana comment, cleanly terminate, let orchestrator reassign to fresh worker
- Retry context comments include a `### Compact Summary` section: condensed history of all prior attempts in <500 tokens. Workers read this instead of all previous comments.

**Standalone equivalent:** Prompt instruction: "If context window >70%, post state and stop cleanly." Already in v1 but not formalized.

---

## 7. MCP Auto-Configuration

### 7.1 Plugin MCP Config

```json
// plugin/.mcp.json
{
  "mcpServers": {
    "asana": {
      "type": "remote",
      "url": "https://mcp.claude.ai/asana",
      "note": "Default PM adapter. Override with your own MCP config for Linear/Jira/GitHub Projects."
    }
  }
}
```

### 7.2 Override Mechanism

Users can override the default by setting their own MCP config in:
- Project-level `.mcp.json` (takes precedence over plugin)
- User-level settings

The plugin detects which PM MCP is available and adapts:
```
if asana MCP connected:    use Asana adapter commands
if linear MCP connected:   use Linear adapter commands (future)
if github MCP connected:   use GitHub Projects adapter commands (future)
if none:                   report error — PM tool required
```

### 7.3 Agent `requiredMcpServers`

All agent definitions declare `requiredMcpServers: [asana]`. Claude Code auto-connects the MCP server when spawning the agent. Workers don't need manual MCP setup.

In standalone mode, users configure MCP manually per the getting-started guide.

---

## 8. Plugin Manifest

```json
// plugin/plugin.json
{
  "name": "agentflow",
  "version": "2.0.0",
  "description": "Autonomous AI development pipeline using your Kanban board as the orchestration layer",
  "author": "UrRhb",
  "license": "MIT",
  "agents": [
    "agents/sdlc-orchestrator.md",
    "agents/sdlc-builder.md",
    "agents/sdlc-reviewer.md",
    "agents/sdlc-tester.md"
  ],
  "hooks": [
    "hooks/lint-gate.md",
    "hooks/coverage-gate.md",
    "hooks/scope-guard.md"
  ],
  "skills": [
    "skills/spec-to-board.md",
    "skills/sdlc-worker.md",
    "skills/sdlc-orchestrate.md",
    "skills/sdlc-stop.md",
    "skills/sdlc-health.md",
    "skills/sdlc-demo.md"
  ]
}
```

---

## 9. Updated Gap Registry (Gaps 46-51)

Plugin mode introduces 6 new potential failure modes:

| # | Gap | Fix |
|---|-----|-----|
| 46 | Team agent crashes mid-sprint (TeamCreate fails) | Fallback to individual AgentTool spawning. Log error, continue sweep. |
| 47 | SendMessage dropped (handoff lost) | Asana comments are the durable fallback. Next sweep recovers from Asana state. |
| 48 | Hook blocks legitimate action (false positive) | scope-guard has 2-warning buffer. lint-gate is deterministic (no false positives). coverage-gate failure = real failure. |
| 49 | MCP auto-config connects wrong PM tool | Plugin detects which MCP is available and uses matching adapter. If multiple, warn and ask user. |
| 50 | Plugin + standalone mode conflict (dual state writes) | Plugin skills detect mode at startup. If crontab is also running, warn: "Disable crontab when using plugin mode." |
| 51 | Progress tracker SendMessage floods orchestrator | Rate-limit progress updates to 1 per 30 seconds per worker. Aggregate at orchestrator. |

---

## 10. Migration Path (v1 -> v2)

### For existing standalone users:
1. No breaking changes. `bin/agentflow-cron.sh` and current skills continue to work.
2. Prompts get minor upgrades (context compaction instructions, compact retry summaries).
3. `conventions.md` bumps to v2 with plugin-aware sections (ignored in standalone mode).

### To upgrade to plugin mode:
1. Install plugin: `claude plugins install agentflow` (or copy `plugin/` to `~/.claude/plugins/`)
2. Disable crontab: `crontab -e` → comment out agentflow line
3. Run: `/sdlc-orchestrate` — orchestrator creates team and begins sweeping
4. Workers spawn automatically. No iTerm tabs needed.

### Rollback:
1. Uninstall plugin
2. Re-enable crontab
3. Open iTerm tabs as before

---

## 11. What's NOT in This Spec

Explicitly out of scope for this iteration:

1. **Remote agent execution (CCR)** — designed as pluggable (local TaskType interface), implemented later
2. **GitHub Projects / Linear / Jira adapters** — adapter interface defined, implementations are separate specs
3. **Web dashboard** — plugin mode enables terminal-based live status; web dashboard is a separate project
4. **Auto-spawn recovery** — if a team member crashes, orchestrator detects via heartbeat and reassigns. Full auto-restart of crashed team members is future work.
5. **Multi-project teams** — v2 teams are per-project. Cross-project orchestration is future work.

---

## 12. Implementation Order

| Phase | What | Depends On | Est. Effort |
|---|---|---|---|
| **P1** | Repo restructure (core/ + plugin/ + bin/) | Nothing | 1 day |
| **P2** | Agent definitions (4 agents) | P1 | 1 day |
| **P3** | Hook definitions (3 hooks) | P1 | 1 day |
| **P4** | Plugin manifest + MCP config | P2, P3 | Half day |
| **P5** | Update skills for dual-mode (SendMessage awareness) | P2 | 2 days |
| **P6** | Pattern docs (6 patterns in docs/patterns/) | Nothing | 1 day |
| **P7** | Update prompts with context compaction | P6 | 1 day |
| **P8** | Update conventions.md to v2 | P5, P6 | Half day |
| **P9** | Update README, getting-started, architecture docs | All | 1 day |
| **P10** | Gap registry update (gaps 46-51) | P5 | Half day |
| **P11** | setup.sh update (detect Claude Code, offer plugin install) | P4 | Half day |

**Total estimated: ~9 working days**

P1-P4 can run in parallel with P6. P5 and P7 are the core integration work.

---

## 13. Success Criteria

AgentFlow v2 is done when:

1. [ ] `plugin/` directory installs as a working Claude Code plugin
2. [ ] `/sdlc-orchestrate` in plugin mode creates a sprint team and dispatches work
3. [ ] Workers spawn automatically in worktrees (no manual iTerm tabs)
4. [ ] Builder-to-reviewer handoff happens via SendMessage in <30 seconds (not 15 min)
5. [ ] lint-gate hook blocks `git commit` when tsc/lint/test fail
6. [ ] coverage-gate Stop hook prevents tester from merging without 80% coverage
7. [ ] scope-guard warns on first 2 unpredicted files, blocks on 3rd
8. [ ] Standalone mode continues to work unchanged
9. [ ] All 45 existing gaps still addressed (no regressions)
10. [ ] 6 new gaps (46-51) addressed
