#!/usr/bin/env bash
#
# dream-status.sh - Output dream status for status line integration
#
# Outputs one of:
#   "running"           - dream is currently active
#   "never"             - dream has never run
#   "last ran Xh ago"   - time since last run
#   "/dream to run"     - hint when enabled but not running (default idle output)
#
# Usage: dream-status.sh [--hint]
#   --hint: Include "/dream to run" hint when idle (for status line)

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_FILE="$SKILL_DIR/.dream-status"
SHOW_HINT="${1:-}"

# Check if dream is currently running
if [[ -f "$STATUS_FILE" ]]; then
    status_content=$(cat "$STATUS_FILE" 2>/dev/null || echo "")

    if [[ "$status_content" == "running" ]]; then
        echo "running"
        exit 0
    fi

    if [[ "$status_content" == last_ran:* ]]; then
        last_ran_ts="${status_content#last_ran:}"
        now=$(date +%s)
        elapsed=$((now - last_ran_ts))

        if [[ $elapsed -lt 3600 ]]; then
            mins=$((elapsed / 60))
            echo "last ran ${mins}m ago"
        elif [[ $elapsed -lt 86400 ]]; then
            hours=$((elapsed / 3600))
            echo "last ran ${hours}h ago"
        else
            days=$((elapsed / 86400))
            echo "last ran ${days}d ago"
        fi
        exit 0
    fi
fi

# Check if dream has EVER run by looking for .last-dream files
found_last_dream=false
for dir in "$HOME/.claude/projects/"*/memory/; do
    if [[ -f "$dir/.last-dream" ]]; then
        found_last_dream=true
        last_dream_ts=$(cat "$dir/.last-dream" 2>/dev/null || echo "0")
        now=$(date +%s)
        elapsed=$((now - last_dream_ts))

        if [[ $elapsed -lt 3600 ]]; then
            mins=$((elapsed / 60))
            echo "last ran ${mins}m ago"
        elif [[ $elapsed -lt 86400 ]]; then
            hours=$((elapsed / 3600))
            echo "last ran ${hours}h ago"
        else
            days=$((elapsed / 86400))
            echo "last ran ${days}d ago"
        fi
        exit 0
    fi
done

if [[ "$found_last_dream" == false ]]; then
    if [[ "$SHOW_HINT" == "--hint" ]]; then
        echo "never — /dream to run"
    else
        echo "never"
    fi
    exit 0
fi
