#!/usr/bin/env bash
# Opens the per-directory gwtt-prompt.local.md in nvim.
# Used by tmux bind E to resolve the correct prompt file for the active pane.
#
# Resolution order:
#   1. <git-root>/.claude/gwtt-prompt.local.md (per-repo)
#   2. $HOME/dotfiles/.claude/gwtt-prompt.local.md (global fallback)
#   3. Creates the per-repo file if neither exists

set -euo pipefail

GLOBAL_PROMPT="$HOME/dotfiles/.claude/gwtt-prompt.local.md"

# Get the pane's working directory (passed by tmux or default to CWD)
PANE_DIR="${1:-$(pwd)}"

# Find git root
GIT_ROOT=$(git -C "$PANE_DIR" rev-parse --show-toplevel 2>/dev/null || true)

PROMPT_FILE=""

if [[ -n "$GIT_ROOT" ]]; then
    REPO_PROMPT="$GIT_ROOT/.claude/gwtt-prompt.local.md"
    if [[ -f "$REPO_PROMPT" ]]; then
        PROMPT_FILE="$REPO_PROMPT"
    elif [[ -f "$GLOBAL_PROMPT" ]]; then
        PROMPT_FILE="$GLOBAL_PROMPT"
    else
        # Create per-repo prompt file with template
        mkdir -p "$GIT_ROOT/.claude"
        REPO_NAME=$(basename "$GIT_ROOT")
        printf '# %s — Task Prompt\n\nDescribe your task here.\n' "$REPO_NAME" >"$REPO_PROMPT"
        PROMPT_FILE="$REPO_PROMPT"
    fi
else
    # Not in a git repo — use global
    if [[ ! -f "$GLOBAL_PROMPT" ]]; then
        mkdir -p "$(dirname "$GLOBAL_PROMPT")"
        printf '# Task Prompt\n\nDescribe your task here.\n' >"$GLOBAL_PROMPT"
    fi
    PROMPT_FILE="$GLOBAL_PROMPT"
fi

exec nvim -c 'setlocal textwidth=80 formatoptions+=t wrap linebreak' "$PROMPT_FILE"
