#!/bin/bash
set -euo pipefail
# WorktreeCreate hook - initialize new worktrees with beads + checkpoints

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // ""' 2>/dev/null || echo "")

if [ -z "$WORKTREE_PATH" ]; then
    exit 0
fi

LOG_DIR="$HOME/.claude/hooks/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree-$(date +%Y-%m-%d).log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeCreate: $WORKTREE_PATH" >>"$LOG_FILE"

# Initialize beads/checkpoints without holding the WorktreeCreate hook. These
# only need to be ready by the first agent commit, not before Claude continues.
(
    if command -v bd &>/dev/null; then
        (cd "$WORKTREE_PATH" && bd prime 2>/dev/null) || true
    fi

    if command -v entire &>/dev/null; then
        (cd "$WORKTREE_PATH" && entire enable 2>/dev/null) || true
    fi
) </dev/null >/dev/null 2>&1 &

exit 0
