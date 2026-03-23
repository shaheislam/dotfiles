#!/usr/bin/env bash
# plan-watch.sh - PostToolUse hook to detect external edits to .claude/plan.md
#
# Lightweight mtime check on every tool call. Only outputs the plan content
# when the file was modified externally (not by the agent's own Edit/Write).
# Uses /tmp cache file for mtime comparison — one stat call per invocation.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.claude/plan.md"
[[ -f "$PLAN_FILE" ]] || exit 0

# Cache file stores last-seen mtime (unique per project dir)
CACHE_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MTIME_CACHE="/tmp/plan-watch-mtime${CACHE_KEY}"

# Get current mtime (macOS stat format)
if [[ "$(uname)" == "Darwin" ]]; then
    CURRENT_MTIME=$(stat -f %m "$PLAN_FILE" 2>/dev/null) || exit 0
else
    CURRENT_MTIME=$(stat -c %Y "$PLAN_FILE" 2>/dev/null) || exit 0
fi

# Read cached mtime
CACHED_MTIME=""
[[ -f "$MTIME_CACHE" ]] && CACHED_MTIME=$(cat "$MTIME_CACHE" 2>/dev/null)

# If mtime unchanged, nothing to do
if [[ "$CURRENT_MTIME" == "$CACHED_MTIME" ]]; then
    exit 0
fi

# Update cache immediately
echo "$CURRENT_MTIME" >"$MTIME_CACHE"

# First run — seed the cache, don't inject (agent already got it from SessionStart)
if [[ -z "$CACHED_MTIME" ]]; then
    exit 0
fi

# Check if the agent itself just edited plan.md (parse stdin for tool context)
# PostToolUse receives JSON with tool_name and tool_input on stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# If the agent just wrote/edited plan.md, skip re-injection (it knows what it wrote)
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
    if [[ "$TOOL_INPUT" == *"plan.md"* ]]; then
        exit 0
    fi
fi

# External edit detected — inject key sections from updated plan
EXTRACTOR="$PROJECT_DIR/.claude/hooks/plan-extract-sections.sh"
if [[ ! -x "$EXTRACTOR" ]]; then
    EXTRACTOR="$HOME/dotfiles/.claude/hooks/plan-extract-sections.sh"
fi

echo "PLAN UPDATED EXTERNALLY — .claude/plan.md was modified outside this session."
echo "Review the changes and course-correct your approach accordingly."
echo ""

SECTIONS=""
if [[ -x "$EXTRACTOR" ]]; then
    SECTIONS=$(bash "$EXTRACTOR" "$PLAN_FILE" 2>/dev/null) || true
fi

if [[ -n "$SECTIONS" ]]; then
    echo "=== Updated Plan (key sections) ==="
    echo "$SECTIONS"
    echo "=== End Updated Plan ==="
else
    echo "Read .claude/plan.md for the full updated plan."
fi

exit 0
