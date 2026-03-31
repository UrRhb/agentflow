# AgentFlow Conventions

> Source of truth for the entire AgentFlow pipeline. All skills, prompts, and adapters reference this document.

## Task Naming

```
[CODE-NNN] <verb> <noun>
```

- `CODE` = project code (e.g., `APP`, `API`, `WEB`)
- `NNN` = sequential number within project
- Verb = action (Add, Create, Implement, Fix, Refactor, Configure, Update)
- Noun = what's being built

Examples:
- `[APP-001] Create user authentication flow`
- `[API-005] Add rate limiting middleware`
- `[WEB-012] Fix responsive layout on dashboard`

## Pipeline Stages

| # | Stage | Section Name | Description |
|---|-------|-------------|-------------|
| 0 | Needs Human | 0 - Needs Human | Blocked, cost-critical, or requires manual intervention |
| 1 | Backlog | 1 - Backlog | Ready for dispatch (dependencies may be pending) |
| 2 | Research | 2 - Research | Conditional — gathering external knowledge |
| 3 | Build | 3 - Build | Agent writing code + creating PR |
| 4 | Review | 4 - Review | Adversarial AI review + coverage gate |
| 5 | Test | 5 - Test | Full test suite + visual validation |
| 6 | Integrate | 6 - Integrate | Merge to main + integration check |
| 7 | Done | 7 - Done | Task complete |

## Metadata Header

Every task description starts with a metadata header:

```
[SLOT:--] [STAGE:Backlog] [RETRY:0] [COST:~$0]
```

- `[SLOT:--]` or `[SLOT:T2]` — assigned worker slot (T2-T5, -- = unassigned)
- `[STAGE:X]` — current pipeline stage
- `[RETRY:N]` — number of feedback loop iterations
- `[COST:~$N]` — accumulated cost estimate

## Comment Tags

Machine-readable tags posted as Asana comments. The orchestrator and workers parse these to determine state.

### Stage Completion Tags
| Tag | Meaning |
|-----|---------|
| `[RESEARCH:COMPLETE]` | Research finished, findings posted |
| `[RESEARCH:SKIP]` | No research triggers — skipped |
| `[BUILD:STARTED]` | Worker began building |
| `[BUILD:COMPLETE]` | Code written, PR created |
| `[LINT:PASS]` | Deterministic gate passed (tsc + lint + tests) |
| `[LINT:FAIL]` | Deterministic gate failed |
| `[REVIEW:PASS]` | AI review approved |
| `[REVIEW:REJECT]` | AI review found issues |
| `[COV:PASS]` | Coverage gate passed (≥80% on new files) |
| `[COV:FAIL]` | Coverage below threshold |
| `[TEST:PASS]` | Test suite passed, PR merged |
| `[TEST:REJECT]` | Test suite or validation failed |
| `[INTEGRATE:PASS]` | Main branch healthy after merge |
| `[INTEGRATE:FAIL]` | Main branch broken, auto-reverted |

### System Tags
| Tag | Meaning |
|-----|---------|
| `[HEARTBEAT]` | Worker is alive (posted every 5 min) |
| `[REASSIGNED]` | Dead worker detected, slot cleared |
| `[COST:WARNING]` | Task cost exceeded $5 |
| `[COST:CRITICAL]` | Task cost exceeded $15, moved to Needs Human |
| `[BUILD:BLOCKED]` | Task evaluated as impossible after 2+ failures |
| `[SCOPE:WARNING]` | PR modifies files outside predicted list |
| `[SPEC:CHANGED]` | Source spec modified since decomposition |
| `[SPEC:CONTINUE]` | Human approved continuing despite spec change |
| `[SPEC:REDECOMPOSE]` | Human requested re-decomposition |
| `[NEEDS:MANUAL_VERIFY]` | Task requires real API/secret for final verification |
| `[NEEDS:REVALIDATION]` | Task needs revalidation due to spec change |
| `[SYSTEM:PAUSING]` | Graceful shutdown initiated |
| `[SYSTEM:PAUSED]` | Shutdown complete |
| `[RETROSPECTIVE]` | System-level learning cycle completed |
| `[HOLD]` | Human placed task on hold |
| `[RETRY:N]` | Feedback loop iteration count |

## Task Description Template

Every task must include these 9 required fields:

```markdown
[SLOT:--] [STAGE:Backlog] [RETRY:0] [COST:~$0]

## Summary
<What this task does — one sentence>

## Input State
<What must be true before this task starts — file states, dependencies met>

## Output State
<What will be true after this task completes — files created/modified, behavior changes>

## Acceptance Criteria
- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] <Criterion 3>

## Verification Command
<Single command that proves the task works>
```bash
npm test -- --grep "feature-name"
```

## Predicted Files
- `src/path/to/file.ts` (create)
- `src/path/to/other.ts` (modify)
- `tests/path/to/test.ts` (create)

## Dependencies
- [CODE-NNN] <task name> — <why this must complete first>

## Research Triggers
- [ ] Uses unfamiliar library: <library name>
- [ ] Involves external API: <API name>
- [ ] Complex algorithm: <description>
(Empty = no research needed)

## Complexity
<Simple | Medium | Complex>
<Estimated hours: N>
```

## Atomicity Rules

A task is atomic if:

1. It can be built, reviewed, tested, and merged independently
2. It modifies ≤5 files
3. It has a single verification command
4. It produces a meaningful, working increment
5. Its PR can be reviewed in under 15 minutes
6. It doesn't require changes to more than 2 modules
7. Rolling it back wouldn't break other completed tasks

## Cost Ceilings Per Stage

| Stage | Cost Ceiling | Notes |
|-------|-------------|-------|
| Research | ~$1.00 | Token cost for context gathering |
| Build | ~$3.00 | Code generation + local testing |
| Review | ~$0.50 | Reading + analysis |
| Test | ~$1.00 | Test execution + validation |
| Integrate | ~$0.25 | Quick suite run on main |

**Guardrails:**
- Warning at $5 total per task → `[COST:WARNING]`
- Hard stop at $15 total per task → `[COST:CRITICAL]` → Needs Human

## Dispatch Priority

Priority is calculated as:

```
priority = count of tasks transitively blocked by this task
```

Higher count = higher priority. This automatically identifies the critical path.

**Tie-breaking:** Earlier task code number wins.

## Worker Slot Assignments

| Slot | Preferred Role | Notes |
|------|---------------|-------|
| T2 | Build/Research | Primary builder |
| T3 | Build/Research | Secondary builder |
| T4 | Review | Dedicated reviewer |
| T5 | Test | Dedicated tester |

- If preferred slot is busy, any available slot is used
- A reviewer must NEVER be the same slot that built the task
- On retry 2+, a DIFFERENT worker than the previous attempt should be assigned

## Research Source Priority

1. **Codebase** (free) — existing patterns, similar implementations
2. **Documentation tools** (e.g., Context7 — no rate limit) — official library docs
3. **Web search** (rate-limited) — blog posts, tutorials, Stack Overflow
4. **GitHub** (opt-in only, 60 req/hr) — reference implementations

## Decomposition Validation

Before creating tasks in the PM tool, the decomposition must pass:

1. **Rubric check**: All 9 required fields present per task
2. **Topological sort**: No circular dependencies
3. **File conflict check**: Parallel tasks don't share predicted files
4. **Atomicity check**: No task modifies >5 files
5. **Verification syntax check**: Every verification command is valid shell
