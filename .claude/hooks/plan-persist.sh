#!/usr/bin/env bash
# plan-persist.sh - PreCompact hook to preserve living plan across compaction
#
# Extracts key sections from .plan.md. Keeps context small.
# (#9) Creates a backup before compaction for crash recovery.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.plan.md"
# Fallback to legacy location for existing worktrees
[[ -f "$PLAN_FILE" ]] || PLAN_FILE="$PROJECT_DIR/.claude/plan.md"
[[ -f "$PLAN_FILE" ]] || exit 0

# (#9) Backup plan before compaction — crash recovery safety net
cp "$PLAN_FILE" "${PLAN_FILE}.bak" 2>/dev/null || true

EXTRACTOR="$PROJECT_DIR/.claude/hooks/plan-extract-sections.sh"
if [[ ! -x "$EXTRACTOR" ]]; then
    EXTRACTOR="$HOME/dotfiles/.claude/hooks/plan-extract-sections.sh"
fi

SECTIONS=""
if [[ -x "$EXTRACTOR" ]]; then
    SECTIONS=$(bash "$EXTRACTOR" "$PLAN_FILE" 2>/dev/null) || true
fi

if [[ -n "$SECTIONS" ]]; then
    echo "=== Living Plan (key sections from .plan.md) ==="
    echo "$SECTIONS"
    echo "=== End Living Plan ==="
    echo ""
    echo "After compaction, read .plan.md for full context, then update it."
else
    echo "A plan file exists at .plan.md — read it after compaction to resume."
fi

exit 0
