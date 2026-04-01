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
