#!/usr/bin/env bash
# Clear Claude/Opencode activity highlighting (removes indicator from window name)

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-claude-activity"

# Get current window name and remove any indicator prefix
current_name=$(tmux display-message -t "${SESSION}:${WINDOW}" -p "#{window_name}" 2>/dev/null)

new_name="$current_name"
# Strip emoji indicators (combined first, then individual)
new_name="${new_name#🟢🔵 }"
new_name="${new_name#🟢 }"
new_name="${new_name#🔵 }"

if [[ "$current_name" != "$new_name" ]]; then
    tmux rename-window -t "${SESSION}:${WINDOW}" "$new_name" 2>/dev/null
fi

# Refresh status bar to show change immediately
tmux refresh-client -S 2>/dev/null

# Remove all state files for this window
rm -f "$STATE_DIR/${SESSION}-${WINDOW}"*
