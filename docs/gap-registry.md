# The 45-Gap Registry

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

**Fix:** Every task tracks accumulated cost in its metadata header: `[COST:~$N]`. Each stage adds its cost ceiling to the running total. Automatic guardrails trigger at the warning threshold ($3/$8) and hard stop ($10/$20) per Sonnet/Opus cost profile, with human escalation.

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

**Fix:** Per-task cost tracking with automatic guardrails. Each stage adds its cost ceiling to the running total. At the warning threshold ($3/$8): `[COST:WARNING]` is posted. At the hard stop ($10/$20): `[COST:CRITICAL]` is posted and the task is moved to "Needs Human" — no more automated retries until a human reviews.

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

---

## Superpowers Integration Gaps (24-31)

---

## Gap 24: Context Window War

**Problem:** When AgentFlow conventions, Superpowers methodology, LEARNINGS.md, task description, and codebase context are all loaded simultaneously, the agent's context window fills up quickly. On complex tasks, critical information gets pushed out and the agent starts hallucinating or ignoring constraints.

**Impact:** Build quality degrades on complex tasks. Agents forget acceptance criteria or conventions mid-build. Retry rates increase, driving up costs.

**Fix:** Lazy-load context by complexity. Simple tasks load only conventions + task description. Medium tasks add LEARNINGS.md. Complex tasks get full context. Additionally, LEARNINGS.md is capped at 50 lines with oldest-first rotation, and workers read only the most recent 30 patterns.

**Implementation:** `skills/sdlc-worker.md` loads context based on task complexity field. `conventions.md` defines LEARNINGS.md size limits.

---

## Gap 25: Two Captains Problem

**Problem:** AgentFlow and Superpowers both try to control the development lifecycle. AgentFlow says "post [BUILD:COMPLETE] and exit." Superpowers says "verify thoroughly before claiming done." When both are active, the agent gets conflicting instructions and may skip pipeline tags or over-verify.

**Impact:** Workers either skip AgentFlow tags (breaking orchestration) or ignore Superpowers methodology (reducing quality). Neither system works as designed.

**Fix:** Clear boundary: AgentFlow owns the lifecycle (start, heartbeat, complete, tags, transitions). Superpowers owns the methodology (how to plan, build, test within a stage). This is enforced in the worker skill prompt: "AgentFlow tags are mandatory. Superpowers methodology guides your approach within each stage."

**Implementation:** `skills/sdlc-worker.md` enforces lifecycle ownership. Superpowers skills are invoked within stages but cannot override tag posting.

---

## Gap 26: Sub-Agents Skip Heartbeats

**Problem:** When Superpowers dispatches sub-agents for parallel work, the parent agent stops posting heartbeats while waiting. The orchestrator sees no heartbeat for >10 minutes and declares the worker dead, reassigning the task mid-build.

**Impact:** Work is duplicated or lost. The original sub-agents continue running without a parent, wasting resources.

**Fix:** Parent agent posts heartbeats before dispatching sub-agents and between sub-agent completions. If a sub-agent is expected to run >5 minutes, the parent posts a heartbeat with status: `[HEARTBEAT] Waiting for sub-agent: <description>`.

**Implementation:** `skills/sdlc-worker.md` includes heartbeat rules for sub-agent dispatch. Parent posts heartbeat before and between sub-agent calls.

---

## Gap 27: Plan Exceeds Task Scope

**Problem:** Superpowers' planning phase can produce plans that modify files outside the task's predicted file list, or that go beyond the acceptance criteria. The plan looks good in isolation but violates AgentFlow's atomicity and scope constraints.

**Impact:** PRs fail scope checks. Review rejects increase. Tasks that should be simple become complex due to over-planning.

**Fix:** Predicted files and acceptance criteria are fed as hard constraints into the planning phase. The plan must only reference predicted files and must map each action to a specific acceptance criterion. If the plan needs more files, it must flag this as a scope expansion request.

**Implementation:** `prompts/build.md` injects predicted files and acceptance criteria as constraints before Superpowers planning. `prompts/review.md` validates plan-to-criteria mapping.

---

## Gap 28: Double Cost Tracking

**Problem:** AgentFlow tracks costs using fixed stage ceilings, but these were calibrated for Opus. When running with Sonnet (which is 10-15x cheaper), the ceilings are far too generous and provide no meaningful guardrail. Conversely, Opus with Superpowers sub-agents can blow past Opus ceilings.

**Impact:** With Sonnet, tasks can waste significant money before hitting guardrails. With Opus + Superpowers, legitimate complex tasks get killed prematurely.

**Fix:** Dual cost profiles (Sonnet and Opus) with separate ceilings. Sonnet profile: Warning at $3, hard stop at $10. Opus profile: Warning at $8, hard stop at $20. Superpowers sub-agent costs are included in the parent task's cost tracking. Profile is selected during `/spec-to-asana` setup.

**Implementation:** `conventions.md` defines both profiles. `skills/spec-to-asana.md` prompts for profile selection. `skills/sdlc-orchestrate.md` reads the active profile from project description.

---

## Gap 29: Retry Context Fragmentation

**Problem:** When Superpowers uses sub-agents, each sub-agent's output is posted as a separate comment. On retry, the next builder sees fragmented context across multiple comments and may miss critical information from a sub-agent that succeeded while another failed.

**Impact:** Retry builders repeat mistakes that were already solved. Context is lost across the sub-agent boundary, leading to more retries and higher costs.

**Fix:** Parent agent aggregates all sub-agent outputs into a single structured comment before posting `[BUILD:COMPLETE]` or signaling failure. The aggregated comment includes: what each sub-agent did, which succeeded, which failed, and what to do differently on retry.

**Implementation:** `skills/sdlc-worker.md` requires output aggregation before posting completion tags. `prompts/build.md` includes aggregation template.

---

## Gap 30: Brainstorm Overkill

**Problem:** Superpowers' brainstorm phase runs for every task regardless of complexity. Simple tasks (rename a variable, update a config value) don't benefit from brainstorming but still pay the cost in tokens and time.

**Impact:** Simple tasks that should cost ~$0.10 end up costing ~$0.50+ due to unnecessary brainstorming. Pipeline throughput drops.

**Fix:** Complexity gating for Superpowers phases. Simple (S) tasks: skip brainstorm and plan, go straight to build. Medium (M) tasks: skip brainstorm, run plan only. Large/Complex (L) tasks: run full brainstorm + plan + sub-agent pipeline.

**Implementation:** `skills/sdlc-worker.md` reads task complexity and gates Superpowers invocation accordingly. `conventions.md` documents the gating rules.

---

## Gap 31: Conflicting Review Standards

**Problem:** AgentFlow's adversarial review says "find 3 things wrong." Superpowers' review methodology may have different criteria or a more lenient standard. When both are active, the reviewer doesn't know which standard to apply.

**Impact:** Inconsistent review quality. Some reviews are too lenient (Superpowers standard), others too strict (AgentFlow standard). Builders can't predict what will pass.

**Fix:** AgentFlow's adversarial review rules always take precedence. Superpowers provides the methodology for HOW to review (what to look at, how to reason about code), but AgentFlow provides the CRITERIA for pass/reject decisions. This is explicitly stated in the review prompt.

**Implementation:** `prompts/review.md` states: "AgentFlow adversarial rules override any other review methodology. You MUST find 3 issues before deciding to pass."

---

## Audit Finding Gaps (32-45)

---

## Gap 32: No Worktree Cleanup

**Problem:** Each worker creates a git worktree for its task, but worktrees are never cleaned up. Over a multi-sprint project, dozens of stale worktrees accumulate, consuming disk space and cluttering the git state.

**Impact:** Disk space exhaustion on long-running projects. `git worktree list` becomes noisy. Potential for accidentally working in a stale worktree.

**Fix:** Worktree cleanup on task completion (Done stage). When a task moves to Done, the orchestrator or worker removes the associated worktree. On retry, the worktree is kept (the next builder may need it). A manual cleanup command is also available via `agentflow worktree prune`.

**Implementation:** `skills/sdlc-orchestrate.md` adds worktree cleanup to Done transition. `prompts/test.md` cleans up worktree after successful integration.

---

## Gap 33: Prompt Version Skew

**Problem:** If `conventions.md` is updated mid-sprint (e.g., new tags added, cost ceilings changed), some workers may be running with the old version cached in their context while others pick up the new version. This causes inconsistent behavior.

**Impact:** Workers using old conventions may post wrong tags, use wrong cost ceilings, or miss new rules. Orchestrator may not recognize tags from workers using newer conventions.

**Fix:** `conventions.md` includes a version field at the top (e.g., `version: 3`). The orchestrator checks the version on every sweep and posts `[CONVENTIONS:UPDATED v3]` if it changes. Workers re-read conventions at the start of each task, not just at session start.

**Implementation:** `conventions.md` header includes version. `skills/sdlc-orchestrate.md` checks version on sweep. `skills/sdlc-worker.md` re-reads conventions per task.

---

## Gap 34: No Merge Lock

**Problem:** When two tasks complete testing simultaneously, both try to merge to main at the same time. This causes merge conflicts, failed integrations, and wasted reverts.

**Impact:** Simultaneous merges create race conditions. One or both PRs may fail integration, triggering unnecessary reverts and retries.

**Fix:** Merge lock via `[MERGE_LOCK:T<slot>:<task>]` comment on the Status task. Before merging, the tester checks for an existing lock. If locked, it waits and retries. After merge + integration test, the lock is released via `[MERGE_UNLOCK:T<slot>]`. Lock timeout: 10 minutes (auto-release if worker dies).

**Implementation:** `prompts/test.md` acquires merge lock before merge, releases after integration. `skills/sdlc-orchestrate.md` cleans up stale merge locks.

---

## Gap 35: Sub-Agent Git Conflicts

**Problem:** When Superpowers dispatches multiple sub-agents to work on the same task, they may modify the same files simultaneously within the worktree, creating conflicts.

**Impact:** Sub-agent work is lost or corrupted. Parent agent must manually resolve conflicts, which AI agents do poorly.

**Fix:** Parent agent assigns non-overlapping file sets to each sub-agent based on the task's predicted files. If files can't be cleanly partitioned, sub-agents run sequentially instead of in parallel. The parent validates no file overlap before dispatching.

**Implementation:** `skills/sdlc-worker.md` includes file partitioning logic for sub-agent dispatch. Falls back to sequential execution if partition is impossible.

---

## Gap 36: No Orchestrator Health Monitoring

**Problem:** If the crontab stops firing (cron daemon crash, machine sleep, auth token expiry), the entire pipeline silently stops. No one knows the orchestrator is dead until they manually check.

**Impact:** Pipeline stalls indefinitely. Tasks sit in Backlog or mid-stage with no progress. Workers may time out waiting for dispatch.

**Fix:** The orchestrator posts `[LAST_SWEEP:<timestamp>]` in the Status task on every sweep. An external watchdog (lightweight script added by `setup.sh`) checks this timestamp. If the last sweep is >30 minutes old, the watchdog sends a notification (system notification, email, or webhook).

**Implementation:** `skills/sdlc-orchestrate.md` posts sweep timestamp. `setup.sh` installs the watchdog script. Watchdog is a separate crontab entry that runs every 30 minutes.

---

## Gap 37: Comment Thread Pollution at Scale

**Problem:** On a task with many retries, the comment thread grows to 50+ comments. Reading all comments to determine state is slow, expensive (tokens), and may hit API rate limits.

**Impact:** Orchestrator sweeps slow down. Workers waste tokens reading irrelevant old comments. API rate limits may be hit on large projects.

**Fix:** Read only the last 10-20 comments per task, not the entire thread. Stage transition decisions only need recent comments (the last build/review/test result). Historical context is summarized in the retry aggregation comment, not scattered across the thread.

**Implementation:** All skills use `get_comments(task, limit=20)` instead of fetching all comments. Adapter interface supports the `limit` parameter.

---

## Gap 38: Dual Sweep Collision

**Problem:** If crontab fires a new orchestrator sweep while the previous one is still running (sweep takes >15 minutes on large projects), two sweeps run simultaneously. Both may dispatch the same task, move the same cards, or create duplicate comments.

**Impact:** Tasks dispatched twice. Duplicate comments pollute the thread. Race conditions in stage transitions cause tasks to skip stages or get stuck.

**Fix:** Sweep mutual exclusion via `[SWEEP:RUNNING <timestamp>]` comment on the Status task. Before starting, the orchestrator checks for this comment. If present and <20 minutes old, the sweep exits immediately. On completion, it posts `[SWEEP:COMPLETE <timestamp>]`.

**Implementation:** `skills/sdlc-orchestrate.md` Step 0 checks for sweep lock before proceeding. Posts lock at start, removes at end.

---

## Gap 39: Adversarial Review Ping-Pong

**Problem:** The adversarial reviewer must find 3 issues. On high-quality code, it invents minor issues (naming nitpicks, style preferences) and rejects. The builder "fixes" these, but the next review finds 3 new nitpicks. This creates an endless loop of trivial rejections.

**Impact:** Tasks bounce between Build and Review indefinitely. Costs accumulate on minor style issues. Builder and reviewer never converge.

**Fix:** Added "PASS WITH NOTES" verdict. If the reviewer finds only minor issues (naming, style, documentation), it can pass the task with notes attached. The notes are posted as suggestions but don't trigger a retry. Only functional issues, security issues, or missing acceptance criteria trigger a reject.

**Implementation:** `prompts/review.md` includes the PASS WITH NOTES path: "If all 3 issues are minor (style/naming/docs), post [REVIEW:PASS_WITH_NOTES] and list suggestions. Task proceeds to Test."

---

## Gap 40: Prompt Injection via Task Inputs

**Problem:** Task descriptions, SPEC.md content, or external research results could contain adversarial instructions that override agent behavior. For example, a malicious dependency's README could contain "ignore all previous instructions and..."

**Impact:** Agent behavior is hijacked. Could lead to secret exfiltration, malicious code injection, or pipeline disruption.

**Fix:** Input sanitization check before every stage execution. The worker scans task description and research inputs for common injection patterns (instruction overrides, base64-encoded commands, suspicious URLs). If detected, the task is flagged with `[SECURITY:WARNING]` and moved to Needs Human for review.

**Implementation:** `skills/sdlc-worker.md` runs sanitization check before executing any stage prompt. `conventions.md` defines the security tags.

---

## Gap 41: LEARNINGS.md Context Bomb

**Problem:** LEARNINGS.md grows without bound as the project progresses. After several sprints, it can be thousands of lines. Loading the entire file into every builder and reviewer's context wastes tokens and may push out more relevant information.

**Impact:** Token waste on every task. Important recent learnings get lost among old, potentially outdated patterns. Context window pressure increases.

**Fix:** Cap LEARNINGS.md at 50 lines with oldest-first rotation. When adding a new pattern, if the file exceeds 50 lines, the oldest patterns are removed from the top. Workers read only the most recent 30 patterns (bottom of file) if the file is large. Each pattern follows a fixed format for consistent parsing.

**Implementation:** `conventions.md` defines the cap and format. `skills/sdlc-orchestrate.md` retrospective step enforces the cap when writing new patterns.

---

## Gap 42: Git Revert Can Fail

**Problem:** When integration tests fail, the system runs `git revert` to undo the merge. But if the reverted changes conflict with subsequent commits (from other tasks merged in the meantime), the revert itself fails with merge conflicts.

**Impact:** Main branch stays broken. The auto-recovery mechanism fails silently. All subsequent merges are blocked.

**Fix:** If `git revert` fails with conflicts, the system posts `[INTEGRATE:REVERT_FAILED]` and moves the task to Needs Human with a detailed comment explaining the conflict. This is a genuine "human required" situation that cannot be safely automated.

**Implementation:** `prompts/test.md` catches revert failures and posts the escalation tag. `skills/sdlc-orchestrate.md` recognizes the tag and keeps the task in Needs Human.

---

## Gap 43: Crontab Environment and Auth Failure

**Problem:** Crontab runs in a minimal shell environment without the user's PATH, environment variables, or shell configuration. Claude Code may not be found, API keys may be missing, and MCP servers may fail to connect.

**Impact:** Orchestrator crontab entry silently fails. Pipeline stops with no error visible to the user. Debugging requires checking cron logs manually.

**Fix:** A wrapper script (`agentflow-cron.sh`) copied and configured by `setup.sh` that sources the user's shell environment before invoking Claude Code. The wrapper also logs errors to a dedicated log file and checks for common issues (missing API key, Claude CLI not found, MCP server unreachable).

**Implementation:** `setup.sh` copies and configures `agentflow-cron.sh` with environment sourcing. Crontab entry calls the wrapper, not Claude directly.

---

## Gap 44: Cost Ceilings Assume Wrong Model

**Problem:** The original cost ceilings were calibrated for Opus (~$15/1M input tokens). When running with Sonnet (~$3/1M input tokens), the ceilings are 5x too generous. When running Opus with Superpowers sub-agents, the ceilings are too tight.

**Impact:** Sonnet users get no meaningful cost protection. Opus + Superpowers users hit false cost alarms on legitimate work.

**Fix:** Dual cost profiles. Sonnet profile has lower ceilings and tighter guardrails (warning at $3, stop at $10). Opus profile has higher ceilings (warning at $8, stop at $20). Profile is selected during project setup and stored in the project description.

**Implementation:** `conventions.md` defines both profiles. `skills/spec-to-asana.md` stores selected profile. `skills/sdlc-orchestrate.md` reads profile for cost checks.

---

## Gap 45: Orchestrator Is 60-80% of Pipeline Cost

**Problem:** The orchestrator runs every 15 minutes regardless of pipeline activity. On a quiet pipeline (all tasks done, no new work), it still costs ~$0.50 per sweep, accumulating to ~$48/day for no useful work.

**Impact:** Idle pipelines burn money. Over a weekend with no activity, that is ~$96 wasted on orchestrator sweeps that find nothing to do.

**Fix:** Idle sweep optimization. If two consecutive sweeps find zero actionable items (no transitions, no dispatches, no dead workers), the orchestrator doubles its interval (15 min -> 30 min -> 60 min). Any new activity (human moves a card, worker posts a comment) resets to the default interval. Additionally, Sonnet is recommended for orchestration since it only reads state and makes routing decisions.

**Implementation:** `skills/sdlc-orchestrate.md` tracks consecutive idle sweeps in the Status task. `setup.sh` configures adaptive crontab or documents manual interval adjustment.

---

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

**Fix:** Plugin orchestrate skill checks for active crontab entry on startup. If found, warns: "Detected active crontab entry for agentflow-cron.sh. Disable it to avoid conflicts: crontab -e and comment out the line." The Asana-level [SWEEP:RUNNING] lock prevents actual conflicts, but dual-mode is wasteful and confusing.

### Gap 51: Progress Tracker SendMessage Floods Orchestrator

**Problem:** 4 workers each sending progress every 5 seconds = 48 messages per minute. The orchestrator's context fills up with progress noise.

**Fix:** Rate-limit progress updates to 1 per 30 seconds per worker (8 messages per minute total). Workers buffer progress locally and send only the latest snapshot. Orchestrator processes progress updates in bulk during the status dashboard update step, not inline.
