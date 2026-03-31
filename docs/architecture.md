# AgentFlow Architecture

> How AgentFlow turns your Kanban board into an autonomous AI software development pipeline with full observability, deterministic quality gates, and built-in cost controls.

## Core Principle

**Your project management tool IS the orchestration layer.**

AgentFlow doesn't build a separate database, message queue, or custom infrastructure. It reads and writes pipeline state directly to your Kanban board (Asana, GitHub Projects, Linear, Jira). This gives you:

- **Crash recovery for free**: State survives agent crashes because it lives in your PM tool
- **Phone-accessible observability**: Monitor the entire pipeline from any device
- **Human override at any point**: Drag a card to "Needs Human" to intervene
- **Audit trail built-in**: Every agent decision is a comment on the task card

## System Components

### 1. The Orchestrator (`/sdlc-orchestrate`)

A **stateless, one-shot sweep** that runs via real crontab — not a daemon, not a session-based scheduler.

```
*/15 * * * * /usr/local/bin/claude -p "Run /sdlc-orchestrate" >> /tmp/sdlc-orchestrate.log 2>&1
```

Each sweep:
1. Discovers all pipeline projects
2. Checks for spec drift (SHA-256 hash comparison)
3. Detects dead workers (heartbeat timeout > 10 min)
4. Processes stage transitions based on comment tags
5. Triggers feedback loops for rejected tasks
6. Dispatches ready tasks to available worker slots
7. Runs system-level retrospective (every 10 completions)
8. Updates the status dashboard
9. Checks for graceful shutdown signals

**Why stateless?** Session-based schedulers die with the terminal. A real crontab entry survives reboots, terminal crashes, and network interruptions. The orchestrator reads all state from the Kanban board on every sweep — it has no memory between invocations.

### 2. Workers (`/sdlc-worker --slot T<N>`)

Each worker is a Claude Code session bound to a slot identifier (T2, T3, T4, T5). Workers:

1. Query the Kanban board for tasks assigned to their slot
2. Determine the current stage from task metadata
3. Execute the appropriate stage prompt (research, build, review, test)
4. Post results as structured comments with machine-readable tags
5. Update task metadata (stage, cost, retry count)

Workers are stateless between tasks. When a worker finishes one task, it checks for the next assigned task. If none, it reports idle.

### 3. The Kanban Board (State Machine)

The board has 8 columns (sections):

```
0 - Needs Human  │  1 - Backlog  │  2 - Research  │  3 - Build
4 - Review        │  5 - Test     │  6 - Integrate │  7 - Done
```

**State is stored in two places:**

1. **Task position** (which column) — the current pipeline stage
2. **Task description header** — metadata: `[SLOT:T2] [STAGE:Build] [RETRY:1] [COST:~$2.50]`
3. **Task comments** — structured event log with machine-readable tags

### 4. Deterministic Quality Gates

Before any AI review happens, deterministic checks run:

```
tsc --noEmit → eslint → npm test
```

This catches ~60% of issues (type errors, lint violations, failing tests) at near-zero cost. Only code that passes all three gates reaches the AI reviewer.

**After review**, a coverage gate runs:

```
npm test -- --coverage
```

New files must have ≥80% test coverage to proceed to the Test stage.

### 5. Feedback Loops

When a task fails (review reject, test fail, integration fail):

1. Retry counter increments
2. Accumulated context is posted: what was tried, what failed, what to do differently
3. Worker slot is cleared (on retry 2+, a different worker is assigned)
4. Task moves back to Build stage
5. Cost is updated and checked against guardrails

This creates a **learning loop** where each retry carries the full history of previous attempts.

### 6. System-Level Learning

Every 10 completed tasks, the orchestrator runs a retrospective:

1. Reads all reject/fail comments from completed tasks
2. Identifies common failure patterns (same error type appearing 3+ times)
3. Writes patterns to `LEARNINGS.md` in the project root
4. Future builders and reviewers read `LEARNINGS.md` before starting work

This means the system gets better over time — mistakes made in task 5 are avoided in task 50.

## Data Flow

```
SPEC.md
    │
    ▼
/spec-to-asana (decompose + validate + create)
    │
    ▼
Kanban Board (Asana)
    │
    ├── Orchestrator reads state every 15 min
    │   ├── Detects transitions (comment tags)
    │   ├── Moves cards between columns
    │   ├── Assigns slots to ready tasks
    │   └── Updates status dashboard
    │
    ├── Worker T2 reads assigned task
    │   ├── Executes build prompt
    │   ├── Posts [BUILD:STARTED] + [HEARTBEAT]
    │   ├── Creates PR
    │   ├── Runs lint gate
    │   └── Posts [BUILD:COMPLETE] + [LINT:PASS]
    │
    ├── Worker T4 reads task in Review
    │   ├── Executes adversarial review prompt
    │   ├── Checks scope (diff vs predicted files)
    │   └── Posts [REVIEW:PASS] or [REVIEW:REJECT]
    │
    ├── Worker T5 reads task in Test
    │   ├── Runs full test suite
    │   ├── Checks coverage
    │   ├── Merges PR
    │   └── Runs integration check on main
    │
    └── Human reads board on phone
        ├── Sees real-time pipeline status
        ├── Reads agent comments/decisions
        └── Can drag cards to intervene
```

## Cost Model

AgentFlow tracks costs per task using stage cost ceilings as estimates:

| Stage | Estimated Cost | What's Measured |
|-------|---------------|-----------------|
| Research | ~$1.00 | Token cost for context gathering |
| Build | ~$3.00 | Code generation + local testing |
| Review | ~$0.50 | Code reading + analysis |
| Test | ~$1.00 | Test execution + validation |
| Integrate | ~$0.25 | Quick suite run on main |

**Orchestrator cost (crontab):**
- Default (`*/15`): ~$48/day (96 sweeps × ~$0.50/sweep)
- Sprint mode (`*/5`): ~$144/day (288 sweeps × ~$0.50/sweep)

**Per-task guardrails:**
- Warning at $5 → `[COST:WARNING]` comment
- Hard stop at $15 → `[COST:CRITICAL]` → task moves to Needs Human

## Adapter Architecture

AgentFlow uses adapters to abstract the PM tool interface:

```
AgentFlow Core (skills + prompts + conventions)
    │
    ▼
Adapter Interface
    ├── create_project(name, sections)
    ├── create_task(project, section, description)
    ├── move_task(task, section)
    ├── add_comment(task, body)
    ├── get_comments(task)
    ├── search_tasks(query)
    ├── update_task_description(task, description)
    └── get_sections(project)
    │
    ├── Asana Adapter (MCP) ← available
    ├── GitHub Projects Adapter ← planned
    ├── Linear Adapter ← planned
    └── Jira Adapter ← planned
```

Each adapter maps these operations to the specific PM tool's API. The core skills and prompts never reference a specific tool — they use the adapter interface.

## Security Model

- **No secrets in code**: Mock values in tests, `process.env.X` in implementation
- **No force-push**: Integration failures create revert commits
- **No unreviewed merges**: Every PR goes through deterministic gates + adversarial AI review
- **Cost containment**: Automatic hard stops prevent runaway spending
- **Scope containment**: PR file changes compared against predicted files
- **Worker isolation**: Each worker operates in its own git worktree

## Failure Modes and Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Worker crashes mid-build | No heartbeat for 10 min | Orchestrator reassigns to different slot |
| Integration breaks main | Tests fail after merge | Auto-revert via `git revert` (new commit) |
| Task is impossible | 2+ build failures | `[BUILD:BLOCKED]` → Needs Human |
| Spec changes mid-sprint | SHA-256 hash mismatch | All tasks flagged `[NEEDS:REVALIDATION]` |
| Cost runaway | Per-task tracking | Warning at $5, hard stop at $15 |
| All slots busy | Orchestrator checks availability | Tasks wait in Backlog until slot frees |
| Circular dependencies | Topological sort at decomposition | Blocked before tasks are created |
| Shared file conflicts | Predicted files comparison | Parallel tasks serialized |
