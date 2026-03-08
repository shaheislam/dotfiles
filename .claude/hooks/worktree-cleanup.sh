#!/bin/bash
set -euo pipefail
# WorktreeRemove hook - cleanup when worktrees are removed

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | python3 -c "import json, sys; print(json.load(sys.stdin).get('worktree_path', ''))" 2>/dev/null || echo "")

LOG_DIR="$HOME/.claude/hooks/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/worktree-$(date +%Y-%m-%d).log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorktreeRemove: ${WORKTREE_PATH:-unknown}" >>"$LOG_FILE"

# Sync beads before removal
if command -v bd &>/dev/null && [ -n "$WORKTREE_PATH" ]; then
    (cd "$WORKTREE_PATH" && bd sync 2>/dev/null) || true
fi

exit 0
