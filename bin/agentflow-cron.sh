#!/usr/bin/env bash
set -euo pipefail

# AgentFlow Crontab Wrapper
# =========================
# Invoked by crontab to run the orchestrator sweep.
#
# Crontab does NOT source .bashrc/.zshrc, so this script loads the shell
# environment before calling Claude Code. The CLAUDE_BIN path is set
# automatically by setup.sh.
#
# Log output:  /tmp/agentflow-orchestrate.log
# Edit crontab: crontab -e
# View crontab: crontab -l

# ---------------------------------------------------------------------------
# Timestamp helper (ISO 8601 UTC)
# ---------------------------------------------------------------------------
timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[$(timestamp)] $1"
}

# ---------------------------------------------------------------------------
# Source shell profile for PATH, env vars, MCP config, etc.
# ---------------------------------------------------------------------------
# We source in a specific order of preference. Only the first match runs.
# Errors are suppressed because interactive shell configs often have commands
# that fail in non-interactive contexts (e.g., compinit, oh-my-zsh themes).
PROFILE_LOADED=false

if [[ -f "$HOME/.zprofile" ]] && ! $PROFILE_LOADED; then
  # shellcheck disable=SC1091
  source "$HOME/.zprofile" 2>/dev/null || true
  PROFILE_LOADED=true
fi

if [[ -f "$HOME/.zshrc" ]] && ! $PROFILE_LOADED; then
  # shellcheck disable=SC1091
  source "$HOME/.zshrc" 2>/dev/null || true
  PROFILE_LOADED=true
fi

if [[ -f "$HOME/.bash_profile" ]] && ! $PROFILE_LOADED; then
  # shellcheck disable=SC1091
  source "$HOME/.bash_profile" 2>/dev/null || true
  PROFILE_LOADED=true
fi

if [[ -f "$HOME/.bashrc" ]] && ! $PROFILE_LOADED; then
  # shellcheck disable=SC1091
  source "$HOME/.bashrc" 2>/dev/null || true
  PROFILE_LOADED=true
fi

if [[ -f "$HOME/.profile" ]] && ! $PROFILE_LOADED; then
  # shellcheck disable=SC1091
  source "$HOME/.profile" 2>/dev/null || true
  PROFILE_LOADED=true
fi

# Ensure common paths are available even if no profile was loaded
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# ---------------------------------------------------------------------------
# Claude binary (automatically set by setup.sh -- do not edit manually)
# ---------------------------------------------------------------------------
CLAUDE_BIN="/usr/local/bin/claude"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ ! -x "$CLAUDE_BIN" ]]; then
  log "ERROR: Claude binary not found or not executable at $CLAUDE_BIN"
  log "       Re-run setup.sh to fix: cd /path/to/agentflow && ./setup.sh"
  exit 1
fi

# Verify Claude can actually run (catches missing dependencies, broken installs)
if ! "$CLAUDE_BIN" --version &>/dev/null; then
  log "ERROR: Claude binary exists but failed to run: $CLAUDE_BIN --version"
  exit 1
fi

# ---------------------------------------------------------------------------
# Lock file to prevent overlapping sweeps
# ---------------------------------------------------------------------------
LOCK_FILE="/tmp/agentflow-sweep.lock"

# Clean up stale lock files (older than 30 minutes)
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_AGE=0
  if [[ "$(uname -s)" == "Darwin" ]]; then
    LOCK_CREATED=$(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    LOCK_AGE=$(( NOW - LOCK_CREATED ))
  else
    LOCK_CREATED=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    LOCK_AGE=$(( NOW - LOCK_CREATED ))
  fi

  if [[ $LOCK_AGE -gt 1800 ]]; then
    log "WARNING: Stale lock file detected (${LOCK_AGE}s old). Removing."
    rm -f "$LOCK_FILE"
  else
    log "SKIP: Another sweep is already running (lock age: ${LOCK_AGE}s). Exiting."
    exit 0
  fi
fi

# Create lock
echo $$ > "$LOCK_FILE"

# Ensure lock is cleaned up on exit
cleanup() {
  rm -f "$LOCK_FILE"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Run the orchestrator sweep
# ---------------------------------------------------------------------------
log "Starting orchestrator sweep..."
log "Claude binary: $CLAUDE_BIN"

EXIT_CODE=0
"$CLAUDE_BIN" -p "Run /sdlc-orchestrate" 2>&1 || EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  log "ERROR: Orchestrator sweep failed (exit code: $EXIT_CODE)"
else
  log "Sweep completed successfully"
fi

log "Sweep finished (exit: $EXIT_CODE)"
exit $EXIT_CODE
