#!/usr/bin/env bash
# Opens the per-directory gwtt-prompt.local.md in nvim.
# Used by tmux bind E to resolve the correct prompt file for the active pane.
# Auto-creates per-repo file if it doesn't exist. No global fallback.

set -euo pipefail

# Get the pane's working directory (passed by tmux or default to CWD)
PANE_DIR="${1:-$(pwd)}"

# Find git root
GIT_ROOT=$(git -C "$PANE_DIR" rev-parse --show-toplevel 2>/dev/null || true)

if [[ -z "$GIT_ROOT" ]]; then
    echo "Error: not inside a git repository: $PANE_DIR"
    echo "Press enter to close..."
    read -r
    exit 1
fi

REPO_PROMPT="$GIT_ROOT/.claude/gwtt-prompt.local.md"

if [[ ! -f "$REPO_PROMPT" ]]; then
    mkdir -p "$GIT_ROOT/.claude"
    REPO_NAME=$(basename "$GIT_ROOT")
    printf '# %s — Task Prompt\n\nDescribe your task here.\n' "$REPO_NAME" >"$REPO_PROMPT"
fi

exec nvim -c 'setlocal textwidth=80 formatoptions+=t wrap linebreak' "$REPO_PROMPT"
