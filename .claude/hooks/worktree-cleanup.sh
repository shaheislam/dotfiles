#!/bin/bash
set -euo pipefail
# WorktreeRemove hook - cleanup when worktrees are removed

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // ""' 2>/dev/null || echo "")

LOG_DIR="$HOME/.claude/hooks/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree-$(date +%Y-%m-%d).log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeRemove: ${WORKTREE_PATH:-unknown}" >>"$LOG_FILE"

# Sync beads before removal
if command -v bd &>/dev/null && [ -n "$WORKTREE_PATH" ]; then
    (cd "$WORKTREE_PATH" && bd sync 2>/dev/null) || true
fi

# Synthesize session into Obsidian before the worktree is gone.
# Covers the manual `git worktree remove` path that bypasses tmux cleanup.
SYNTHESIZE_SCRIPT="$HOME/dotfiles/scripts/obsidian/session-synthesize.sh"
if [ -x "$SYNTHESIZE_SCRIPT" ] && [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
    timeout 60 bash "$SYNTHESIZE_SCRIPT" --cwd "$WORKTREE_PATH" --worktree "$WORKTREE_PATH" \
        </dev/null >>"$LOG_FILE" 2>&1 || true
fi

exit 0
