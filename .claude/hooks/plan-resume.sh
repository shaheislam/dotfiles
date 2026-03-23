#!/usr/bin/env bash
# plan-resume.sh - SessionStart hook to inject living plan into context
#
# Extracts key sections (Current State, Next Steps, Useful Commands) from
# .claude/plan.md rather than injecting the full plan. Keeps context small.
# Silent exit when no plan exists or plan has no meaningful content.

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
    echo "=== Living Plan (.claude/plan.md) ==="
    echo "$SECTIONS"
    echo "=== End Living Plan ==="
    echo ""
    echo "Read .claude/plan.md for full context. Keep it updated as you work."
fi

exit 0
