#!/usr/bin/env bash
# gwt-rename-session.sh - Deliver prompt and rename session on completion
#
# Usage: gwt-rename-session.sh <pane_id> <window_name> [prompt_cmd_file]
#
# Waits for the TUI to be ready (❯ prompt), delivers the initial prompt
# command, then waits for the ralph-loop to complete and sends /rename
# so the Claude session is named after the tmux window (ticket key or slug).
#
# Text and Enter MUST be separate send-keys calls — ink's TUI batches
# combined calls and the Enter doesn't trigger submission.

set -euo pipefail

PANE_ID="${1:?Usage: gwt-rename-session.sh <pane_id> <session_name> [prompt_cmd_file]}"
WINDOW_NAME="${2:?Missing session name}"
PROMPT_CMD_FILE="${3:-}"

# Wait for Claude TUI to show the ❯ prompt indicator (fully initialized,
# all SessionStart hooks complete, ready for input).
# $1 = max wait seconds, $2 = required consecutive idle seconds (default: 2)
wait_for_idle() {
    local max_wait="${1:-90}"
    local required="${2:-2}"
    local wait_count=0
    local consecutive=0
    while [ $wait_count -lt "$max_wait" ]; do
        if tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
            consecutive=$((consecutive + 1))
            if [ $consecutive -ge "$required" ]; then
                return 0
            fi
        else
            consecutive=0
        fi
        sleep 1
        wait_count=$((wait_count + 1))
    done
    return 1
}

if ! wait_for_idle 90 2; then
    echo "Warning: Claude TUI did not become idle within 90s, skipping" >&2
    exit 0
fi

# Extra stabilization
sleep 1

# Step 1: Deliver prompt (this creates the session JSONL file)
if [ -n "$PROMPT_CMD_FILE" ] && [ -f "$PROMPT_CMD_FILE" ]; then
    PROMPT_CMD=$(cat "$PROMPT_CMD_FILE")
    tmux send-keys -l -t "$PANE_ID" "$PROMPT_CMD"
    sleep 0.2
    tmux send-keys -t "$PANE_ID" Enter
fi

# Step 2: Wait for agent to go busy (prompt accepted), then idle again (work done)
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
# Require 15 consecutive seconds of idle to avoid false triggers from brief
# pauses between ralph-loop iterations or during context compaction.
if wait_for_idle 14400 15; then
    sleep 1
    tmux send-keys -l -t "$PANE_ID" "/rename $WINDOW_NAME"
    sleep 0.2
    tmux send-keys -t "$PANE_ID" Enter
fi
