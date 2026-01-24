#!/usr/bin/env bash
# Clears activity indicator and marks window as viewed

SESSION="$1"
WINDOW="$2"

INDICATOR="🟢"

# Remove indicator from window name if present
current_name=$(tmux display-message -t "${SESSION}:${WINDOW}" -p "#{window_name}" 2>/dev/null)
if [[ "$current_name" == "${INDICATOR} "* ]]; then
    new_name="${current_name#${INDICATOR} }"
    tmux rename-window -t "${SESSION}:${WINDOW}" "$new_name" 2>/dev/null
fi

# Mark window as viewed (tells watcher not to re-add indicator until Claude works again)
~/dotfiles/scripts/tmux/tmux-claude-watcher.sh mark-viewed "$WINDOW"

# Refresh status bar
tmux refresh-client -S 2>/dev/null
