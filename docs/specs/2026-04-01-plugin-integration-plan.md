# AgentFlow v2: Plugin Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure AgentFlow into a dual-mode repo (standalone + Claude Code plugin) with team-based agent spawning, infrastructure-level quality gates via hooks, and 6 architectural patterns from Claude Code's source.

**Architecture:** Three-layer repo: `core/` (portable prompts, conventions, adapters), `plugin/` (Claude Code agents, hooks, skills, MCP config), `bin/` (standalone crontab). Plugin mode uses TeamCreate for worker spawning with SendMessage for instant handoffs, falling back to Asana comments as durable state.

**Tech Stack:** Claude Code plugin system (markdown agent/hook/skill definitions), Asana MCP, git worktrees for worker isolation.

---

## File Structure

### Files to CREATE:

```
plugin/plugin.json                      # Plugin manifest
plugin/.mcp.json                        # MCP auto-configuration
plugin/agents/sdlc-orchestrator.md      # Orchestrator agent definition
plugin/agents/sdlc-builder.md           # Builder worker agent
plugin/agents/sdlc-reviewer.md          # Reviewer worker agent
plugin/agents/sdlc-tester.md            # Tester worker agent
plugin/hooks/lint-gate.md               # PreToolUse: blocks commit without passing gates
plugin/hooks/coverage-gate.md           # Stop: blocks tester completion without coverage
plugin/hooks/scope-guard.md             # PreToolUse: warns/blocks unpredicted file edits
plugin/skills/spec-to-board.md          # Decompose spec (plugin-aware version)
plugin/skills/sdlc-worker.md            # Unified worker skill (plugin-aware)
plugin/skills/sdlc-orchestrate.md       # Orchestration skill (plugin-aware)
plugin/skills/sdlc-stop.md              # Graceful shutdown (plugin-aware)
plugin/skills/sdlc-health.md            # Health check (plugin-aware)
plugin/skills/sdlc-demo.md              # Demo skill (plugin-aware)
core/prompts/decompose.md               # Moved from prompts/
core/prompts/research.md                # Moved from prompts/
core/prompts/build.md                   # Moved + updated with compaction
core/prompts/review.md                  # Moved from prompts/
core/prompts/test.md                    # Moved from prompts/
core/conventions.md                     # Moved + updated to v2
core/adapters/interface.md              # Adapter contract definition
core/adapters/asana/README.md           # Moved from adapters/asana/
core/adapters/github-projects/README.md # Moved from adapters/github-projects/
docs/patterns/coordinator.md            # Reference: coordinator mode pattern
docs/patterns/progress-tracker.md       # Reference: progress tracker pattern
docs/patterns/permission-classifiers.md # Reference: permission classifiers
docs/patterns/streaming-status.md       # Reference: async streaming pattern
docs/patterns/complexity-gating.md      # Reference: feature flag gating
docs/patterns/context-compaction.md     # Reference: context compaction
```

### Files to MOVE:

```
prompts/*           -> core/prompts/*
conventions.md      -> core/conventions.md
adapters/*          -> core/adapters/*
skills/*            -> (kept as standalone reference, content duplicated into plugin/skills/)
```

### Files to MODIFY:

```
README.md                  # Dual-mode installation + plugin section
docs/architecture.md       # Updated for v2 architecture
docs/getting-started.md    # Plugin install path added
docs/gap-registry.md       # Gaps 46-51 added
setup.sh                   # Detect Claude Code, offer plugin install
core/prompts/build.md      # Context compaction instructions added
core/conventions.md        # v2 with plugin-aware sections
```

---

## Task 1: Repo Restructure — Create `core/` Directory

**Files:**
- Create: `core/prompts/` (directory)
- Create: `core/adapters/` (directory)
- Move: `prompts/*.md` -> `core/prompts/*.md`
- Move: `conventions.md` -> `core/conventions.md`
- Move: `adapters/*` -> `core/adapters/*`

- [ ] **Step 1: Create core directory structure**

```bash
cd /Users/habeebrahman/projects/agentflow
mkdir -p core/prompts core/adapters/asana core/adapters/github-projects
```

- [ ] **Step 2: Move prompts to core/**

```bash
cp prompts/decompose.md core/prompts/decompose.md
cp prompts/research.md core/prompts/research.md
cp prompts/build.md core/prompts/build.md
cp prompts/review.md core/prompts/review.md
cp prompts/test.md core/prompts/test.md
```

- [ ] **Step 3: Move conventions to core/**

```bash
cp conventions.md core/conventions.md
```

- [ ] **Step 4: Move adapters to core/**

```bash
cp adapters/asana/README.md core/adapters/asana/README.md
cp adapters/github-projects/README.md core/adapters/github-projects/README.md
```

- [ ] **Step 5: Create adapter interface definition**

Create `core/adapters/interface.md`:

```markdown
# AgentFlow Adapter Interface

Every PM tool adapter must implement these operations. The core skills and prompts
reference these operations generically — never a specific PM tool.

## Required Operations

| Operation | Description | Returns |
|---|---|---|
| `create_project(name, sections[])` | Create a new project with named sections | project_id |
| `create_task(project_id, section, name, description)` | Create a task in a section | task_id |
| `move_task(task_id, section)` | Move a task to a different section | void |
| `add_comment(task_id, body)` | Add a comment to a task | comment_id |
| `get_comments(task_id, limit?)` | Get comments on a task (newest first) | comment[] |
| `search_tasks(query)` | Search tasks by text | task[] |
| `update_task_description(task_id, description)` | Update task description | void |
| `get_sections(project_id)` | Get all sections in a project | section[] |
| `get_tasks(section_id)` | Get all tasks in a section | task[] |
| `complete_task(task_id)` | Mark a task as complete | void |

## Adapter Mapping

### Asana (via Asana MCP)
- `create_project` -> `create_project_preview` + `create_project_confirm`
- `create_task` -> `create_task_preview` + `create_task_confirm`
- `move_task` -> `update_tasks` (move to section)
- `add_comment` -> `add_comment`
- `get_comments` -> `get_task` (includes comments)
- `search_tasks` -> `search_tasks_preview`
- `update_task_description` -> `update_tasks`
- `get_sections` -> `get_project` (includes sections)
- `get_tasks` -> `get_tasks`
- `complete_task` -> `update_tasks` (mark complete)

### GitHub Projects (planned)
- Uses `gh` CLI commands
- Projects as project boards
- Issues as tasks
- Labels as sections/stages
- Issue comments as comments

### Linear (planned)
- Uses Linear MCP or API
- Projects as projects
- Issues as tasks
- Status as sections/stages
- Issue comments as comments
```

- [ ] **Step 6: Verify structure and commit**

```bash
cd /Users/habeebrahman/projects/agentflow
ls -R core/
git add core/
git commit -m "feat: create core/ directory with portable prompts, conventions, and adapters"
```

---

## Task 2: Create Plugin Directory Structure

**Files:**
- Create: `plugin/plugin.json`
- Create: `plugin/.mcp.json`
- Create: `plugin/agents/` (directory)
- Create: `plugin/hooks/` (directory)
- Create: `plugin/skills/` (directory)

- [ ] **Step 1: Create plugin directory structure**

```bash
cd /Users/habeebrahman/projects/agentflow
mkdir -p plugin/agents plugin/hooks plugin/skills
```

- [ ] **Step 2: Create plugin manifest**

Create `plugin/plugin.json`:

```json
{
  "name": "agentflow",
  "version": "2.0.0",
  "description": "Autonomous AI development pipeline using your Kanban board as the orchestration layer. Spawns builder, reviewer, and tester agents as a team with instant handoffs and infrastructure-level quality gates.",
  "author": "UrRhb",
  "license": "MIT",
  "homepage": "https://github.com/UrRhb/agentflow",
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

- [ ] **Step 3: Create MCP auto-configuration**

Create `plugin/.mcp.json`:

```json
{
  "mcpServers": {
    "asana": {
      "type": "remote",
      "url": "https://mcp.claude.ai/asana"
    }
  }
}
```

- [ ] **Step 4: Verify and commit**

```bash
cd /Users/habeebrahman/projects/agentflow
ls -R plugin/
cat plugin/plugin.json | python3 -m json.tool  # validate JSON
cat plugin/.mcp.json | python3 -m json.tool
git add plugin/
git commit -m "feat: create plugin/ directory with manifest and MCP config"
```

---

## Task 3: Agent Definitions — Orchestrator

**Files:**
- Create: `plugin/agents/sdlc-orchestrator.md`

- [ ] **Step 1: Create orchestrator agent definition**

Create `plugin/agents/sdlc-orchestrator.md`:

```markdown
---
name: sdlc-orchestrator
description: "AgentFlow orchestrator. Performs stateless sweep: reads Kanban state, creates sprint team, dispatches tasks to workers, handles stage transitions, tracks costs, detects dead workers."
whenToUse: "When running pipeline orchestration via /sdlc-orchestrate in plugin mode"
model: haiku
maxTurns: 100
tools:
  - AgentTool
  - Read
  - Glob
  - Grep
  - Bash
  - SendMessageTool
  - TeamCreateTool
  - TeamDeleteTool
requiredMcpServers:
  - asana
color: "#8B5CF6"
---

You are the AgentFlow orchestrator. You perform ONE stateless sweep of all pipeline projects, then exit.

## Your Role

You are the fleet commander. You do NOT write code. You:
1. Read pipeline state from the Kanban board (via Asana MCP)
2. Create or reuse the sprint team (T2-T5 workers)
3. Check for dead workers (no heartbeat for 10 min)
4. Process stage transitions based on comment tags
5. Dispatch ready tasks to available workers via SendMessage
6. Update the status dashboard
7. Exit

## Team Management

On first sweep (no existing team), create the sprint team:

```
TeamCreate({
  name: "sprint-team",
  members: [
    { agent: "sdlc-builder",  name: "T2", isolation: "worktree" },
    { agent: "sdlc-builder",  name: "T3", isolation: "worktree" },
    { agent: "sdlc-reviewer", name: "T4", isolation: "worktree" },
    { agent: "sdlc-tester",   name: "T5", isolation: "worktree" }
  ]
})
```

On subsequent sweeps, check team health. If a member is unresponsive, replace it.

## Dispatch Protocol

When dispatching a task to a worker, use SendMessage:

```
SendMessage(to: "T2", message: "Build [APP-007]. <full task context from Asana>")
```

Workers also post structured tags to Asana as durable state. You read Asana for transitions.

## Read the Full Orchestration Protocol

Before your first action, read the orchestration skill for the complete sweep process:
1. Read `core/conventions.md` for all tag formats and rules
2. Follow the sweep steps from the orchestration skill exactly
```

- [ ] **Step 2: Commit**

```bash
git add plugin/agents/sdlc-orchestrator.md
git commit -m "feat: add orchestrator agent definition with team management"
```

---

## Task 4: Agent Definitions — Builder, Reviewer, Tester

**Files:**
- Create: `plugin/agents/sdlc-builder.md`
- Create: `plugin/agents/sdlc-reviewer.md`
- Create: `plugin/agents/sdlc-tester.md`

- [ ] **Step 1: Create builder agent definition**

Create `plugin/agents/sdlc-builder.md`:

```markdown
---
name: sdlc-builder
description: "AgentFlow builder worker. Executes Build stage: reads task from Kanban, writes production code, creates PR, runs lint gate. Posts structured tags to Asana and progress to orchestrator via SendMessage."
whenToUse: "When the orchestrator dispatches a task to the Build stage"
model: sonnet
isolation: worktree
maxTurns: 50
tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - AgentTool
  - SendMessageTool
requiredMcpServers:
  - asana
color: "#3B82F6"
---

You are an AgentFlow builder worker. You write production code for one task at a time.

## Your Role

You receive a task via SendMessage from the orchestrator. You:
1. Read the task description from Asana (summary, acceptance criteria, predicted files)
2. Read project CLAUDE.md and LEARNINGS.md
3. Post [BUILD:STARTED] to Asana
4. Enter a git worktree for this task
5. Write code following project conventions
6. Write tests
7. Run the lint gate (tsc + eslint + npm test)
8. Create a PR
9. Post [BUILD:COMPLETE] with PR link to Asana
10. Notify the reviewer directly: SendMessage(to: "T4", "Build complete for [TASK]. PR #N ready for review.")

## Context Management

Monitor your context usage:
- At 50%: compact old research findings into summaries
- At 70%: aggressive compaction — keep only latest retry context + current work
- At 90%: post full state as Asana comment, terminate cleanly

## Read the Full Build Protocol

Before writing code, read `core/prompts/build.md` for the complete build process.
Read `core/conventions.md` for tag formats, cost profiles, and metadata rules.
```

- [ ] **Step 2: Create reviewer agent definition**

Create `plugin/agents/sdlc-reviewer.md`:

```markdown
---
name: sdlc-reviewer
description: "AgentFlow adversarial reviewer. Performs staff-engineer-level code review. Must find 3 issues before deciding to pass. Cannot modify code — enforced by disallowedTools."
whenToUse: "When the orchestrator dispatches a task to the Review stage"
model: sonnet
isolation: worktree
maxTurns: 20
tools:
  - Read
  - Glob
  - Grep
  - Bash
  - SendMessageTool
disallowedTools:
  - Edit
  - Write
  - AgentTool
requiredMcpServers:
  - asana
color: "#F59E0B"
---

You are an AgentFlow adversarial code reviewer. Your job is to find problems.

## Your Role

You receive a task via SendMessage from the builder or orchestrator. You:
1. Read the task description from Asana (acceptance criteria, predicted files)
2. Read the [BUILD:COMPLETE] comment to get the PR link
3. Read project CLAUDE.md and LEARNINGS.md
4. Run scope check (PR files vs predicted files)
5. Read the full PR diff
6. Run the adversarial review checklist
7. Find at least 3 issues before deciding to pass
8. Post [REVIEW:PASS] or [REVIEW:REJECT] to Asana
9. If pass: notify tester directly: SendMessage(to: "T5", "Review passed for [TASK]. Ready for test.")

## Critical Rule

You CANNOT modify code. Your Edit and Write tools are disabled. You can only read, search, and run commands. This enforces separation of concerns — you find problems, the builder fixes them.

## Read the Full Review Protocol

Before reviewing, read `core/prompts/review.md` for the complete review process.
Read `core/conventions.md` for tag formats and review rules.
```

- [ ] **Step 3: Create tester agent definition**

Create `plugin/agents/sdlc-tester.md`:

```markdown
---
name: sdlc-tester
description: "AgentFlow tester. Runs full test suite, checks coverage (>=80% on new files), merges PR, runs integration check on main. Auto-reverts on failure."
whenToUse: "When the orchestrator dispatches a task to the Test stage"
model: sonnet
isolation: worktree
maxTurns: 30
tools:
  - Bash
  - Read
  - Glob
  - Grep
  - SendMessageTool
requiredMcpServers:
  - asana
color: "#10B981"
---

You are an AgentFlow tester. You validate, merge, and verify integration.

## Your Role

You receive a task via SendMessage from the reviewer or orchestrator. You:
1. Check out the feature branch
2. Run full test suite (npm test)
3. Run linter and TypeScript check
4. Run the task's verification command
5. Run coverage check (npm test -- --coverage)
6. If all pass: acquire merge lock, merge PR, run integration check on main
7. Post [TEST:PASS] + [INTEGRATE:PASS] or appropriate failure tags to Asana
8. If integration fails: auto-revert via git revert (new commit, never force-push)

## Merge Lock Protocol

Before merging, check the Status task for [MERGE_LOCK]. If another task holds the lock, wait 2 minutes and retry. After merge + integration check, post [MERGE_UNLOCK].

## Read the Full Test Protocol

Before testing, read `core/prompts/test.md` for the complete test and integration process.
Read `core/conventions.md` for tag formats and merge rules.
```

- [ ] **Step 4: Commit all agent definitions**

```bash
git add plugin/agents/sdlc-builder.md plugin/agents/sdlc-reviewer.md plugin/agents/sdlc-tester.md
git commit -m "feat: add builder, reviewer, and tester agent definitions"
```

---

## Task 5: Hook Definitions — Lint Gate

**Files:**
- Create: `plugin/hooks/lint-gate.md`

- [ ] **Step 1: Create lint gate hook**

Create `plugin/hooks/lint-gate.md`:

```markdown
---
name: agentflow-lint-gate
description: "Blocks git commit and PR creation unless tsc, eslint, and npm test all pass. Enforces Gap #1 (deterministic before probabilistic) at the infrastructure level."
event: PreToolUse
tools: ["Bash"]
agent: ["sdlc-builder"]
---

# AgentFlow Lint Gate

This hook intercepts Bash tool calls from builder agents. It triggers when the command
matches a commit or PR creation pattern.

## Trigger Pattern

Activate when the Bash command contains any of:
- `git commit`
- `gh pr create`
- `git push` (only on feature branches, not main)

Do NOT activate for other Bash commands (npm install, tsc, eslint, etc. — those are
the tools themselves, not the gated action).

## Gate Checks

When triggered, run these checks IN ORDER. Stop on first failure.

### 1. TypeScript Compilation
```bash
npx tsc --noEmit 2>&1
```
If exit code != 0: BLOCK with message:
"Lint gate: TypeScript compilation failed. Fix type errors before committing."
Include the first 20 lines of error output.

### 2. ESLint
```bash
npm run lint 2>&1
```
If exit code != 0: BLOCK with message:
"Lint gate: ESLint found errors. Fix lint issues before committing."
Include the first 20 lines of error output.

### 3. Tests
```bash
npm test 2>&1
```
If exit code != 0: BLOCK with message:
"Lint gate: Tests failed. Fix failing tests before committing."
Include the first 30 lines of error output.

## On All Pass

Allow the original Bash command to proceed. No message needed.

## Edge Cases

- If `package.json` has no `lint` script: skip ESLint check, log info
- If `package.json` has no `test` script: skip test check, log info
- If `tsconfig.json` doesn't exist: skip tsc check, log info
- Never block on missing tooling — only block on failing tooling
```

- [ ] **Step 2: Commit**

```bash
git add plugin/hooks/lint-gate.md
git commit -m "feat: add lint-gate hook — blocks commits without passing tsc/lint/tests"
```

---

## Task 6: Hook Definitions — Coverage Gate and Scope Guard

**Files:**
- Create: `plugin/hooks/coverage-gate.md`
- Create: `plugin/hooks/scope-guard.md`

- [ ] **Step 1: Create coverage gate hook**

Create `plugin/hooks/coverage-gate.md`:

```markdown
---
name: agentflow-coverage-gate
description: "Prevents tester agent from completing without verifying >=80% test coverage on new files. Enforces the coverage quality gate at the infrastructure level."
event: Stop
agent: ["sdlc-tester"]
---

# AgentFlow Coverage Gate

This hook fires when the tester agent attempts to finish its turn. It ensures
the coverage threshold was met before the tester can complete (and merge the PR).

## Check

Run:
```bash
npm test -- --coverage 2>&1
```

Parse the coverage output. For each file in the task's Predicted Files list
that is marked as `(create)`:
- Check if coverage >= 80%

## Decision

If ALL new files have >= 80% coverage: ALLOW the tester to complete.

If ANY new file has < 80% coverage:
- BLOCK completion
- Inject message: "[COV:FAIL] Coverage below 80% on new files: <list files and their coverage %>. Task bounced back to Build."
- The tester should post [COV:FAIL] to Asana and update the task stage

## Edge Cases

- If no new files in predicted files list (all modifications): ALLOW — coverage
  gate only applies to newly created files
- If coverage tool is not configured (no jest --coverage support): ALLOW with
  warning logged. Do not block on missing tooling.
```

- [ ] **Step 2: Create scope guard hook**

Create `plugin/hooks/scope-guard.md`:

```markdown
---
name: agentflow-scope-guard
description: "Warns then blocks builder agents from editing files outside the task's predicted files list. 2 warnings, then hard block on 3rd unpredicted file. Prevents scope creep (Gap #17)."
event: PreToolUse
tools: ["Edit", "Write"]
agent: ["sdlc-builder"]
---

# AgentFlow Scope Guard

This hook intercepts Edit and Write tool calls from builder agents. It checks
whether the target file is in the task's Predicted Files list.

## State

The hook tracks unpredicted file edits per task (across tool calls within
the same agent session):

- `unpredicted_count`: number of unique unpredicted files edited so far
- `unpredicted_files`: list of unpredicted file paths

## Check

When the builder calls Edit or Write:
1. Extract the target file path from the tool input
2. Read the current task's Predicted Files from Asana (cached per session)
3. Normalize paths (strip leading ./ and project root prefix)
4. Check if the target file appears in the predicted files list

## Decision

If file IS in predicted files: ALLOW. No message.

If file is NOT in predicted files:
- Increment `unpredicted_count`
- If count <= 2: ALLOW the edit, but post `[SCOPE:WARNING] Builder editing unpredicted file: <path>` to Asana
- If count >= 3: BLOCK with message: "Scope guard: 3+ unpredicted files edited (<file1>, <file2>, <file3>). Update the task's Predicted Files list in Asana or flag [SCOPE:CRITICAL] for human review."

## Why Soft-Then-Hard

Builders legitimately discover they need utility files, test fixtures, or config
changes not predicted during decomposition. Hard-blocking on the first file creates
friction on every task. Two warnings + block on third balances safety with
practical flexibility.

## Edge Cases

- Files in `tests/` or `__tests__/` directories: always ALLOW (test files are
  expected even if not explicitly predicted)
- `package.json` and `package-lock.json`: always ALLOW (dependency changes are common)
- Files already warned about: don't double-count the same file path
```

- [ ] **Step 3: Commit**

```bash
git add plugin/hooks/coverage-gate.md plugin/hooks/scope-guard.md
git commit -m "feat: add coverage-gate and scope-guard hooks"
```

---

## Task 7: Plugin Skills — Orchestrate and Worker (Plugin-Aware)

**Files:**
- Create: `plugin/skills/sdlc-orchestrate.md`
- Create: `plugin/skills/sdlc-worker.md`

- [ ] **Step 1: Create plugin-aware orchestrate skill**

Create `plugin/skills/sdlc-orchestrate.md` — this is the existing `skills/sdlc-orchestrate.md` with plugin-mode additions. The full content should be:

1. Copy the entire content of `skills/sdlc-orchestrate.md` (the existing 234-line file)
2. Add a new section at the top after the frontmatter:

```markdown
---
name: sdlc-orchestrate
description: Stateless orchestrator sweep for the AgentFlow pipeline. In plugin mode, creates a sprint team and dispatches via SendMessage for instant handoffs. In standalone mode, reads/writes Asana only.
---

# /sdlc-orchestrate

## Mode Detection

Before starting the sweep, detect which mode you're running in:

**Plugin mode** (preferred): You are running as the `sdlc-orchestrator` agent with TeamCreateTool and SendMessageTool available.
- Use TeamCreate to spawn the sprint team (T2-T5)
- Use SendMessage for task dispatch (instant handoffs)
- Use SendMessage for progress tracking
- Still post structured tags to Asana (durable state)

**Standalone mode**: You are running as a regular Claude Code session via crontab.
- No team creation — workers are separate terminal sessions
- Dispatch by updating Asana task assignments
- All communication through Asana comments only
- 15-minute sweep cycle for handoffs

To detect: check if `TeamCreateTool` is available in your tool list. If yes, you're in plugin mode.

## Team Management (Plugin Mode Only)

### First Sweep: Create Team
```
TeamCreate({
  name: "sprint-team",
  members: [
    { agent: "sdlc-builder",  name: "T2", isolation: "worktree" },
    { agent: "sdlc-builder",  name: "T3", isolation: "worktree" },
    { agent: "sdlc-reviewer", name: "T4", isolation: "worktree" },
    { agent: "sdlc-tester",   name: "T5", isolation: "worktree" }
  ]
})
```

### Subsequent Sweeps: Check Team Health
If a team member is unresponsive (no progress for 10 min), replace it by removing and re-adding the member.

### Shutdown
On `/sdlc-stop`, call `TeamDelete("sprint-team")` for clean teardown.

## Dispatch Protocol (Plugin Mode)

Instead of just updating Asana task assignments, also send direct messages:

```
SendMessage(to: "T2", message: "Build [APP-007]. Task context: <full description from Asana>")
```

Workers acknowledge via SendMessage and also post to Asana.

---

[REST OF EXISTING ORCHESTRATE SKILL CONTENT FOLLOWS UNCHANGED]
(Copy the full content from skills/sdlc-orchestrate.md starting from "## Setup")
```

- [ ] **Step 2: Create plugin-aware worker skill**

Create `plugin/skills/sdlc-worker.md` — same approach: existing content with plugin-mode additions at the top:

```markdown
---
name: sdlc-worker
description: Execute a single AgentFlow pipeline stage. In plugin mode, receives dispatch via SendMessage and hands off directly to next worker. In standalone mode, polls Asana for assignments.
args: --slot T<N> (required in standalone mode, auto-assigned in plugin mode)
---

# /sdlc-worker

## Mode Detection

**Plugin mode**: You are running as a team member (sdlc-builder, sdlc-reviewer, or sdlc-tester agent). You receive tasks via SendMessage from the orchestrator or from the previous worker in the pipeline.
- No need for --slot argument (your team member name IS your slot)
- Receive dispatch via SendMessage (instant)
- Hand off to next worker via SendMessage after completing your stage
- Still post structured tags to Asana (durable state)

**Standalone mode**: You are running as a separate terminal session.
- Requires --slot T<N> argument
- Polls Asana for assigned tasks
- All communication through Asana comments only

To detect: check if `SendMessageTool` is available. If yes, you're in plugin mode.

## Handoff Protocol (Plugin Mode)

After completing your stage, notify the next worker directly:

| Your Stage | Next Worker | Message |
|---|---|---|
| Build complete | T4 (reviewer) | "Review [TASK]. PR #N ready. <PR link>" |
| Review pass | T5 (tester) | "Test [TASK]. Review passed. <PR link>" |
| Review reject | T2 or T3 (builder) | "Rebuild [TASK]. Review rejected: <reasons>" |
| Test pass | (none — integration runs inline) | — |
| Test reject | T2 or T3 (builder) | "Rebuild [TASK]. Tests failed: <reasons>" |

Also post the structured tags to Asana for durable state and human visibility.

## Progress Reporting (Plugin Mode)

Every 30 seconds, send progress to orchestrator:

```
SendMessage(to: "sdlc-orchestrator", message: {
  "type": "progress",
  "slot": "T2",
  "task": "APP-007",
  "toolUseCount": 12,
  "outputTokens": 45000,
  "activity": "Editing src/auth.ts",
  "cost": "$0.23"
})
```

Also post [HEARTBEAT] to Asana every 5 minutes (durable backup).

---

[REST OF EXISTING WORKER SKILL CONTENT FOLLOWS UNCHANGED]
(Copy the full content from skills/sdlc-worker.md starting from "## Arguments")
```

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/sdlc-orchestrate.md plugin/skills/sdlc-worker.md
git commit -m "feat: add plugin-aware orchestrate and worker skills with SendMessage handoffs"
```

---

## Task 8: Plugin Skills — Remaining Skills

**Files:**
- Create: `plugin/skills/spec-to-board.md`
- Create: `plugin/skills/sdlc-stop.md`
- Create: `plugin/skills/sdlc-health.md`
- Create: `plugin/skills/sdlc-demo.md`

- [ ] **Step 1: Create spec-to-board skill**

Copy `skills/spec-to-asana.md` to `plugin/skills/spec-to-board.md`. Change the name in frontmatter from `spec-to-asana` to `spec-to-board`. Add this section after the frontmatter:

```markdown
## PM Tool Detection

This skill works with any supported PM tool. It detects which MCP is available:
- If Asana MCP connected: use Asana operations
- If GitHub Projects MCP connected: use GitHub Projects operations (future)
- If none: report error and suggest configuring MCP

The skill uses adapter-neutral language in its operations. See `core/adapters/interface.md` for the mapping.
```

The rest of the content stays identical to `spec-to-asana.md`.

- [ ] **Step 2: Create plugin-aware stop skill**

Copy `skills/sdlc-stop.md` to `plugin/skills/sdlc-stop.md`. Add after frontmatter:

```markdown
## Plugin Mode Additions

In plugin mode, also:
1. Call `TeamDelete("sprint-team")` to clean up the agent team
2. Workers receive shutdown signal via SendMessage (faster than waiting for next Asana read)
3. No need to instruct user about crontab — the plugin handles scheduling
```

- [ ] **Step 3: Create plugin-aware health skill**

Copy `skills/sdlc-health.md` to `plugin/skills/sdlc-health.md`. Add a new check section:

```markdown
### 7. Plugin Status (Plugin Mode Only)

If running as a Claude Code plugin:
- [ ] **Plugin installed** — check if agentflow plugin is recognized
- [ ] **Agent definitions** — verify all 4 agents are loadable
- [ ] **Hook definitions** — verify all 3 hooks are loadable
- [ ] **Team status** — if sprint-team exists, report member health
- [ ] **SendMessage working** — verify inter-agent communication

Output:
```
Plugin:         [OK] v2.0.0, 4 agents, 3 hooks (or [N/A] Not in plugin mode)
```
```

- [ ] **Step 4: Create plugin-aware demo skill**

Copy `skills/sdlc-demo.md` to `plugin/skills/sdlc-demo.md`. Unchanged — demo works the same in both modes.

- [ ] **Step 5: Commit**

```bash
git add plugin/skills/
git commit -m "feat: add remaining plugin skills — spec-to-board, stop, health, demo"
```

---

## Task 9: Pattern Documentation

**Files:**
- Create: `docs/patterns/coordinator.md`
- Create: `docs/patterns/progress-tracker.md`
- Create: `docs/patterns/permission-classifiers.md`
- Create: `docs/patterns/streaming-status.md`
- Create: `docs/patterns/complexity-gating.md`
- Create: `docs/patterns/context-compaction.md`

- [ ] **Step 1: Create docs/patterns/ directory**

```bash
mkdir -p docs/patterns
```

- [ ] **Step 2: Write all 6 pattern docs**

Each pattern doc follows this format:

```markdown
# Pattern: <Name>

**Source:** `claude-code/src/<path>`
**What it does:** <1-2 sentences>
**How AgentFlow uses it:** <1-2 sentences>

## Original Implementation

<Key code/concepts from Claude Code source>

## AgentFlow Integration

<How this pattern is baked into AgentFlow's agents/hooks/skills>

## Standalone Equivalent

<What standalone mode does instead>
```

Create all 6 files with content from spec Section 6 (patterns 6.1 through 6.6). Each file should be 30-60 lines covering the source, integration, and standalone fallback.

- [ ] **Step 3: Commit**

```bash
git add docs/patterns/
git commit -m "docs: add 6 architectural patterns from Claude Code source analysis"
```

---

## Task 10: Update Build Prompt with Context Compaction

**Files:**
- Modify: `core/prompts/build.md`

- [ ] **Step 1: Read current build prompt**

Read `core/prompts/build.md` (copied from `prompts/build.md` in Task 1).

- [ ] **Step 2: Add context compaction section**

After the "## Before Writing Code" section and before "## Writing Code", add:

```markdown
### Step 1.9: Context Budget Management

Monitor your context window usage throughout the build:

**At 50% context used:**
- Compact old research findings: replace full research with a 3-sentence summary
- Compact early retry contexts (retry 1, 2) into a single "what was tried" paragraph
- Keep: current retry context, task description, LEARNINGS.md patterns

**At 70% context used:**
- Aggressive compaction: keep ONLY the latest retry context + current work
- Replace all previous comments with: "Prior attempts: <1-paragraph summary of what was tried and what failed>"
- Continue working

**At 90% context used:**
- STOP building immediately
- Post current state as an Asana comment:
  ```
  [CONTEXT:OVERFLOW]
  ## Build State at Context Limit
  Files modified: <list>
  Current progress: <what's done, what remains>
  Uncommitted changes: <git diff summary>
  Suggested next step: <what the next worker should do>
  ```
- Terminate cleanly. The orchestrator will reassign to a fresh worker.

### Compact Retry Summary Format

When reading retry context, look for the `### Compact Summary` section first. If present, read ONLY that section instead of all previous comments. This saves ~2000 tokens per retry.

If no compact summary exists (legacy format), read the full retry context but mentally summarize it to: what was tried, what failed, what to do differently.
```

- [ ] **Step 3: Verify the updated file and commit**

```bash
cd /Users/habeebrahman/projects/agentflow
git diff core/prompts/build.md  # verify changes look correct
git add core/prompts/build.md
git commit -m "feat: add context compaction instructions to build prompt"
```

---

## Task 11: Update Conventions to v2

**Files:**
- Modify: `core/conventions.md`

- [ ] **Step 1: Read current conventions**

Read `core/conventions.md`.

- [ ] **Step 2: Update version and add plugin sections**

Change version from `1` to `2` at the top.

Add a new section after "## LEARNINGS.md Management":

```markdown
## Plugin Mode

AgentFlow v2 supports two execution modes:

### Standalone Mode (v1 compatible)
- Workers: separate terminal sessions (`claude -p "/sdlc-worker --slot T<N>"`)
- Orchestrator: crontab every 15 minutes
- Communication: Asana comments only
- Gates: prompt-enforced

### Plugin Mode (v2)
- Workers: spawned as agent team via TeamCreate
- Orchestrator: runs as sdlc-orchestrator agent
- Communication: SendMessage (fast) + Asana comments (durable)
- Gates: hook-enforced (lint-gate, coverage-gate, scope-guard)

### Mode Detection
Skills detect mode by checking tool availability:
- `TeamCreateTool` available → plugin mode
- `SendMessageTool` available → plugin mode
- Neither available → standalone mode

### Dual Communication Protocol
In plugin mode, workers use BOTH channels:
1. **SendMessage** for instant handoffs and progress (ephemeral, agent-to-agent)
2. **Asana comments** for structured tags and audit trail (durable, human-visible)

If SendMessage fails, fall back to Asana-only communication. The orchestrator's next sweep recovers from Asana state.

## New Comment Tags (v2)

| Tag | Meaning |
|-----|---------|
| `[CONTEXT:OVERFLOW]` | Worker hit context window limit, state posted, needs reassignment |
| `[SCOPE:CRITICAL]` | 3+ unpredicted files, needs human review |

## Updated Gap Registry

Gaps 46-51 address plugin mode failure modes. See `docs/gap-registry.md`.
```

- [ ] **Step 3: Commit**

```bash
git add core/conventions.md
git commit -m "feat: update conventions to v2 with plugin mode sections"
```

---

## Task 12: Update Gap Registry

**Files:**
- Modify: `docs/gap-registry.md`

- [ ] **Step 1: Read current gap registry**

Read `docs/gap-registry.md`.

- [ ] **Step 2: Append gaps 46-51**

Add to the end of the file:

```markdown
## Plugin Mode Gaps (46-51)

These gaps apply only when running AgentFlow in Claude Code plugin mode.

### Gap 46: Team Agent Crashes Mid-Sprint

**Problem:** TeamCreate succeeds but a team member crashes during execution. The team is in an inconsistent state.

**Fix:** Orchestrator checks team member health on each sweep (progress tracker). If a member is unresponsive for 10 minutes, remove and re-add it. Fallback: if TeamCreate itself fails, fall back to individual AgentTool spawning and log a warning.

### Gap 47: SendMessage Dropped (Handoff Lost)

**Problem:** Builder sends "build complete" via SendMessage to reviewer, but the message is lost. Reviewer never starts.

**Fix:** Asana comments are the durable fallback. Workers always post structured tags ([BUILD:COMPLETE], etc.) to Asana in addition to SendMessage. The orchestrator's next sweep reads Asana and processes any transitions that SendMessage missed.

### Gap 48: Hook Blocks Legitimate Action (False Positive)

**Problem:** Scope-guard blocks a file edit that's actually needed. Lint-gate blocks a commit due to a pre-existing issue unrelated to the task.

**Fix:**
- scope-guard: 2-warning buffer before blocking. Test files and package.json are always allowed.
- lint-gate: only runs on feature branches (not main). If tsc/lint/test scripts don't exist, skip that check.
- coverage-gate: only checks new files, not modified files. Missing coverage tooling = allow with warning.

### Gap 49: MCP Auto-Config Connects Wrong PM Tool

**Problem:** Plugin's .mcp.json auto-configures Asana, but user has Linear configured at the project level. Two PM MCPs are connected — which one is authoritative?

**Fix:** Project-level .mcp.json takes precedence over plugin-level. The plugin detects which PM MCP is available and uses the matching adapter. If multiple PM MCPs are connected, warn the user and ask which to use.

### Gap 50: Plugin + Standalone Mode Conflict

**Problem:** User has both the crontab running (standalone mode) AND the plugin orchestrator running. Two orchestrators fight over the same tasks.

**Fix:** Plugin orchestrate skill checks for active crontab entry on startup. If found, warns: "Detected active crontab entry for agentflow-cron.sh. Disable it to avoid conflicts: `crontab -e` and comment out the line." The Asana-level [SWEEP:RUNNING] lock prevents actual conflicts, but dual-mode is wasteful and confusing.

### Gap 51: Progress Tracker SendMessage Floods Orchestrator

**Problem:** 4 workers each sending progress every 5 seconds = 48 messages per minute. The orchestrator's context fills up with progress noise.

**Fix:** Rate-limit progress updates to 1 per 30 seconds per worker (8 messages per minute total). Workers buffer progress locally and send only the latest snapshot. Orchestrator processes progress updates in bulk during the status dashboard update step, not inline.
```

- [ ] **Step 3: Commit**

```bash
git add docs/gap-registry.md
git commit -m "docs: add gaps 46-51 for plugin mode failure modes"
```

---

## Task 13: Update README for Dual-Mode

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README**

Read `README.md`.

- [ ] **Step 2: Add plugin installation section**

After the existing "### Installation" section, add a new section:

```markdown
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
```

- [ ] **Step 3: Update comparison table**

Add a row to the comparison table:

```markdown
| **Worker spawning** | Automatic (plugin) or manual (standalone) | Manual | Manual | Manual |
```

- [ ] **Step 4: Update project structure in README**

Replace the existing project structure with the v2 structure showing `core/`, `plugin/`, and `bin/` directories.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README with plugin installation and dual-mode architecture"
```

---

## Task 14: Update setup.sh for Plugin Detection

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Read current setup.sh**

Read `setup.sh`.

- [ ] **Step 2: Add plugin detection and offer**

After the Claude Code CLI detection section (section 1), add:

```bash
# ---------------------------------------------------------------------------
# 1b. Detect Claude Code plugin support
# ---------------------------------------------------------------------------
PLUGIN_MODE=false
PLUGIN_DIR="$HOME/.claude/plugins"

if [[ -d "$PLUGIN_DIR" ]]; then
  echo ""
  echo "Claude Code plugin directory detected at $PLUGIN_DIR"
  echo ""
  echo "AgentFlow can be installed as a Claude Code plugin for:"
  echo "  - Automatic worker spawning (no iTerm tabs needed)"
  echo "  - Instant handoffs between workers"
  echo "  - Infrastructure-level quality gates (hooks)"
  echo ""
  read -p "Install as plugin? [Y/n] " PLUGIN_CHOICE
  PLUGIN_CHOICE="${PLUGIN_CHOICE:-Y}"
  if [[ "$PLUGIN_CHOICE" =~ ^[Yy] ]]; then
    PLUGIN_MODE=true
  fi
fi
```

After the file copy section (section 5), add:

```bash
# ---------------------------------------------------------------------------
# 5b. Install plugin (if chosen)
# ---------------------------------------------------------------------------
if $PLUGIN_MODE; then
  PLUGIN_INSTALL_DIR="$PLUGIN_DIR/agentflow"
  mkdir -p "$PLUGIN_INSTALL_DIR"
  cp -r "$SCRIPT_DIR/plugin/"* "$PLUGIN_INSTALL_DIR/"
  info "Plugin installed to $PLUGIN_INSTALL_DIR"
  echo ""
  echo "  Plugin mode is now active. You can run:"
  echo "    claude -p '/sdlc-orchestrate'   # Start pipeline (workers spawn automatically)"
  echo ""
  echo "  No need to set up crontab or open worker terminals."
fi
```

Update the version constant:

```bash
AGENTFLOW_VERSION="2.0.0"
```

Also update the source file verification to check the new `core/` directory:

```bash
for dir in core/prompts plugin; do
```

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat: update setup.sh with plugin detection and dual-mode install"
```

---

## Task 15: Update Architecture Docs

**Files:**
- Modify: `docs/architecture.md`
- Modify: `docs/getting-started.md`

- [ ] **Step 1: Update architecture.md**

Add a new section at the top of `docs/architecture.md` after the intro:

```markdown
## v2 Architecture: Dual-Mode

AgentFlow v2 supports two execution modes from the same codebase:

### Standalone Mode
The original architecture. Workers are separate terminal sessions, orchestrator runs via crontab, all communication flows through Asana comments.

### Plugin Mode
Workers spawn as a named agent team inside Claude Code. The orchestrator creates the team, dispatches via SendMessage for instant handoffs, and hooks enforce quality gates at the tool level.

```
Standalone:                          Plugin:
┌──────────┐                         ┌──────────┐
│ Crontab  │                         │Orchestrat│
│ (sweep)  │                         │  (agent) │
└────┬─────┘                         └────┬─────┘
     │                                    │
     │ reads/writes Asana                 │ TeamCreate + SendMessage
     │                                    │
┌────┴────┐ ┌────┐ ┌────┐          ┌────┴────┐ ┌────┐ ┌────┐
│T2 (term)│ │T3  │ │T4  │          │T2 (agent│ │T3  │ │T4  │
│ manual  │ │    │ │    │          │ spawned)│ │    │ │    │
└─────────┘ └────┘ └────┘          └─────────┘ └────┘ └────┘
```

### What Changes

| Aspect | Standalone | Plugin |
|---|---|---|
| Worker spawning | Manual (iTerm tabs) | Automatic (TeamCreate) |
| Handoff latency | 15 min (sweep cycle) | <30 sec (SendMessage) |
| Quality gates | Prompt-enforced | Hook-enforced |
| Progress tracking | [HEARTBEAT] comments | Real-time telemetry |
| Communication | Asana only | SendMessage + Asana |
| Shutdown | Manual crontab edit | TeamDelete |
```

- [ ] **Step 2: Update getting-started.md**

Add a plugin quick-start section alongside the existing standalone instructions. Keep both paths documented.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture.md docs/getting-started.md
git commit -m "docs: update architecture and getting-started for v2 dual-mode"
```

---

## Task 16: Final Verification

- [ ] **Step 1: Verify directory structure**

```bash
cd /Users/habeebrahman/projects/agentflow
echo "=== CORE ===" && ls -R core/
echo "=== PLUGIN ===" && ls -R plugin/
echo "=== BIN ===" && ls bin/
echo "=== DOCS ===" && ls docs/ && ls docs/patterns/
```

Expected: all directories populated with correct files.

- [ ] **Step 2: Validate plugin.json**

```bash
cat plugin/plugin.json | python3 -m json.tool
cat plugin/.mcp.json | python3 -m json.tool
```

Expected: valid JSON, no errors.

- [ ] **Step 3: Verify all agent definitions have required fields**

```bash
for f in plugin/agents/*.md; do
  echo "--- $f ---"
  head -15 "$f"
  echo ""
done
```

Expected: each has name, description, whenToUse, model, tools, requiredMcpServers.

- [ ] **Step 4: Verify all hooks have required fields**

```bash
for f in plugin/hooks/*.md; do
  echo "--- $f ---"
  head -10 "$f"
  echo ""
done
```

Expected: each has name, event, agent (and tools for PreToolUse hooks).

- [ ] **Step 5: Verify no broken references**

```bash
# Check that core/prompts/ has all 5 prompt files
ls core/prompts/

# Check that plugin/skills/ has all 6 skill files
ls plugin/skills/

# Check that old directories still exist (backward compat)
ls prompts/ skills/
```

- [ ] **Step 6: Run a quick git status check**

```bash
git status
git log --oneline -15
```

Expected: clean working tree, ~15 commits from this implementation.

- [ ] **Step 7: Final commit if any remaining changes**

```bash
git add -A
git status  # review what's staged
git commit -m "chore: final v2 cleanup and verification"
```

---

## Summary

| Task | What | Files |
|---|---|---|
| 1 | Repo restructure — create core/ | 8 files moved/created |
| 2 | Plugin directory structure | 2 files created |
| 3 | Orchestrator agent definition | 1 file created |
| 4 | Builder/reviewer/tester agents | 3 files created |
| 5 | Lint gate hook | 1 file created |
| 6 | Coverage gate + scope guard hooks | 2 files created |
| 7 | Plugin-aware orchestrate + worker skills | 2 files created |
| 8 | Remaining plugin skills | 4 files created |
| 9 | Pattern documentation | 6 files created |
| 10 | Build prompt context compaction | 1 file modified |
| 11 | Conventions v2 | 1 file modified |
| 12 | Gap registry update | 1 file modified |
| 13 | README dual-mode | 1 file modified |
| 14 | Setup.sh plugin detection | 1 file modified |
| 15 | Architecture + getting-started docs | 2 files modified |
| 16 | Final verification | 0 files (validation) |

**Total: ~36 files created/modified across 16 tasks.**
