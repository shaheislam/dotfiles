#!/usr/bin/env bash
# plan-resume.sh - SessionStart hook to inject living plan into context
#
# On session start (fresh or post-compaction), reads .claude/plan.md and
# outputs it so Claude has the full plan context immediately.
# Silent exit when no plan exists.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.claude/plan.md"
[[ -f "$PLAN_FILE" ]] || exit 0

# Check the plan has content beyond just the template header
CONTENT_LINES=$(grep -cv '^\s*$\|^---$\|^#' "$PLAN_FILE" 2>/dev/null || echo "0")
[[ "$CONTENT_LINES" -eq 0 ]] && exit 0

echo "=== Living Plan (.claude/plan.md) ==="
cat "$PLAN_FILE"
echo "=== End Living Plan ==="
echo ""
echo "Keep .claude/plan.md updated as you work. Update it after completing"
echo "subtasks, making key decisions, or before natural stopping points."

exit 0
