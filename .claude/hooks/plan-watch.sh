#!/usr/bin/env bash
# plan-watch.sh - PostToolUse hook to detect external edits and plan staleness
#
# Two responsibilities:
# 1. Detect external edits to .plan.md and show the diff (#3)
# 2. Detect plan staleness — warn if plan hasn't been updated in N minutes (#2)
#
# Uses /tmp cache files for mtime comparison and content snapshots.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
[[ -z "$PROJECT_DIR" ]] && exit 0

PLAN_FILE="$PROJECT_DIR/.plan.md"
# Fallback to legacy location for existing worktrees
[[ -f "$PLAN_FILE" ]] || PLAN_FILE="$PROJECT_DIR/.claude/plan.md"
[[ -f "$PLAN_FILE" ]] || exit 0

CACHE_KEY=$(echo "$PROJECT_DIR" | tr '/' '-')
MTIME_CACHE="/tmp/plan-watch-mtime${CACHE_KEY}"
CONTENT_CACHE="/tmp/plan-watch-content${CACHE_KEY}"
STALE_WARN_CACHE="/tmp/plan-watch-stale-warned${CACHE_KEY}"

# Get current mtime
if [[ "$(uname)" == "Darwin" ]]; then
    CURRENT_MTIME=$(stat -f %m "$PLAN_FILE" 2>/dev/null) || exit 0
else
    CURRENT_MTIME=$(stat -c %Y "$PLAN_FILE" 2>/dev/null) || exit 0
fi

CACHED_MTIME=""
[[ -f "$MTIME_CACHE" ]] && CACHED_MTIME=$(cat "$MTIME_CACHE" 2>/dev/null)

# --- (#2) Staleness detection ---
# Warn once if plan hasn't been updated in 10+ minutes
if [[ -n "$CACHED_MTIME" && "$CURRENT_MTIME" == "$CACHED_MTIME" ]]; then
    NOW=$(date +%s)
    AGE=$((NOW - CURRENT_MTIME))
    STALE_THRESHOLD=600 # 10 minutes

    if [[ "$AGE" -gt "$STALE_THRESHOLD" ]]; then
        # Only warn once per stale period
        LAST_WARN=""
        [[ -f "$STALE_WARN_CACHE" ]] && LAST_WARN=$(cat "$STALE_WARN_CACHE" 2>/dev/null)
        if [[ "$LAST_WARN" != "$CURRENT_MTIME" ]]; then
            echo "$CURRENT_MTIME" >"$STALE_WARN_CACHE"
            MINS=$((AGE / 60))
            echo "PLAN STALE — .plan.md hasn't been updated in ${MINS} minutes."
            echo "Update Current State and Next Steps to keep your persistent memory fresh."
        fi
    fi
    exit 0
fi

# Mtime changed — update cache
echo "$CURRENT_MTIME" >"$MTIME_CACHE"

# First run — seed cache and snapshot, no output
if [[ -z "$CACHED_MTIME" ]]; then
    cp "$PLAN_FILE" "$CONTENT_CACHE" 2>/dev/null || true
    exit 0
fi

# Check if agent itself just edited plan.md
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
    if [[ "$TOOL_INPUT" == *"plan.md"* ]]; then
        # Agent edited — stamp last_updated in frontmatter
        NOW_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        if head -1 "$PLAN_FILE" | grep -q '^---$'; then
            if grep -q '^last_updated:' "$PLAN_FILE"; then
                awk -v ts="$NOW_UTC" '{
                    if ($0 ~ /^last_updated:/) print "last_updated: \"" ts "\""
                    else print
                }' "$PLAN_FILE" >"${PLAN_FILE}.tmp" && mv "${PLAN_FILE}.tmp" "$PLAN_FILE"
            else
                # Insert last_updated before closing --- of frontmatter
                awk -v ts="$NOW_UTC" 'BEGIN{s=0;d=0} /^---$/ && !s{s=1;print;next} /^---$/ && s && !d{print "last_updated: \"" ts "\""; d=1} {print}' "$PLAN_FILE" >"${PLAN_FILE}.tmp" && mv "${PLAN_FILE}.tmp" "$PLAN_FILE"
            fi
        fi
        # Update snapshot silently, clear stale warning
        cp "$PLAN_FILE" "$CONTENT_CACHE" 2>/dev/null || true
        rm -f "$STALE_WARN_CACHE" 2>/dev/null || true
        exit 0
    fi
fi

# --- (#3) External edit detected — show diff ---
echo "PLAN UPDATED EXTERNALLY — .plan.md was modified outside this session."
echo "Review the changes and course-correct your approach accordingly."
echo ""

# Show diff if we have a content snapshot
if [[ -f "$CONTENT_CACHE" ]]; then
    DIFF=$(diff --unified=1 "$CONTENT_CACHE" "$PLAN_FILE" 2>/dev/null | tail -n +3) || true
    if [[ -n "$DIFF" ]]; then
        echo "Changes:"
        echo "$DIFF"
        echo ""
    fi
fi

# Also show key sections for full context
EXTRACTOR="$PROJECT_DIR/.claude/hooks/plan-extract-sections.sh"
if [[ ! -x "$EXTRACTOR" ]]; then
    EXTRACTOR="$HOME/dotfiles/.claude/hooks/plan-extract-sections.sh"
fi

SECTIONS=""
if [[ -x "$EXTRACTOR" ]]; then
    SECTIONS=$(bash "$EXTRACTOR" "$PLAN_FILE" 2>/dev/null) || true
fi

if [[ -n "$SECTIONS" ]]; then
    echo "=== Updated Plan (key sections) ==="
    echo "$SECTIONS"
    echo "=== End Updated Plan ==="
fi

# Update content snapshot and clear stale warning
cp "$PLAN_FILE" "$CONTENT_CACHE" 2>/dev/null || true
rm -f "$STALE_WARN_CACHE" 2>/dev/null || true

exit 0
