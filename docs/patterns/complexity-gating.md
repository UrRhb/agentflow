# Pattern: Complexity Gating

**Source:** `claude-code/src/main.tsx` -- `import { feature } from 'bun:bundle'`
**What it does:** Uses build-time feature flags for dead-code elimination, ensuring unused capabilities are never loaded and never consume resources.
**How AgentFlow uses it:** Task complexity (S/M/L) gates which Superpowers are loaded, so simple tasks skip expensive workflow overhead.

## Original Implementation

Claude Code uses Bun's build-time feature flags to control binary composition:

- **`import { feature } from 'bun:bundle'`** provides compile-time constants
  that the bundler uses to tree-shake entire code paths.
- Features not enabled for a build are eliminated entirely -- not just disabled
  at runtime, but absent from the bundle.
- This keeps the binary lean: a minimal build excludes heavy features like
  multi-agent coordination or advanced permission systems.
- The pattern enforces a "pay only for what you use" principle at the build level.

## AgentFlow Integration

AgentFlow applies complexity gating at runtime through task sizing:

- **Simple (S) tasks:** Skip all Superpowers. No plan phase, no review cycle,
  no multi-agent coordination. The worker executes directly with a minimal
  prompt. Examples: typo fixes, config changes, dependency bumps.
- **Medium (M) tasks:** Load plan + execute Superpowers. The worker writes a
  plan, gets approval (auto or manual), then executes. No reviewer agent.
  Examples: single-file features, bug fixes with clear reproduction.
- **Complex (L) tasks:** Full workflow loaded -- planning, multi-agent teams,
  review gates, test verification, and context management. Examples:
  cross-cutting features, architecture changes, multi-file refactors.

The key insight: **prompts not loaded = tokens not spent.** A Simple task that
skips the planning Superpower saves the ~800 tokens that plan instructions
would consume per worker turn.

## Standalone Equivalent

Standalone mode already implements complexity gating at the prompt level:

- Task descriptions include a complexity tag that tells the worker which
  workflow steps to follow.
- Conditional instructions in the prompt (e.g., "If complexity is S, skip
  planning") achieve the same effect without runtime infrastructure.
- This was the v1 implementation and remains the fallback for all modes.
