# Pattern: Context Compaction

**Source:** `claude-code/src/query.ts` -- reactive compaction, `src/services/compact/`
**What it does:** Auto-compresses older messages when context window usage crosses thresholds, preserving recent context while discarding redundant history.
**How AgentFlow uses it:** Workers monitor their own context usage and apply progressively aggressive compaction, terminating cleanly at critical thresholds.

## Original Implementation

Claude Code implements reactive context compaction with multiple strategies:

- **Threshold-based triggers:** Compaction activates automatically when context
  usage crosses defined thresholds (e.g., 50%, 70%, 90%), with increasing
  aggressiveness at each level.
- **Message summarization:** Older messages are replaced with compact summaries
  that preserve key decisions, file paths modified, and current task state.
- **Recency preservation:** Recent messages (typically the last 5-10 turns) are
  always kept verbatim, as they contain the most relevant working context.
- **The `/compact` command** lets users trigger compaction manually when they
  notice degraded output quality.

This pattern is critical because model precision degrades significantly above
70% context utilization -- compaction is not just about fitting more content,
but about maintaining output quality.

## AgentFlow Integration

AgentFlow builds context management into the worker lifecycle:

- **50% threshold -- compact research:** Workers summarize exploration results
  (file reads, grep outputs, architecture analysis) into condensed findings.
  Implementation details are discarded; conclusions are kept.
- **70% threshold -- aggressive compaction:** Workers compress everything except
  the current task state, active plan step, and recent tool outputs. This is
  the "save yourself" threshold.
- **90% threshold -- post state and terminate:** Workers write their full current
  state (task progress, files modified, blockers found) to an Asana comment,
  then terminate cleanly. A new worker picks up from the posted state.
- **Retry contexts** include a Compact Summary (under 500 tokens) from the
  previous worker's final state, giving the new worker enough context to
  continue without re-reading the full history.

## Standalone Equivalent

Standalone mode relies on prompt-level instructions:

- Workers are told: "If context exceeds 70%, post your current state to the
  task and stop."
- There is no automated threshold detection -- the worker must self-assess.
- No compact summary is generated; the next worker reads the raw Asana
  comments to reconstruct context.
