#!/usr/bin/env bash
# Called when window changes - monitors the PREVIOUS window if it has Claude

SESSION="$1"
NEW_WINDOW="$2"

# Debug logging
echo "$(date '+%H:%M:%S') window-changed: session=$SESSION new_window=$NEW_WINDOW" >> /tmp/window-changed.log
STATE_DIR="/tmp/tmux-claude-activity"
PREV_FILE="$STATE_DIR/${SESSION}-previous"

mkdir -p "$STATE_DIR"

# Read previous window
PREV_WINDOW=""
[[ -f "$PREV_FILE" ]] && PREV_WINDOW=$(cat "$PREV_FILE")

# Save current as previous for next switch
echo "$NEW_WINDOW" > "$PREV_FILE"

# If we have a previous window and it's not the same as current, monitor it
if [[ -n "$PREV_WINDOW" ]] && [[ "$PREV_WINDOW" != "$NEW_WINDOW" ]]; then
    # Start monitoring the previous window (will only act if it has Claude)
    ~/dotfiles/scripts/tmux/tmux-claude-activity-monitor.sh "$SESSION" "$PREV_WINDOW" &
fi
