#!/usr/bin/env bash
#
# should-dream.sh - Check if dream consolidation should run
#
# Returns exit code 0 if dream should run, 1 if not.
# Triggers when EITHER condition is met:
#   - minHours elapsed since last consolidation
#   - minSessions occurred since last consolidation
#
# Reads config from ~/.claude/skills/dream/.dream-config

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SKILL_DIR/.dream-config"

# Read config with defaults
read_config() {
    local key="$1" default="$2"
    if [[ -f "$CONFIG" ]]; then
        grep "^${key}=" "$CONFIG" 2>/dev/null | cut -d= -f2 || echo "$default"
    else
        echo "$default"
    fi
}

DREAM_MEMORY_TYPE=$(read_config "DREAM_MEMORY_TYPE" "native")
DREAM_MIN_HOURS=$(read_config "DREAM_MIN_HOURS" "24")
DREAM_MIN_SESSIONS=$(read_config "DREAM_MIN_SESSIONS" "5")

# Find the .last-dream timestamp based on memory type
find_last_dream() {
    case "$DREAM_MEMORY_TYPE" in
    native)
        for dir in "$HOME/.claude/projects/"*/memory/; do
            if [[ -f "$dir/.last-dream" ]]; then
                echo "$dir/.last-dream"
                return 0
            fi
        done
        return 1 # No .last-dream found
        ;;
    openclaw | project-root)
        local mem_path
        mem_path=$(read_config "DREAM_MEMORY_PATH" ".")
        mem_path="${mem_path/#\~/$HOME}"
        if [[ -f "$mem_path/.last-dream" ]]; then
            echo "$mem_path/.last-dream"
            return 0
        fi
        return 1
        ;;
    esac
}

# Check session count since last dream
SESSION_COUNT_FILE="$SKILL_DIR/.session-count"

check_session_threshold() {
    if [[ "$DREAM_MIN_SESSIONS" -eq 0 ]]; then
        return 1 # Session trigger disabled
    fi
    if [[ ! -f "$SESSION_COUNT_FILE" ]]; then
        return 1 # No session count yet
    fi
    local count
    count=$(cat "$SESSION_COUNT_FILE" 2>/dev/null || echo "0")
    if [[ "$count" -ge "$DREAM_MIN_SESSIONS" ]]; then
        echo "Dream conditions met: ${count} sessions since last dream (threshold: ${DREAM_MIN_SESSIONS})"
        return 0
    fi
    return 1
}

# Check time threshold
check_time_threshold() {
    if [[ "$DREAM_MIN_HOURS" -eq 0 ]]; then
        return 1 # Time trigger disabled
    fi
    local last_dream_file
    if ! last_dream_file=$(find_last_dream); then
        echo "Dream conditions met: first-run (no .last-dream found)"
        return 0
    fi
    local last_dream now elapsed hours_elapsed
    last_dream=$(cat "$last_dream_file")
    now=$(date +%s)
    elapsed=$((now - last_dream))
    hours_elapsed=$((elapsed / 3600))

    if [[ "$hours_elapsed" -ge "$DREAM_MIN_HOURS" ]]; then
        echo "Dream conditions met: ${hours_elapsed}h since last dream (threshold: ${DREAM_MIN_HOURS}h)"
        return 0
    fi
    return 1
}

# Dream runs when EITHER condition is met
# First-run always triggers
if ! find_last_dream >/dev/null 2>&1; then
    echo "Dream conditions met: first-run (no .last-dream found)"
    exit 0
fi

if check_time_threshold; then
    exit 0
fi

if check_session_threshold; then
    exit 0
fi

exit 1 # Neither condition met
