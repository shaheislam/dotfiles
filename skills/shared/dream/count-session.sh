#!/usr/bin/env bash
#
# count-session.sh - Increment session counter for dream trigger
#
# Called from SessionStart hook. Increments a counter that resets
# after each dream consolidation. This enables the minSessions
# threshold trigger.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_COUNT_FILE="$SKILL_DIR/.session-count"

# Read current count or start at 0
count=0
if [[ -f "$SESSION_COUNT_FILE" ]]; then
    count=$(cat "$SESSION_COUNT_FILE" 2>/dev/null || echo "0")
fi

# Increment
count=$((count + 1))
echo "$count" >"$SESSION_COUNT_FILE"

exit 0
