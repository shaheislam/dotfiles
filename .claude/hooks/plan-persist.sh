#!/usr/bin/env bash
# plan-persist.sh - PreCompact hook to preserve living plan across compaction
#
# Reads .claude/plan.md and outputs it as context so the compacted session
# retains the full plan state. Also reminds Claude to keep the plan updated.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.claude/plan.md"
[[ -f "$PLAN_FILE" ]] || exit 0

# Output the plan content so it survives compaction
echo "=== Living Plan (from .claude/plan.md) ==="
cat "$PLAN_FILE"
echo ""
echo "=== End Living Plan ==="
echo ""
echo "IMPORTANT: The above plan was loaded from .claude/plan.md. After compaction,"
echo "update .claude/plan.md with your current progress, decisions, and next steps."
echo "This file is your persistent memory across compactions."

exit 0
