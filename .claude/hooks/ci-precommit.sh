#!/usr/bin/env bash
# ci-precommit.sh — Claude Code PreToolUse(Bash) hook.
# Intercepts git commit/push in ~/work repos and runs CI checks first.
# Returns JSON with decision to allow/block the tool use.
#
# Hook protocol:
#   stdin: JSON with tool_name and tool_input
#   stdout: JSON with {"decision": "allow"} or {"decision": "block", "reason": "..."}
#
# Only activates for git commit/push commands in watched directories.

set -euo pipefail

CI_HOOKS_DIR="$HOME/dotfiles/scripts/ci-hooks"
# Fallback for dotfiles-hooks worktree
if [[ ! -d "$CI_HOOKS_DIR" ]]; then
    CI_HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../scripts/ci-hooks" 2>/dev/null && pwd)" || true
fi

# Read hook input from stdin
INPUT="$(cat)"

# Extract the bash command
COMMAND="$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)" || COMMAND=""

# Only care about git commit and git push
case "$COMMAND" in
git\ commit* | git\ push*) ;;
*)
    # Not a commit/push — allow immediately
    echo '{"decision":"allow"}'
    exit 0
    ;;
esac

# Check if we're in a watched directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if ! "$CI_HOOKS_DIR/ci-local.sh" --check-only "$PROJECT_DIR" >/dev/null 2>&1; then
    # Not in a watched path — allow
    echo '{"decision":"allow"}'
    exit 0
fi

# Run CI checks
CI_OUTPUT="$("$CI_HOOKS_DIR/ci-local.sh" "$PROJECT_DIR" 2>&1)" || {
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 2 ]]; then
        # Not watched — allow
        echo '{"decision":"allow"}'
        exit 0
    fi
    # CI failed — block with reason
    REASON="$(echo "$CI_OUTPUT" | tail -5 | tr '\n' ' ')"
    # Escape for JSON
    REASON="$(echo "$REASON" | sed 's/"/\\"/g')"
    echo "{\"decision\":\"block\",\"reason\":\"Local CI failed. $REASON\"}"
    exit 0
}

# CI passed — allow
echo '{"decision":"allow"}'
exit 0
