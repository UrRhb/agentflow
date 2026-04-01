#!/usr/bin/env bash
set -euo pipefail

# AgentFlow Setup Script
# Installs skills, prompts, conventions, and the crontab wrapper.
#
# Usage:
#   ./setup.sh                     # Standard install
#   ./setup.sh --with-cron         # Install + configure crontab (every 15 min)
#   ./setup.sh --model opus        # Set preferred model (default: sonnet)
#   ./setup.sh --help              # Show this help
#
# Supports macOS (Apple Silicon + Intel) and Linux.

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
AGENTFLOW_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude"
SDLC_DIR="$INSTALL_DIR/sdlc"
SKILLS_DIR="$INSTALL_DIR/skills"
PROMPTS_DIR="$SDLC_DIR/prompts"

# Defaults
WITH_CRON=false
MODEL="sonnet"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { printf '  \033[1;32m%s\033[0m %s\n' "OK" "$1"; }
warn()    { printf '  \033[1;33m%s\033[0m %s\n' "WARN" "$1"; }
err()     { printf '  \033[1;31m%s\033[0m %s\n' "ERROR" "$1"; }
header()  { printf '\n\033[1;36m=== %s ===\033[0m\n\n' "$1"; }

usage() {
  cat <<'USAGE'
AgentFlow Setup
===============
Usage: ./setup.sh [OPTIONS]

Options:
  --with-cron       Configure crontab to run the orchestrator every 15 minutes
  --model MODEL     Preferred Claude model: sonnet (default) or opus
  --uninstall       Remove AgentFlow files from ~/.claude
  --help            Show this help message

Examples:
  ./setup.sh                          # Install AgentFlow
  ./setup.sh --with-cron              # Install + set up crontab
  ./setup.sh --with-cron --model opus # Install + crontab + use Opus
  ./setup.sh --uninstall              # Remove AgentFlow files
USAGE
  exit 0
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
UNINSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-cron)  WITH_CRON=true; shift ;;
    --model)
      if [[ -z "${2:-}" ]]; then
        err "--model requires a value (sonnet or opus)"
        exit 1
      fi
      MODEL="$2"
      if [[ "$MODEL" != "sonnet" && "$MODEL" != "opus" ]]; then
        err "Invalid model '$MODEL'. Choose 'sonnet' or 'opus'."
        exit 1
      fi
      shift 2
      ;;
    --uninstall)  UNINSTALL=true; shift ;;
    --help|-h)    usage ;;
    *)
      err "Unknown option: $1"
      echo "Run ./setup.sh --help for usage."
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Uninstall path
# ---------------------------------------------------------------------------
if $UNINSTALL; then
  header "AgentFlow Uninstall"
  echo "Removing AgentFlow files from $INSTALL_DIR..."

  # Remove crontab entry if present
  if crontab -l 2>/dev/null | grep -q "agentflow-cron.sh"; then
    crontab -l 2>/dev/null | grep -v "agentflow-cron.sh" | crontab -
    info "Crontab entry removed"
  fi

  # Remove installed files (but not the entire ~/.claude directory)
  rm -f "$SDLC_DIR/conventions.md"
  rm -f "$SDLC_DIR/agentflow-cron.sh"
  rm -rf "$PROMPTS_DIR"
  # Only remove skill files that came from AgentFlow
  for skill in spec-to-asana sdlc-worker sdlc-orchestrate sdlc-stop sdlc-health sdlc-demo; do
    rm -f "$SKILLS_DIR/${skill}.md"
  done
  info "AgentFlow files removed"
  echo ""
  echo "Note: ~/.claude/skills/ and ~/.claude/sdlc/ directories were preserved."
  echo "      Delete them manually if no longer needed."
  exit 0
fi

# ---------------------------------------------------------------------------
# Main install
# ---------------------------------------------------------------------------
header "AgentFlow Setup v${AGENTFLOW_VERSION}"

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Darwin)
    PLATFORM="macOS"
    if [[ "$ARCH" == "arm64" ]]; then
      PLATFORM_DETAIL="macOS (Apple Silicon)"
    else
      PLATFORM_DETAIL="macOS (Intel)"
    fi
    ;;
  Linux)
    PLATFORM="Linux"
    PLATFORM_DETAIL="Linux ($ARCH)"
    ;;
  *)
    PLATFORM="Unknown"
    PLATFORM_DETAIL="$OS ($ARCH)"
    warn "Untested platform: $PLATFORM_DETAIL. Proceeding anyway."
    ;;
esac
echo "Platform: $PLATFORM_DETAIL"
echo ""

# ---------------------------------------------------------------------------
# 1. Detect Claude Code CLI
# ---------------------------------------------------------------------------
echo "Checking prerequisites..."

CLAUDE_BIN=""
if command -v claude &>/dev/null; then
  CLAUDE_BIN="$(command -v claude)"
elif [[ "$PLATFORM" == "macOS" && "$ARCH" == "arm64" && -x /opt/homebrew/bin/claude ]]; then
  CLAUDE_BIN="/opt/homebrew/bin/claude"
elif [[ -x /usr/local/bin/claude ]]; then
  CLAUDE_BIN="/usr/local/bin/claude"
elif [[ -x "$HOME/.local/bin/claude" ]]; then
  CLAUDE_BIN="$HOME/.local/bin/claude"
elif [[ -x "$HOME/.npm-global/bin/claude" ]]; then
  CLAUDE_BIN="$HOME/.npm-global/bin/claude"
else
  err "Claude Code CLI not found."
  echo ""
  echo "  Install it from: https://claude.ai/code"
  echo ""
  echo "  Common install locations checked:"
  echo "    - PATH lookup"
  echo "    - /opt/homebrew/bin/claude  (macOS Apple Silicon)"
  echo "    - /usr/local/bin/claude     (macOS Intel / Linux)"
  echo "    - ~/.local/bin/claude       (Linux user install)"
  echo "    - ~/.npm-global/bin/claude  (npm global)"
  echo ""
  exit 1
fi
info "Claude Code CLI: $CLAUDE_BIN"

# ---------------------------------------------------------------------------
# 1b. Detect Claude Code plugin support
# ---------------------------------------------------------------------------
PLUGIN_MODE=false
PLUGIN_DIR="$HOME/.claude/plugins"

if [[ -d "$PLUGIN_DIR" ]]; then
  echo ""
  echo "Claude Code plugin directory detected at $PLUGIN_DIR"
  echo ""
  echo "AgentFlow can be installed as a Claude Code plugin for:"
  echo "  - Automatic worker spawning (no iTerm tabs needed)"
  echo "  - Instant handoffs between workers"
  echo "  - Infrastructure-level quality gates (hooks)"
  echo ""
  read -p "Install as plugin? [Y/n] " PLUGIN_CHOICE
  PLUGIN_CHOICE="${PLUGIN_CHOICE:-Y}"
  if [[ "$PLUGIN_CHOICE" =~ ^[Yy] ]]; then
    PLUGIN_MODE=true
  fi
fi

# ---------------------------------------------------------------------------
# 2. Check other prerequisites
# ---------------------------------------------------------------------------
WARNINGS=0

# git
if command -v git &>/dev/null; then
  info "git $(git --version | awk '{print $3}')"
else
  err "git not found. Install git before continuing."
  exit 1
fi

# gh (GitHub CLI)
if command -v gh &>/dev/null; then
  # Check if authenticated
  if gh auth status &>/dev/null 2>&1; then
    info "GitHub CLI (gh) authenticated"
  else
    warn "GitHub CLI (gh) installed but not authenticated. Run: gh auth login"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  warn "GitHub CLI (gh) not found. PR creation will not work."
  echo "       Install: https://cli.github.com/"
  WARNINGS=$((WARNINGS + 1))
fi

# node/npm
if command -v node &>/dev/null; then
  info "Node.js $(node --version)"
else
  warn "Node.js not found. Build/test stages require Node.js."
  WARNINGS=$((WARNINGS + 1))
fi

if command -v npm &>/dev/null; then
  info "npm $(npm --version)"
else
  warn "npm not found. Build/test stages require npm."
  WARNINGS=$((WARNINGS + 1))
fi

# crontab
if command -v crontab &>/dev/null; then
  info "crontab available"
else
  warn "crontab not found. Orchestrator automation will not work."
  WARNINGS=$((WARNINGS + 1))
fi

if [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo "  ($WARNINGS warning(s) above -- AgentFlow will install but some features may not work)"
fi

# ---------------------------------------------------------------------------
# 3. Verify source files exist
# ---------------------------------------------------------------------------
echo ""
echo "Verifying source files..."

MISSING=0
for dir in skills prompts; do
  if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
    err "Missing directory: $SCRIPT_DIR/$dir"
    MISSING=$((MISSING + 1))
  fi
done

for f in conventions.md; do
  if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
    err "Missing file: $SCRIPT_DIR/$f"
    MISSING=$((MISSING + 1))
  fi
done

if [[ ! -f "$SCRIPT_DIR/bin/agentflow-cron.sh" ]]; then
  err "Missing file: $SCRIPT_DIR/bin/agentflow-cron.sh"
  MISSING=$((MISSING + 1))
fi

SKILL_COUNT=$(find "$SCRIPT_DIR/skills" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
PROMPT_COUNT=$(find "$SCRIPT_DIR/prompts" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

if [[ "$SKILL_COUNT" -eq 0 ]]; then
  err "No skill files found in $SCRIPT_DIR/skills/"
  MISSING=$((MISSING + 1))
fi

if [[ "$PROMPT_COUNT" -eq 0 ]]; then
  err "No prompt files found in $SCRIPT_DIR/prompts/"
  MISSING=$((MISSING + 1))
fi

if [[ $MISSING -gt 0 ]]; then
  echo ""
  err "Cannot continue -- $MISSING required file(s) missing."
  echo "  Make sure you are running setup.sh from the agentflow repository root."
  exit 1
fi

info "Source verified: $SKILL_COUNT skills, $PROMPT_COUNT prompts"

# ---------------------------------------------------------------------------
# 4. Create directories
# ---------------------------------------------------------------------------
echo ""
echo "Installing AgentFlow..."

mkdir -p "$SKILLS_DIR"
mkdir -p "$PROMPTS_DIR"
info "Created $SKILLS_DIR/"
info "Created $PROMPTS_DIR/"

# ---------------------------------------------------------------------------
# 5. Copy files
# ---------------------------------------------------------------------------
cp "$SCRIPT_DIR"/skills/*.md "$SKILLS_DIR/"
info "Skills installed ($SKILL_COUNT files)"

cp "$SCRIPT_DIR"/prompts/*.md "$PROMPTS_DIR/"
info "Prompts installed ($PROMPT_COUNT files)"

cp "$SCRIPT_DIR/conventions.md" "$SDLC_DIR/conventions.md"
info "Conventions installed"

# ---------------------------------------------------------------------------
# 5b. Install plugin (if chosen)
# ---------------------------------------------------------------------------
if $PLUGIN_MODE; then
  PLUGIN_INSTALL_DIR="$PLUGIN_DIR/agentflow"
  mkdir -p "$PLUGIN_INSTALL_DIR"
  cp -r "$SCRIPT_DIR/plugin/"* "$PLUGIN_INSTALL_DIR/"
  # Also copy dotfiles (like .mcp.json)
  cp "$SCRIPT_DIR/plugin/.mcp.json" "$PLUGIN_INSTALL_DIR/.mcp.json" 2>/dev/null || true
  info "Plugin installed to $PLUGIN_INSTALL_DIR"
  echo ""
  echo "  Plugin mode is now active. You can run:"
  echo "    claude -p '/sdlc-orchestrate'   # Start pipeline (workers spawn automatically)"
  echo ""
  echo "  No need to set up crontab or open worker terminals."
fi

# ---------------------------------------------------------------------------
# 6. Install crontab wrapper
# ---------------------------------------------------------------------------
cp "$SCRIPT_DIR/bin/agentflow-cron.sh" "$SDLC_DIR/agentflow-cron.sh"
chmod +x "$SDLC_DIR/agentflow-cron.sh"

# Update the Claude binary path in the wrapper
# Use a temp file approach that works on both macOS and Linux sed
CRON_WRAPPER="$SDLC_DIR/agentflow-cron.sh"
if [[ "$PLATFORM" == "macOS" ]]; then
  sed -i '' "s|^CLAUDE_BIN=.*|CLAUDE_BIN=\"$CLAUDE_BIN\"|" "$CRON_WRAPPER"
else
  sed -i "s|^CLAUDE_BIN=.*|CLAUDE_BIN=\"$CLAUDE_BIN\"|" "$CRON_WRAPPER"
fi
info "Crontab wrapper installed ($CRON_WRAPPER)"

# ---------------------------------------------------------------------------
# 7. Optional: configure crontab
# ---------------------------------------------------------------------------
if $WITH_CRON; then
  echo ""
  echo "Setting up crontab..."

  CRON_LINE="*/15 * * * * $SDLC_DIR/agentflow-cron.sh >> /tmp/agentflow-orchestrate.log 2>&1"

  # Add to crontab without duplicating existing entry
  EXISTING_CRONTAB=$(crontab -l 2>/dev/null || true)
  FILTERED=$(echo "$EXISTING_CRONTAB" | grep -v "agentflow-cron.sh" || true)

  if [[ -z "$FILTERED" ]]; then
    echo "$CRON_LINE" | crontab -
  else
    printf '%s\n%s\n' "$FILTERED" "$CRON_LINE" | crontab -
  fi

  info "Crontab configured (every 15 minutes)"
  echo "       View:  crontab -l"
  echo "       Logs:  tail -f /tmp/agentflow-orchestrate.log"

  # macOS: remind about cron permissions
  if [[ "$PLATFORM" == "macOS" ]]; then
    echo ""
    warn "macOS may require granting cron Full Disk Access."
    echo "       System Settings > Privacy & Security > Full Disk Access > add /usr/sbin/cron"
  fi
fi

# ---------------------------------------------------------------------------
# 8. Summary
# ---------------------------------------------------------------------------
header "Setup Complete"

echo "Installed to:"
echo "  Skills:      $SKILLS_DIR/ ($SKILL_COUNT files)"
echo "  Prompts:     $PROMPTS_DIR/ ($PROMPT_COUNT files)"
echo "  Conventions: $SDLC_DIR/conventions.md"
echo "  Cron wrapper: $SDLC_DIR/agentflow-cron.sh"
echo ""

if $WITH_CRON; then
  echo "Orchestrator: ACTIVE (crontab every 15 min)"
else
  echo "Orchestrator: NOT configured (run ./setup.sh --with-cron to enable)"
fi
echo "Model: $MODEL"
echo ""

echo "Next steps:"
echo ""
echo "  1. Verify your setup:"
echo "     claude -p '/sdlc-health'"
echo ""
echo "  2. Try the 5-minute demo:"
echo "     claude -p '/sdlc-demo'"
echo ""
echo "  3. Or start a real project:"
echo "     a. Write a SPEC.md for your project"
echo "     b. Decompose:  claude -p '/spec-to-asana'"
echo "     c. Start workers in separate terminals:"
echo "        claude -p '/sdlc-worker --slot T2'"
echo "        claude -p '/sdlc-worker --slot T3'"
echo "        claude -p '/sdlc-worker --slot T4'"
echo "        claude -p '/sdlc-worker --slot T5'"
if ! $WITH_CRON; then
  echo "     d. Enable the orchestrator:  ./setup.sh --with-cron"
  echo "        Or run manually:  claude -p '/sdlc-orchestrate'"
fi
echo ""
echo "Docs: https://github.com/UrRhb/agentflow"
echo ""
