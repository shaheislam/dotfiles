#!/usr/bin/env bash
# gwt-rename-session.sh - Rename Claude Code session to ticket/task name
#
# Usage: gwt-rename-session.sh <pane_id> <session_name> <prompt_cmd_file>

set -euo pipefail

PANE_ID="${1:?Usage: gwt-rename-session.sh <pane_id> <session_name> <prompt_cmd_file>}"
SESSION_NAME="${2:?Missing session name}"
PROMPT_CMD_FILE="${3:?Missing prompt command file}"

if [ ! -f "$PROMPT_CMD_FILE" ]; then
    echo "Error: prompt command file not found: $PROMPT_CMD_FILE" >&2
    exit 1
fi

# Wait for Claude to be the foreground process (up to 60 seconds)
attempts=0
while [ $attempts -lt 60 ]; do
    pcmd=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_command}' 2>/dev/null || true)
    if [[ "$pcmd" == "claude" ]] || [[ "$pcmd" == "node" ]]; then
        break
    fi
    sleep 1
    attempts=$((attempts + 1))
done

if [ $attempts -ge 60 ]; then
    echo "Warning: Claude did not start within 60s, skipping session rename" >&2
    exit 0
fi

# Extra wait for TUI initialization
sleep 2

# Send /rename command (instant TUI command, no AI processing)
tmux send-keys -t "$PANE_ID" "/rename $SESSION_NAME" Enter

# Wait for rename to complete before delivering prompt
sleep 1

# Deliver the task prompt via tmux paste-buffer
# -p enables bracketed paste mode so newlines don't trigger premature submission
tmux load-buffer -b gwt-prompt "$PROMPT_CMD_FILE"
tmux paste-buffer -t "$PANE_ID" -b gwt-prompt -p -d 2>/dev/null || {
    # Fallback: older tmux without -p (bracketed paste)
    tmux load-buffer -b gwt-prompt "$PROMPT_CMD_FILE"
    tmux paste-buffer -t "$PANE_ID" -b gwt-prompt -d
}

# Submit the prompt
tmux send-keys -t "$PANE_ID" Enter
