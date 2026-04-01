# Pattern: Permission Classifiers

**Source:** `claude-code/src/utils/permissions/permissions.ts` -- BASH_CLASSIFIER, TRANSCRIPT_CLASSIFIER
**What it does:** Runs speculative safety checks on bash commands and transcript content before execution, catching dangerous operations before they reach the shell.
**How AgentFlow uses it:** A 3-layer sanitization pipeline protects against prompt injection and unsafe commands.

## Original Implementation

Claude Code uses classifier functions to evaluate safety before tool execution:

- **BASH_CLASSIFIER:** Inspects the command string a model wants to execute.
  Checks for patterns like `rm -rf /`, credential exfiltration (`curl` piping
  secrets), or privilege escalation. Runs before the command reaches the shell.
- **TRANSCRIPT_CLASSIFIER:** Scans conversation content for injection attempts
  embedded in tool outputs, files read from disk, or user messages that try to
  override system instructions.
- Both classifiers return allow/deny/ask decisions, feeding into the permission
  system that gates tool execution.
- Classification happens synchronously and adds negligible latency compared to
  the cost of executing an unsafe command.

## AgentFlow Integration

AgentFlow implements a 3-layer sanitization stack:

- **Layer 1 -- Regex (current):** Pattern matching against known dangerous
  commands (`rm -rf`, `curl | bash`, secret file access). Active in both
  orchestrated and standalone modes. Implemented in prompt instructions and
  pre-execution hooks.
- **Layer 2 -- Classifier for obfuscated injection:** A lightweight model call
  that catches base64-encoded commands, variable-substitution tricks, and other
  obfuscation techniques that bypass regex. Planned for orchestrated mode.
- **Layer 3 -- Task description classification:** Validates that the command
  being executed is plausible given the task description. A command to
  `DROP TABLE` during a CSS styling task would be flagged. Planned for
  orchestrated mode.

## Standalone Equivalent

Standalone mode uses Layer 1 only:

- Regex-based checks embedded in worker prompts catch obvious dangerous patterns.
- No classifier model calls occur -- the cost/latency tradeoff is not justified
  for single-worker sessions.
- The human operator serves as the implicit Layer 2 and 3.
