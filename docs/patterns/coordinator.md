# Pattern: Coordinator Mode

**Source:** `claude-code/src/coordinator/coordinatorMode.ts`
**What it does:** Manages multi-agent teams with role assignment, session mode matching, and inter-agent messaging to coordinate parallel work streams.
**How AgentFlow uses it:** The orchestrator operates in coordinator mode, creating teams, assigning roles (builder/reviewer/tester), and enforcing review separation.

## Original Implementation

Claude Code's coordinator mode enables a parent agent to spawn and manage child agents
with distinct roles. Key concepts:

- **Role assignment:** Each agent in a team receives a specific role (e.g., coder,
  reviewer, planner) that constrains its tool access and behavioral mode.
- **Session mode matching:** The coordinator matches incoming tasks to the appropriate
  session mode, routing work to agents configured for that type of task.
- **Inter-agent messaging:** Agents communicate through structured messages, allowing
  the coordinator to relay context, results, and instructions between team members
  without polluting individual agent contexts.
- **Separation of concerns:** The coordinator enforces that the agent who wrote code
  cannot also approve it, building review gates into the workflow.

## AgentFlow Integration

AgentFlow's orchestrator adopts coordinator mode as its primary operating pattern:

- Creates teams of 2-5 workers per task, each with a dedicated role
  (builder, reviewer, tester, documenter).
- The builder agent never reviews its own output; a separate reviewer agent handles QA.
- Role instructions are injected into each worker's system prompt via the
  `role_instructions` field in the task payload.
- Inter-agent communication flows through `SendMessage` tool calls routed by the
  orchestrator, which decides when to escalate, retry, or reassign.

## Standalone Equivalent

In standalone mode (no orchestrator), coordinator behavior is simulated through prompts:

- Worker prompts include explicit role instructions (e.g., "You are the builder.
  Do not self-review.").
- Enforcement is prompt-level only -- there is no structural guarantee that roles
  are respected.
- Review separation relies on the human operator switching context between
  builder and reviewer tasks manually.
