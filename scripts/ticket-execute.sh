#!/usr/bin/env bash
#
# ticket-execute.sh - Thin orchestrator for autonomous ticket execution
#
# This script is a simplified wrapper that delegates to gwt-ticket.fish
# for the actual worktree/devcontainer/tmux setup.
#
# Usage:
#   ticket-execute.sh <ISSUE_KEY> <TITLE> <DESCRIPTION> [OPTIONS]
#
# Options:
#   --max N              Max iterations (default: 20)
#   --command C          Slash command (default: /ralph-loop:ralph-loop)
#   --prompt-template F  Custom prompt template file
#   --prompt-prefix P    Text to prepend to prompt
#   --prompt-suffix S    Text to append to prompt
#   --session S          Tmux session name (default: repo name)
#   --system S           Ticketing system: linear or jira
#   --mount M            Additional mount (repeatable)
#   --devcon          Use devcontainer for isolation (default: local)
#   --dry-run            Show what would be executed without running
#   --quiet, -q          Suppress verbose output (default)
#   --verbose, -v        Show full verbose output
#   --help               Show this help

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat <<'EOF'
ticket-execute.sh - Orchestrate autonomous ticket execution

USAGE:
  ticket-execute.sh <ISSUE_KEY> <TITLE> <DESCRIPTION> [OPTIONS]

ARGUMENTS:
  ISSUE_KEY     Issue key (e.g., ENG-123, DEVOPS-456)
  TITLE         Issue title/summary
  DESCRIPTION   Full issue description

OPTIONS:
  --max N              Max iterations (default: 20)
  --command C          Slash command (default: /ralph-loop:ralph-loop)
  --prompt-template F  Custom prompt template file
  --prompt-prefix P    Text to prepend to prompt
  --prompt-suffix S    Text to append to prompt
  --session S          Tmux session name (default: repo name)
  --system S           Ticketing system: linear or jira
  --mount M            Additional mount directory (repeatable)
  --devcon          Use devcontainer for isolation (default: local)
  --dry-run            Show what would be executed without running
  --quiet, -q          Suppress verbose output (default; writes to .claude/gwt-ticket.log)
  --verbose, -v        Show full verbose output (overrides default quiet mode)
  --help               Show this help

EXAMPLES:
  ticket-execute.sh ENG-123 "Fix auth bug" "Session tokens expire" --max 10
  ticket-execute.sh DEVOPS-456 "Add monitoring" "Add Prometheus" --system jira
  ticket-execute.sh ENG-789 "Refactor API" "Clean up" --devcon

WHAT IT DOES:
  Delegates to gwt-ticket for:
  1. Creating git worktree via gwt-dev
  2. Starting devcontainer with isolated instance
  3. Creating tmux window in repo-named session
  4. Launching Claude with ralph-loop

MONITORING:
  tmux attach -t <repo-name>
  tmux select-window -t <repo-name>:<ISSUE_KEY>
EOF
}

# Defaults
MAX_ITERATIONS=20
SESSION_NAME=""
TICKETING_SYSTEM=""
SLASH_COMMAND=""
PROMPT_TEMPLATE=""
PROMPT_PREFIX=""
PROMPT_SUFFIX=""
USE_DEVCON=false
DRY_RUN=false
QUIET=false
VERBOSE=false
MOUNTS=()

# Parse arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
    --max)
        MAX_ITERATIONS="$2"
        shift 2
        ;;
    --session)
        SESSION_NAME="$2"
        shift 2
        ;;
    --system)
        TICKETING_SYSTEM="$2"
        shift 2
        ;;
    --command)
        SLASH_COMMAND="$2"
        shift 2
        ;;
    --prompt-template)
        PROMPT_TEMPLATE="$2"
        shift 2
        ;;
    --prompt-prefix)
        PROMPT_PREFIX="$2"
        shift 2
        ;;
    --prompt-suffix)
        PROMPT_SUFFIX="$2"
        shift 2
        ;;
    --mount | -m)
        MOUNTS+=("$2")
        shift 2
        ;;
    --devcon)
        USE_DEVCON=true
        shift
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --quiet | -q)
        QUIET=true
        shift
        ;;
    --verbose | -v)
        VERBOSE=true
        shift
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    -*)
        echo -e "${RED}Error: Unknown option $1${NC}" >&2
        exit 1
        ;;
    *)
        POSITIONAL_ARGS+=("$1")
        shift
        ;;
    esac
done

# Assign positional arguments
if [[ ${#POSITIONAL_ARGS[@]} -lt 3 ]]; then
    echo -e "${RED}Error: Missing required arguments${NC}" >&2
    echo "Usage: ticket-execute.sh <ISSUE_KEY> <TITLE> <DESCRIPTION> [OPTIONS]" >&2
    exit 1
fi

ISSUE_KEY="${POSITIONAL_ARGS[0]}"
TITLE="${POSITIONAL_ARGS[1]}"
DESCRIPTION="${POSITIONAL_ARGS[2]}"

# Validate issue key format
if ! [[ "$ISSUE_KEY" =~ ^[A-Z]+-[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid issue key format: $ISSUE_KEY${NC}" >&2
    echo "Expected format: ABC-123 (uppercase letters, dash, numbers)" >&2
    exit 1
fi

# Build gwt-ticket arguments
GWT_ARGS=("$ISSUE_KEY" "$TITLE" "$DESCRIPTION")
GWT_ARGS+=("--max" "$MAX_ITERATIONS")

if [[ -n "$SESSION_NAME" ]]; then
    GWT_ARGS+=("--session" "$SESSION_NAME")
fi

if [[ -n "$TICKETING_SYSTEM" ]]; then
    GWT_ARGS+=("--system" "$TICKETING_SYSTEM")
fi

if [[ -n "$SLASH_COMMAND" ]]; then
    GWT_ARGS+=("--command" "$SLASH_COMMAND")
fi

if [[ -n "$PROMPT_TEMPLATE" ]]; then
    GWT_ARGS+=("--prompt-template" "$PROMPT_TEMPLATE")
fi

if [[ -n "$PROMPT_PREFIX" ]]; then
    GWT_ARGS+=("--prompt-prefix" "$PROMPT_PREFIX")
fi

if [[ -n "$PROMPT_SUFFIX" ]]; then
    GWT_ARGS+=("--prompt-suffix" "$PROMPT_SUFFIX")
fi

if [[ "$USE_DEVCON" == "true" ]]; then
    GWT_ARGS+=("--devcon")
fi

if [[ "$QUIET" == "true" ]]; then
    GWT_ARGS+=("--quiet")
fi

if [[ "$VERBOSE" == "true" ]]; then
    GWT_ARGS+=("--verbose")
fi

for mount in "${MOUNTS[@]}"; do
    GWT_ARGS+=("--mount" "$mount")
done

if $DRY_RUN; then
    echo -e "${YELLOW}=== DRY RUN - Would execute: ===${NC}"
    echo ""
    echo "fish -c 'gwt-ticket ${GWT_ARGS[*]}'"
    echo ""
    echo "This would:"
    echo "  1. Create worktree via gwt-dev"
    echo "  2. Start devcontainer (if available)"
    echo "  3. Create tmux window in repo-named session"
    echo "  4. Launch Claude with ${SLASH_COMMAND:-/ralph-loop:ralph-loop} ($MAX_ITERATIONS iterations max)"
    exit 0
fi

if [[ "$QUIET" != "true" ]]; then
    echo -e "${BLUE}=== Ticket Execute ===${NC}"
    echo -e "Issue:     ${GREEN}$ISSUE_KEY${NC}"
    echo -e "Title:     $TITLE"
    echo -e "Max iter:  $MAX_ITERATIONS"
    echo ""
fi

# Build gwt-ticket command with proper escaping
GWT_CMD="gwt-ticket '$ISSUE_KEY' '$TITLE' '$DESCRIPTION' --max $MAX_ITERATIONS"

if [[ -n "$SESSION_NAME" ]]; then
    GWT_CMD="$GWT_CMD --session '$SESSION_NAME'"
fi

if [[ -n "$TICKETING_SYSTEM" ]]; then
    GWT_CMD="$GWT_CMD --system $TICKETING_SYSTEM"
fi

if [[ -n "$SLASH_COMMAND" ]]; then
    GWT_CMD="$GWT_CMD --command '$SLASH_COMMAND'"
fi

if [[ -n "$PROMPT_TEMPLATE" ]]; then
    GWT_CMD="$GWT_CMD --prompt-template '$PROMPT_TEMPLATE'"
fi

if [[ -n "$PROMPT_PREFIX" ]]; then
    GWT_CMD="$GWT_CMD --prompt-prefix '$PROMPT_PREFIX'"
fi

if [[ -n "$PROMPT_SUFFIX" ]]; then
    GWT_CMD="$GWT_CMD --prompt-suffix '$PROMPT_SUFFIX'"
fi

if [[ "$USE_DEVCON" == "true" ]]; then
    GWT_CMD="$GWT_CMD --devcon"
fi

for mount in "${MOUNTS[@]}"; do
    GWT_CMD="$GWT_CMD --mount '$mount'"
done

# Execute gwt-ticket
fish -c "$GWT_CMD"
