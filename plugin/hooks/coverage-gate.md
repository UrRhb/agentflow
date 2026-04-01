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
