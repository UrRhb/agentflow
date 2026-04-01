# Getting Started with AgentFlow

> Set up an autonomous AI development pipeline in under 30 minutes. Full pipeline observability from your phone, deterministic quality gates, and built-in cost tracking.
>
> **Expected cost:** $44-200 per 14-task sprint depending on model choice (Sonnet vs Opus) and Superpowers usage. See [Architecture - Cost Model](architecture.md#cost-model) for details.

## Choose Your Mode

### Plugin Mode (Recommended)
If you have Claude Code installed:

1. Add the marketplace and install:
   ```bash
   claude plugin marketplace add UrRhb/agentflow
   claude plugin install agentflow
   ```
2. Create your spec and decompose: `claude -p "/spec-to-board"`
3. Start the pipeline: `claude -p "/sdlc-orchestrate"`
4. Workers spawn automatically — no iTerm tabs needed!

### Standalone Mode
If you prefer manual control:

1. Run the setup script: `./setup.sh --with-cron`
2. Create your spec and decompose: `claude -p "/spec-to-asana"`
3. Open worker terminals: `claude -p "/sdlc-worker --slot T2"` (repeat for T3-T5)
4. Orchestrator runs via crontab every 15 minutes

## Prerequisites

| Requirement | Why |
|-------------|-----|
| [Claude Code CLI](https://claude.ai/code) | Runs the AI agents |
| Asana account + MCP server | State machine (Kanban board) |
| Node.js project with `npm test` | Pipeline expects test commands |
| Git + GitHub CLI (`gh`) | PR creation and management |
| macOS/Linux with crontab | Durable orchestrator scheduling |

## Step 1: Install AgentFlow

```bash
git clone https://github.com/UrRhb/agentflow.git
cd agentflow
```

Run the setup script to install skills, prompts, conventions, and the crontab wrapper:

```bash
./setup.sh
```

This will:
- Copy skills to `~/.claude/skills/`
- Copy prompts to `~/.claude/sdlc/prompts/`
- Copy conventions to `~/.claude/sdlc/conventions.md`
- Generate `~/.claude/sdlc/agentflow-cron.sh` (wrapper that sources your shell environment)
- Install the orchestrator health watchdog
- Prompt you to select a cost profile (Sonnet or Opus)

## Step 2: Configure Asana MCP

Ensure your Asana MCP server is running and accessible from Claude Code. You need:

- An Asana workspace
- MCP server connection configured in Claude Code
- Permissions to create projects, tasks, and comments

Test the connection:

```
You: List my Asana projects
Claude: [should return your projects via MCP]
```

## Step 3: Write Your Spec

Create a `SPEC.md` in your project root. This is the input to the decomposition engine.

```markdown
# Project Name

## Overview
What this project does and why.

## Phase 1: Core Foundation

### Module 1.1: Feature Name
- Requirement 1
- Requirement 2
- Acceptance criteria

### Module 1.2: Another Feature
- Requirement 1
- Requirement 2

## Phase 2: Advanced Features
...
```

Or use Claude to brainstorm one:

```
You: I want to build [your idea]. Help me write a SPEC.md.
Claude: [brainstorms → produces structured SPEC.md]
```

## Step 4: Decompose Into Tasks

```
You: /spec-to-asana
```

This will:
1. Read your `SPEC.md`
2. Break it into atomic tasks (≤5 files each)
3. Validate: all 9 fields present, no circular dependencies, no file conflicts
4. Create the Asana project with 8 sections (Needs Human + 7 pipeline stages)
5. Create all tasks with metadata headers, dependencies, and predicted files
6. Store the SPEC.md SHA-256 hash for drift detection

**What you'll see in Asana:** A board with tasks in the "Backlog" column, each with a detailed description containing acceptance criteria, verification commands, and dependency links.

## Step 5: Set Up Worker Terminals

Open 3-4 terminal windows. Each one is a worker slot:

```bash
# Terminal 2 — Primary builder
claude -p "/sdlc-worker --slot T2"

# Terminal 3 — Secondary builder
claude -p "/sdlc-worker --slot T3"

# Terminal 4 — Reviewer (adversarial review agent)
claude -p "/sdlc-worker --slot T4"

# Terminal 5 — Tester
claude -p "/sdlc-worker --slot T5"
```

Workers will:
- Check Asana for tasks assigned to their slot
- Execute the appropriate stage prompt
- Post results as structured comments
- Update task metadata
- **Loop by default**: after completing a task, workers automatically check for the next assigned task. They continue until no tasks remain or you stop them manually.

## Step 6: Start the Orchestrator

Add the orchestrator to your crontab:

```bash
crontab -e
```

**For your first run**, trigger the orchestrator manually to verify everything works:

```
You: /sdlc-orchestrate
```

This runs a single sweep immediately so you can confirm task dispatch, worker assignment, and status updates are working before automating.

**Then set up crontab for future automation.** Add one of these lines:

```bash
# Default mode — every 15 minutes
*/15 * * * * ~/.claude/sdlc/agentflow-cron.sh >> /tmp/agentflow-orchestrate.log 2>&1

# Sprint mode — every 5 minutes (use during active dev only)
# */5 * * * * ~/.claude/sdlc/agentflow-cron.sh >> /tmp/agentflow-orchestrate.log 2>&1
```

> **Note:** The wrapper script `agentflow-cron.sh` (generated by `setup.sh`) sources your shell environment so that Claude Code, API keys, and MCP servers are available in the crontab context.

The orchestrator will:
- Scan all `[SDLC]` projects in Asana
- Process stage transitions based on comment tags
- Dispatch ready tasks to available worker slots
- Detect and reassign dead workers
- Track costs and trigger guardrails
- Update the status dashboard

## Step 7: Monitor from Your Phone

Open Asana on your phone. You'll see:
- Tasks moving between columns in real-time
- Agent comments on each card (build logs, review findings, test results)
- A pinned Status task with the full pipeline dashboard
- Cost tracking per task

**To intervene:** Drag any card to "Needs Human". The orchestrator will stop processing that task until you move it back.

## Stopping the Pipeline

```
You: /sdlc-stop
```

This gracefully:
1. Signals active workers to finish their current task
2. Moves unstarted tasks back to Backlog
3. Posts `[SYSTEM:PAUSED]` status

To fully stop, also comment out the crontab entry:

```bash
crontab -e
# Comment out: */15 * * * * /usr/local/bin/claude ...
```

To resume: uncomment the crontab entry and run `/sdlc-orchestrate` once.

## Configuration

### Adjusting Cost Guardrails

Edit `conventions.md` to change thresholds:

```
Default warning: $3 (Sonnet) or $8 (Opus) → change to your preferred warning threshold
Default hard stop: $10 (Sonnet) or $20 (Opus) → change to your preferred hard stop
```

### Adjusting Orchestrator Frequency

```bash
# Conservative (every 30 min, ~$24/day)
*/30 * * * * ...

# Default (every 15 min, ~$48/day)
*/15 * * * * ...

# Sprint (every 5 min, ~$144/day)
*/5 * * * * ...
```

### Adjusting Worker Slots

You can run 2-8 worker slots. More slots = faster throughput but higher cost. The default 4 slots (T2-T5) balances speed and cost.

### Adjusting Coverage Threshold

Edit `prompts/test.md` to change the 80% coverage requirement:

```
If new file coverage ≥ 80%: [COV:PASS]
```

## Troubleshooting

### "No tasks assigned to slot T2"
The orchestrator hasn't dispatched yet. Wait for the next crontab sweep, or run `/sdlc-orchestrate` manually.

### Worker seems stuck
Check the last heartbeat in Asana comments. If >10 min old, the orchestrator will reassign on next sweep. You can also manually clear the slot by editing the task description: `[SLOT:T2]` → `[SLOT:--]`.

### Task in "Needs Human"
Check the task comments for the reason (cost critical, build blocked, spec drift). Address the issue and move the card back to the appropriate stage.

### Integration failure
The system auto-reverted the merge. Check the `[INTEGRATE:FAIL]` comment for details. The feature branch still exists — the builder will fix and re-submit on the next retry.

### Cost running high on a task
Check `[RETRY:N]` in the description. High retry counts mean the task may need human help. Consider:
- Simplifying the acceptance criteria
- Breaking into smaller sub-tasks
- Adding more context to the task description

### Crontab orchestrator not running
The most common cause is crontab environment issues. Crontab runs in a minimal shell without your PATH or environment variables. Symptoms:
- No new sweeps (check `[LAST_SWEEP]` timestamp in the Status task)
- `/tmp/agentflow-orchestrate.log` shows "command not found" or authentication errors

**Fixes:**
1. Ensure you ran `setup.sh` which generates `~/.claude/sdlc/agentflow-cron.sh` with proper environment sourcing
2. Check the log: `tail -50 /tmp/agentflow-orchestrate.log`
3. Verify the wrapper script works manually: `~/.claude/sdlc/agentflow-cron.sh`
4. Ensure your API key is set in your shell profile (`.zshrc` or `.bashrc`), not just exported in the current session

### Orchestrator health watchdog alert
If you receive a notification that the orchestrator has not swept in >30 minutes:
1. Check if the crontab entry is still active: `crontab -l`
2. Check the log for errors: `tail -100 /tmp/agentflow-orchestrate.log`
3. Run a manual sweep: `/sdlc-orchestrate`
4. If the machine was asleep, the crontab will resume automatically on wake

## Next Steps

- Read the [Architecture docs](architecture.md) for a deep-dive into how the system works
- Review the [Gap Registry](gap-registry.md) to understand the 45 failure modes AgentFlow addresses
- Check the [Comparison](comparison.md) to see how AgentFlow differs from other tools
- See [examples/](../examples/) for starter templates
