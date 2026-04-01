# Pattern: Progress Tracker

**Source:** `claude-code/src/tasks/LocalAgentTask/LocalAgentTask.tsx` -- ProgressTracker type
**What it does:** Tracks real-time agent progress through metrics like tool use count, token consumption, and recent activity history to detect stalls and report status.
**How AgentFlow uses it:** Workers stream progress via SendMessage; if toolUseCount stops incrementing for 10 minutes, the orchestrator flags a dead worker.

## Original Implementation

Claude Code's ProgressTracker type captures continuous execution telemetry:

- **toolUseCount:** Incremented each time the agent invokes a tool. A flat line
  signals the agent may be stuck in a reasoning loop or has silently failed.
- **latestInputTokens:** Token count of the most recent user/system message,
  useful for detecting context bloat.
- **cumulativeOutputTokens:** Running total of all tokens generated, used for
  cost tracking and budget enforcement.
- **recentActivities:** A rolling window of the last 5 activities (tool calls,
  messages, decisions), providing a quick snapshot of what the agent is doing
  without reading the full transcript.

These metrics are surfaced in the terminal UI, letting operators spot problems
at a glance.

## AgentFlow Integration

AgentFlow extends this pattern across a distributed worker fleet:

- Each worker streams progress updates to the orchestrator via `SendMessage` tool
  calls containing `toolUseCount`, token usage, and current activity.
- The orchestrator maintains a progress dashboard: if any worker's `toolUseCount`
  stops incrementing for 10 minutes, it is flagged as a dead worker and eligible
  for reassignment or restart.
- `[HEARTBEAT]` comments are posted to Asana tasks as a durable backup, ensuring
  progress is visible even if the orchestrator session drops.
- The `/sdlc-health` command reads these heartbeats to produce a fleet-wide
  status report.

## Standalone Equivalent

Without an orchestrator, progress tracking is minimal:

- `[HEARTBEAT]` comments on the Asana task are the only progress signal.
- The human operator monitors task comments to detect stalls.
- No automatic dead-worker detection or reassignment occurs.
