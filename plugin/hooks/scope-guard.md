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
