#!/usr/bin/env bash
# gwt-rename-session.sh - Deliver prompt and rename Claude session
#
# Usage: gwt-rename-session.sh <pane_id> <session_name> [prompt_cmd_file]
#
# Sequence: wait for TUI → deliver prompt → wait for session file → /rename
# Prompt goes first because /rename needs the session JSONL file,
# which is created when the first prompt is processed.
#
# Text and Enter MUST be separate send-keys calls — ink's TUI batches
# combined calls and the Enter doesn't trigger submission.

set -euo pipefail

PANE_ID="${1:?Usage: gwt-rename-session.sh <pane_id> <session_name> [prompt_cmd_file]}"
SESSION_NAME="${2:?Missing session name}"
PROMPT_CMD_FILE="${3:-}"

# Wait for Claude TUI to show the ❯ prompt indicator (fully initialized,
# all SessionStart hooks complete, ready for input).
wait_for_idle() {
    local max_wait="${1:-90}"
    local wait_count=0
    local consecutive=0
    while [ $wait_count -lt "$max_wait" ]; do
        if tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
            consecutive=$((consecutive + 1))
            if [ $consecutive -ge 2 ]; then
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

if ! wait_for_idle 90; then
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

# Step 2: Wait for session file to be created, then rename
# The JSONL file is created when the first prompt is processed.
# /rename needs this file to exist (otherwise ENOENT).
sleep 5
tmux send-keys -l -t "$PANE_ID" "/rename $SESSION_NAME"
sleep 0.2
tmux send-keys -t "$PANE_ID" Enter
