#!/usr/bin/env bash
# Monitor Claude activity and highlight window visually
# Highlights window when Claude is actively outputting text
# Auto-clears after 5 seconds of silence

SESSION="$1"
WINDOW="$2"

# Configuration
STATE_DIR="/tmp/tmux-claude-activity"
STATE_FILE="$STATE_DIR/${SESSION}-${WINDOW}"
LOCK_FILE="${STATE_FILE}.lock"
SILENCE_PERIOD=5  # Seconds of silence before clearing highlight

# Create state directory
mkdir -p "$STATE_DIR"

# Check if Claude is running in this window
# Checks all panes in the window for a process containing 'claude'
if ! tmux list-panes -t "${SESSION}:${WINDOW}" -F "#{pane_tty}" 2>/dev/null | while read tty; do
    ps -o args= -t "$tty" 2>/dev/null | grep -q 'claude' && exit 0
done; then
    exit 0  # Not a Claude window, skip monitoring
fi

# Update activity timestamp
echo "$(date +%s)" > "$STATE_FILE"

# Highlight pane borders when Claude is active - Tokyo Night Storm bright blue/purple
# Inactive pane borders: bright blue (#7aa2f7)
# Active pane border: bright purple (#bb9af7)
tmux set-window-option -t "${SESSION}:${WINDOW}" pane-border-style "fg=#7aa2f7,bold" 2>/dev/null
tmux set-window-option -t "${SESSION}:${WINDOW}" pane-active-border-style "fg=#bb9af7,bold" 2>/dev/null

# Debouncing: exit if monitor already running
[[ -f "$LOCK_FILE" ]] && exit 0

# Spawn background silence detector
(
    touch "$LOCK_FILE"
    trap "rm -f '$LOCK_FILE'" EXIT

    sleep "$SILENCE_PERIOD"

    # Check if activity is still ongoing
    if [[ -f "$STATE_FILE" ]]; then
        LAST_ACTIVITY=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - LAST_ACTIVITY))

        if [[ $TIME_DIFF -ge $SILENCE_PERIOD ]]; then
            # Silence detected - clear pane border highlights and restore default styling
            tmux set-window-option -t "${SESSION}:${WINDOW}" -u pane-border-style 2>/dev/null
            tmux set-window-option -t "${SESSION}:${WINDOW}" -u pane-active-border-style 2>/dev/null
            rm -f "$STATE_FILE"
        fi
    fi

    rm -f "$LOCK_FILE"
) &
