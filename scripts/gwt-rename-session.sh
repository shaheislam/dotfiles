#!/usr/bin/env bash
# gwt-rename-session.sh - Deliver prompt and wait for completion
#
# Usage: gwt-rename-session.sh <pane_id> <window_name> [prompt_cmd_file]
#
# Waits for the TUI to be ready (❯ prompt), delivers the initial prompt
# command, then waits for the ralph-loop to complete.
#
# --name, --effort max, and --remote-control are CLI flags on the claude
# launch command — no post-launch send-keys needed for those.
#
# Text and Enter MUST be separate send-keys calls — ink's TUI batches
# combined calls and the Enter doesn't trigger submission.

set -euo pipefail

PANE_ID="${1:?Usage: gwt-rename-session.sh <pane_id> <window_name> [prompt_cmd_file]}"
# $2 (window_name) reserved for logging/future use; --name set via CLI flag at launch
PROMPT_CMD_FILE="${3:-}"

# Wait for Claude TUI to show the ❯ prompt indicator.
# Uses a sliding window: requires ❯ in at least $threshold out of
# the last $window checks. This tolerates brief TUI redraws that
# momentarily hide ❯ while still requiring sustained idle.
# $1 = max wait seconds, $2 = window size, $3 = threshold hits needed
wait_for_idle() {
    local max_wait="${1:-90}"
    local window="${2:-4}"
    local threshold="${3:-3}"
    local sleep_interval="${4:-1}"
    local wait_count=0

    # Ring buffer: 0=not idle, 1=idle
    local -a ring=()
    local hits=0

    while [ $wait_count -lt "$max_wait" ]; do
        local is_idle=0
        if tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
            is_idle=1
        fi

        # Evict oldest entry if ring is full
        if [ ${#ring[@]} -ge "$window" ]; then
            hits=$((hits - ring[0]))
            ring=("${ring[@]:1}")
        fi

        ring+=("$is_idle")
        hits=$((hits + is_idle))

        # Check threshold once window is full
        if [ ${#ring[@]} -ge "$window" ] && [ $hits -ge "$threshold" ]; then
            return 0
        fi

        sleep "$sleep_interval"
        wait_count=$((wait_count + 1))
    done
    return 1
}

# Initial startup: ❯ in 3 out of 4 checks (lenient, just needs to appear)
if ! wait_for_idle 90 4 3; then
    echo "Warning: Claude TUI did not become idle within 90s, skipping" >&2
    exit 0
fi

# Deliver prompt from file
if [ -n "$PROMPT_CMD_FILE" ] && [ -f "$PROMPT_CMD_FILE" ]; then
    PROMPT_CMD=$(<"$PROMPT_CMD_FILE")
    tmux send-keys -l -t "$PANE_ID" "$PROMPT_CMD"
    sleep 0.2
    tmux send-keys -t "$PANE_ID" Enter
fi

# Wait for agent to go busy (prompt accepted), then idle again (work done)
# First confirm the TUI left idle state (no ❯ for 5s means the agent is working)
busy_wait=0
while [ $busy_wait -lt 30 ]; do
    if ! tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
        break
    fi
    sleep 1
    busy_wait=$((busy_wait + 1))
done

# Now wait for the ralph-loop to finish (TUI returns to idle ❯)
# Long timeout — ralph-loop can run for hours.
# Require ❯ in 10 out of 12 checks (~83%). This avoids false triggers from
# brief inter-iteration pauses (1-3s = at most 3/12 = 25%) while tolerating
# occasional TUI redraws that briefly hide ❯ during true idle.
# Wait for ralph-loop to finish. --name and --remote-control set via CLI flags at launch.
wait_for_idle 14400 12 10 2
