# The 23-Gap Registry

> Every gap represents a failure mode in AI-assisted software development that existing tools don't address. AgentFlow was designed by systematically identifying and closing each one.

This registry is the foundation of AgentFlow's design. Each gap was discovered through production experience running AI agent fleets, CTO-level architectural review, and analysis of competing frameworks.

## Gap 1: Shared Blindness Between Builder and Reviewer

**Problem:** When the same AI model builds and reviews code, both agents share identical blind spots. The reviewer is unlikely to catch mistakes the builder made because they reason about code the same way.

**Fix:** Deterministic quality gates (`tsc --noEmit + eslint + npm test`) run BEFORE the AI reviewer sees the code. These catch ~60% of issues (type errors, lint violations, test failures) at near-zero cost. The AI reviewer only evaluates code that already passes machine-verifiable checks.

**Implementation:** `prompts/build.md` runs lint gate locally before posting `[BUILD:COMPLETE]`. The orchestrator only moves tasks to Review after seeing `[LINT:PASS]`.

---

## Gap 2: No Decomposition Quality Standard

**Problem:** AI agents decompose specs into tasks of wildly varying quality — some are too vague, some are too large, some have missing acceptance criteria. Poor decomposition cascades into build failures.

**Fix:** A 9-field quality rubric enforced during decomposition. Every task must have: Summary, Input State, Output State, Acceptance Criteria, Verification Command, Predicted Files, Dependencies, Research Triggers, and Complexity. A validator checks all fields before any task is created in the PM tool.

**Implementation:** `prompts/decompose.md` enforces the rubric. `skills/spec-to-asana.md` runs 5 validation checks (rubric, topological sort, file conflicts, atomicity, verification syntax) before creating tasks.

---

## Gap 3: No Integration Testing After Merge

**Problem:** Individual PRs pass their own tests, but merging to `main` can break other features. Without post-merge integration testing, bugs accumulate silently on the main branch.

**Fix:** A 7th pipeline stage (Integrate) that runs the full test suite on `main` immediately after every merge. If tests fail, the merge is automatically reverted via `git revert` (new commit, never force-push).

**Implementation:** `prompts/test.md` includes an Integration Stage section that runs immediately after merging a PR.

---

## Gap 4: Unconditional Research Wastes Resources

**Problem:** Running a research phase for every task wastes time and money. Many tasks (simple CRUD, styling changes, config updates) don't need external knowledge.

**Fix:** Research is conditional. Each task has a "Research Triggers" field listing specific triggers (unfamiliar library, external API, complex algorithm). Research only runs if triggers are present. Tasks without triggers skip directly to Build.

**Implementation:** `prompts/research.md` starts with Step 0: Check Triggers. If none, posts `[RESEARCH:SKIP]` and exits.

---

## Gap 5: No Cost Visibility

**Problem:** AI agent pipelines can run up costs quickly, especially on stuck tasks that retry endlessly. Without per-task cost tracking, there's no way to identify expensive tasks or set guardrails.

**Fix:** Every task tracks accumulated cost in its metadata header: `[COST:~$N]`. Each stage adds its cost ceiling to the running total. Automatic guardrails trigger at $5 (warning) and $15 (hard stop with human escalation).

**Implementation:** `conventions.md` defines cost ceilings per stage. `skills/sdlc-worker.md` updates costs after each stage. `skills/sdlc-orchestrate.md` checks cost thresholds during feedback loops.

---

## Gap 6: Parallel Task File Conflicts

**Problem:** When multiple agents work on different tasks simultaneously, they may modify the same files, leading to merge conflicts and wasted work.

**Fix:** Each task declares its "Predicted Files" during decomposition. The orchestrator compares predicted files across all tasks currently in Build/Review/Test/Integrate. If any file appears in multiple active tasks, the lower-priority task waits in Backlog until the conflict resolves.

**Implementation:** `skills/sdlc-orchestrate.md` Step 6 checks file conflicts before dispatching. `prompts/decompose.md` requires predicted files per task.

---

## Gap 7: Same Mistakes Repeated Across Tasks

**Problem:** If task 3 fails because of a common pattern (e.g., forgetting to handle null in API responses), tasks 8, 12, and 15 will make the same mistake independently.

**Fix:** System-level retrospectives. Every 10 completed tasks, the orchestrator analyzes all reject/fail comments, identifies patterns appearing 3+ times, and writes them to `LEARNINGS.md`. Builders and reviewers read `LEARNINGS.md` before starting work.

**Implementation:** `skills/sdlc-orchestrate.md` Step 7 runs the retrospective. `prompts/build.md` and `prompts/review.md` read `LEARNINGS.md` as part of their context gathering.

---

## Gap 8: Dead Agents Block the Pipeline

**Problem:** If a worker agent crashes, gets killed, or loses connection, its assigned task stays in Build/Review/Test indefinitely. No one knows the worker is dead.

**Fix:** Heartbeat pattern. Workers post `[HEARTBEAT]` comments every 5 minutes during execution. The orchestrator checks for heartbeats during every sweep. If no heartbeat for >10 minutes, the worker is declared dead, the slot is cleared, and the task is re-dispatched.

**Implementation:** `prompts/build.md` posts `[BUILD:STARTED]` and `[HEARTBEAT]` every 5 min. `skills/sdlc-orchestrate.md` Step 3 checks heartbeats and posts `[REASSIGNED]` for dead workers.

---

## Gap 9: AI Reviews Are Too Lenient

**Problem:** AI reviewers tend to approve code that "looks right" without finding subtle issues. They default to positive assessments unless explicitly directed otherwise.

**Fix:** Adversarial review prompt. The reviewer's instructions begin with: "Your job is to find problems. You MUST list at least 3 things wrong with this code before making your pass/reject decision." To pass, the reviewer must explain why each issue is acceptable.

**Implementation:** `prompts/review.md` uses adversarial framing: "List 3 things wrong before deciding to pass."

---

## Gap 10: Integration Failures Leave Main Broken

**Problem:** When a merged PR breaks `main`, manual intervention is needed to revert. This blocks all other work and may not be noticed immediately.

**Fix:** Automatic revert. When integration tests fail after merge, the system runs `git revert $MERGE_COMMIT --no-edit && git push origin main`. This creates a new commit (never force-push), preserving history. The feature branch remains intact for the builder to fix.

**Implementation:** `prompts/test.md` Integration Stage runs `git revert` on failure and posts `[INTEGRATE:FAIL]` with the revert commit hash.

---

## Gap 11: Asana Custom Fields Are Fragile

**Problem:** Asana's custom fields require specific field creation, are workspace-scoped, and add API complexity. They're also harder to read at a glance in the task description.

**Fix:** All metadata lives in the task description header as plain text: `[SLOT:T2] [STAGE:Build] [RETRY:1] [COST:~$2.50]`. Parsed with simple regex. No custom field setup required. Visible in every view (board, list, detail).

**Implementation:** `conventions.md` defines the metadata header format. All skills use regex to read/write these fields.

---

## Gap 12: Session-Based Scheduling Dies with Session (Most Critical)

**Problem:** Using `CronCreate` or in-process timers to schedule orchestration sweeps means the scheduler dies when the Claude Code session ends. The entire pipeline stops silently.

**Fix:** The orchestrator is a **stateless, one-shot command** invoked by real system crontab. It reads all state from the Kanban board on every sweep, makes decisions, updates state, and exits. Real crontab survives terminal crashes, reboots, and network interruptions.

**Implementation:** `skills/sdlc-orchestrate.md` is designed as a one-shot sweep. Installation instructions use `crontab -e` for durable scheduling.

---

## Gap 13: No Visibility Into Agent Decisions

**Problem:** Agents make decisions (which approach to take, what to research, why something was rejected) but these decisions are invisible unless you read the code diff.

**Fix:** Comment-thread-as-memory. Every significant decision is posted as a structured comment on the Asana task with machine-readable tags. The full decision history is visible by reading the task's comment thread — from research findings through build approach to review verdict.

**Implementation:** All prompts post structured comments with tags. The comment thread IS the audit trail.

---

## Gap 14: Runaway Costs on Stuck Tasks

**Problem:** A task that fails review repeatedly can accumulate significant costs without any guardrail. The pipeline happily retries forever.

**Fix:** Per-task cost tracking with automatic guardrails. Each stage adds its cost ceiling to the running total. At $5: `[COST:WARNING]` is posted. At $15: `[COST:CRITICAL]` is posted and the task is moved to "Needs Human" — no more automated retries until a human reviews.

**Implementation:** `skills/sdlc-orchestrate.md` Step 5 checks cost thresholds during feedback loops.

---

## Gap 15: Uncontrolled External API Usage

**Problem:** AI agents may call rate-limited APIs (GitHub, Google, npm registry) excessively during research, hitting rate limits that affect other tools.

**Fix:** Source priority hierarchy. Research follows a strict order: (1) Codebase patterns (free), (2) Documentation tools like Context7 (no rate limit), (3) Web search (rate-limited), (4) GitHub API (opt-in only, 60 req/hr). Each source is used only if the previous one didn't provide sufficient information.

**Implementation:** `prompts/research.md` enforces source priority order.

---

## Gap 16: Circular Dependencies in Task Graph

**Problem:** If task A depends on task B and task B depends on task A (directly or transitively), both tasks wait forever in Backlog.

**Fix:** Topological sort validation during decomposition. Before creating any tasks, the decomposition validator runs a topological sort on the dependency graph. If cycles are detected, decomposition fails with a clear error listing the cycle.

**Implementation:** `skills/spec-to-asana.md` runs topological sort as part of the 5-check validation.

---

## Gap 17: PRs That Exceed Task Scope

**Problem:** AI builders sometimes modify files beyond what the task requires — "while I'm here" refactoring, over-eager cleanup, or unrelated changes.

**Fix:** Scope creep detection. Each task declares its predicted files during decomposition. During review, the reviewer compares `gh pr diff --name-only` against the predicted files list. Files modified but not predicted trigger a `[SCOPE:WARNING]`.

**Implementation:** `prompts/review.md` includes a scope check step that compares diff files against predicted files.

---

## Gap 18: Impossible Tasks Retry Forever

**Problem:** Some tasks genuinely can't be completed by an AI agent (requires hardware access, needs credentials, depends on an external system that's down). Without detection, these tasks retry endlessly.

**Fix:** Blocked detection. After 2 failed build attempts, the builder evaluates whether the task is actually impossible (missing credentials, requires manual setup, external dependency unavailable). If so, it posts `[BUILD:BLOCKED reason="..."]` and the task moves to "Needs Human".

**Implementation:** `prompts/build.md` includes blocked detection logic after the 2nd failure.

---

## Gap 19: Secrets Leaked in Code

**Problem:** AI agents may hardcode API keys, tokens, or credentials in code or test files.

**Fix:** Three-layer secret management: (1) Mock values in tests, (2) `process.env.X` references in implementation code, (3) `[NEEDS:MANUAL_VERIFY]` tag for tasks that require real API credentials for final verification. Builders are explicitly instructed never to use real secrets.

**Implementation:** `prompts/build.md` includes secret management rules.

---

## Gap 20: Wrong Task Gets Built First

**Problem:** Without intelligent priority, the pipeline may build leaf tasks (that nothing depends on) before critical-path tasks (that unblock many others).

**Fix:** Transitive priority. Priority score = count of tasks transitively blocked by this task. A task that unblocks 5 others gets built before a task that unblocks 1. This automatically identifies the critical path without manual priority assignment.

**Implementation:** `skills/sdlc-orchestrate.md` Step 6 calculates transitive priority during dispatch.

---

## Gap 21: No Dashboard for Pipeline Status

**Problem:** Without a centralized view, you have to check individual tasks to understand overall pipeline progress.

**Fix:** A pinned Status task updated every orchestration sweep. Shows: active tasks per slot, completion count, total retries, estimated cost, blocked tasks, tasks needing human intervention, ETA based on current velocity, and recent activity log.

**Implementation:** `skills/sdlc-orchestrate.md` Step 8 updates the Status task and posts a project status update.

---

## Gap 22: No Clean Shutdown Mechanism

**Problem:** Stopping the pipeline by killing processes leaves tasks in inconsistent states — some assigned to slots that no longer exist, some mid-build with no worker.

**Fix:** Graceful shutdown via `/sdlc-stop`. Posts `[SYSTEM:PAUSING]`, lets active workers finish, moves unstarted tasks back to Backlog with cleared slots, posts `[SYSTEM:PAUSED]` when complete. Resume with `/sdlc-orchestrate`.

**Implementation:** `skills/sdlc-stop.md` implements the 5-step graceful shutdown.

---

## Gap 23: Spec Changes Go Unnoticed

**Problem:** If the SPEC.md changes after decomposition, tasks may be building against outdated requirements. No one notices until review or integration fails.

**Fix:** Spec drift detection. During decomposition, the SHA-256 hash of SPEC.md is stored in the Asana project description. Every orchestration sweep compares the current hash. If changed: `[SPEC:CHANGED]` is posted, all non-Done tasks are flagged with `[NEEDS:REVALIDATION]`, and dispatch pauses until a human posts `[SPEC:CONTINUE]` or `[SPEC:REDECOMPOSE]`.

**Implementation:** `skills/sdlc-orchestrate.md` Step 2 checks spec drift. `skills/spec-to-asana.md` stores the initial hash.
