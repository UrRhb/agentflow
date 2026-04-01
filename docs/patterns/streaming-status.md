# Pattern: Streaming Status

**Source:** `claude-code/src/QueryEngine.ts` -- `submitMessage()` async generator yielding SDKMessage
**What it does:** Streams responses via async generators with `yield*` composition, enabling real-time progress visibility instead of blocking until completion.
**How AgentFlow uses it:** Worker progress streams through SendMessage to the orchestrator, powering live dashboards and the `/sdlc-health` command.

## Original Implementation

Claude Code's QueryEngine uses async generators to stream model output:

- **`submitMessage()`** is an async generator that yields `SDKMessage` objects
  as they arrive from the API, rather than buffering the full response.
- **`yield*` composition** allows nested generators to be composed cleanly --
  tool execution generators yield their own status updates through the parent
  message stream.
- The terminal UI consumes this stream to render live typing indicators,
  tool execution progress, and partial results.
- Backpressure is handled naturally by the generator protocol -- the consumer
  controls the pace of iteration.

This pattern enables Claude Code's responsive feel: users see activity
immediately rather than waiting for complete responses.

## AgentFlow Integration

AgentFlow adapts streaming to a distributed multi-agent architecture:

- Workers emit progress updates via `SendMessage` tool calls to the orchestrator,
  creating a pull-based status stream.
- The orchestrator aggregates streams from all active workers into a unified
  progress view.
- `/sdlc-health` reads live progress data to render a terminal-based dashboard
  showing each worker's current activity, token usage, and time since last update.
- For long-running tasks, the stream includes milestone markers (e.g., "tests
  passing", "PR opened") that the orchestrator uses for workflow decisions.

## Standalone Equivalent

Without an orchestrator, there is no live streaming:

- Status is derived from Asana task comments, which are polled rather than streamed.
- The human operator checks task comments manually for updates.
- No live dashboard or real-time progress aggregation is available.
