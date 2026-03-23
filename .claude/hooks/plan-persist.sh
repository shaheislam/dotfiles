#!/usr/bin/env bash
# plan-persist.sh - PreCompact hook to preserve living plan across compaction
#
# Extracts key sections (Current State, Next Steps, Useful Commands) from
# .claude/plan.md rather than injecting the full plan. Keeps context small.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.claude/plan.md"
[[ -f "$PLAN_FILE" ]] || exit 0

EXTRACTOR="$PROJECT_DIR/.claude/hooks/plan-extract-sections.sh"
if [[ ! -x "$EXTRACTOR" ]]; then
    EXTRACTOR="$HOME/dotfiles/.claude/hooks/plan-extract-sections.sh"
fi

SECTIONS=""
if [[ -x "$EXTRACTOR" ]]; then
    SECTIONS=$(bash "$EXTRACTOR" "$PLAN_FILE" 2>/dev/null) || true
fi

if [[ -n "$SECTIONS" ]]; then
    echo "=== Living Plan (key sections from .claude/plan.md) ==="
    echo "$SECTIONS"
    echo "=== End Living Plan ==="
    echo ""
    echo "After compaction, read .claude/plan.md for full context, then update it."
else
    echo "A plan file exists at .claude/plan.md — read it after compaction to resume."
fi

exit 0
