#!/usr/bin/env bash
# gwt-rename-session.sh - Rename Claude Code session to ticket/task name
#
# Usage: gwt-rename-session.sh <pane_id> <session_name>
#
# Prompt delivery is handled by the launch script (CLI argument),
# not by this script. This script only renames the session.

set -euo pipefail

PANE_ID="${1:?Usage: gwt-rename-session.sh <pane_id> <session_name>}"
SESSION_NAME="${2:?Missing session name}"

# Wait for Claude TUI to be fully idle (shows input prompt indicator).
# The ❯ character appears when Claude is initialized and ready for input,
# after all SessionStart hooks have completed.
wait_for_idle() {
    local max_wait="${1:-45}"
    local wait_count=0
    while [ $wait_count -lt "$max_wait" ]; do
        if tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
            return 0
        fi
        sleep 1
        wait_count=$((wait_count + 1))
    done
    return 1
}

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

# Wait for TUI to be fully initialized (hooks complete, input area ready)
if ! wait_for_idle 45; then
    echo "Warning: Claude TUI did not become idle within 45s, attempting anyway" >&2
fi

# Send /rename command (instant TUI command, no AI processing)
tmux send-keys -t "$PANE_ID" "/rename $SESSION_NAME" Enter
