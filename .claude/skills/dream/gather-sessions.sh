#!/usr/bin/env bash
#
# gather-sessions.sh - Collect session metadata for dream agent
#
# Outputs a list of sessions since last consolidation with their
# first user prompts. This matches the native autodream behavior of
# feeding the agent "a list of sessions since the last consolidation
# with their first prompts."
#
# Usage: gather-sessions.sh [days]
#   days: lookback window (default: from .dream-config DREAM_SESSION_WINDOW_DAYS)

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SKILL_DIR/.dream-config"

read_config() {
    local key="$1" default="$2"
    if [[ -f "$CONFIG" ]]; then
        grep "^${key}=" "$CONFIG" 2>/dev/null | cut -d= -f2 || echo "$default"
    else
        echo "$default"
    fi
}

DAYS="${1:-$(read_config "DREAM_SESSION_WINDOW_DAYS" "7")}"
MEMORY_TYPE=$(read_config "DREAM_MEMORY_TYPE" "native")

# Find session files based on memory type
find_sessions() {
    case "$MEMORY_TYPE" in
    native)
        find "$HOME/.claude/projects/"*/sessions/ -name "*.jsonl" -mtime "-${DAYS}" 2>/dev/null | sort -t/ -k6 -r
        ;;
    openclaw | project-root)
        local mem_path
        mem_path=$(read_config "DREAM_MEMORY_PATH" ".")
        mem_path="${mem_path/#\~/$HOME}"
        find "$mem_path/sessions/" -name "*.jsonl" -mtime "-${DAYS}" 2>/dev/null | sort -r
        ;;
    esac
}

# Extract first user prompt from a JSONL session file
first_prompt() {
    local file="$1"
    # Find first line with type=human and extract content
    grep -m1 '"type":"human"' "$file" 2>/dev/null |
        sed 's/.*"content":"\([^"]*\)".*/\1/' |
        head -c 200
}

echo "Sessions since last consolidation (last ${DAYS} days):"
echo "---"

session_files=$(find_sessions)
if [[ -z "$session_files" ]]; then
    echo "(no sessions found)"
    exit 0
fi

count=0
while IFS= read -r session_file; do
    if [[ -f "$session_file" ]]; then
        # Get modification date
        mod_date=$(date -r "$session_file" +%Y-%m-%d 2>/dev/null || stat -c %y "$session_file" 2>/dev/null | cut -d' ' -f1)
        prompt=$(first_prompt "$session_file")
        if [[ -n "$prompt" ]]; then
            echo "- ${mod_date}: ${prompt}"
            count=$((count + 1))
        fi
    fi
done <<<"$session_files"

echo "---"
echo "Total: ${count} sessions"
