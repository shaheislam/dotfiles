#!/usr/bin/env bash
# Clear Claude activity highlighting (removes indicator from window name)

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-claude-activity"
NEEDS_INPUT_INDICATOR="🟢"

# Get current window name and remove indicator if present
current_name=$(tmux display-message -t "${SESSION}:${WINDOW}" -p "#{window_name}" 2>/dev/null)
if [[ "$current_name" == "${NEEDS_INPUT_INDICATOR} "* ]]; then
    # Remove the indicator prefix (emoji + space)
    new_name="${current_name#${NEEDS_INPUT_INDICATOR} }"
    tmux rename-window -t "${SESSION}:${WINDOW}" "$new_name" 2>/dev/null
fi

# Refresh status bar to show change immediately
tmux refresh-client -S 2>/dev/null

# Remove all state files for this window
rm -f "$STATE_DIR/${SESSION}-${WINDOW}"*
