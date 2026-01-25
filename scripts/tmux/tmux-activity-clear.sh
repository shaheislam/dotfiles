#!/usr/bin/env bash
# Clears activity indicator and marks window as viewed

SESSION="$1"
WINDOW="$2"

INDICATOR="🟢"

# Remove indicator from window name if present
current_name=$(tmux display-message -t "${SESSION}:${WINDOW}" -p "#{window_name}" 2>/dev/null)
if [[ "$current_name" == "${INDICATOR}"* ]]; then
    # Try to restore original name from state file
    STATE_DIR="/tmp/tmux-claude-state"
    original_file="$STATE_DIR/original-name-$WINDOW"
    if [[ -f "$original_file" ]]; then
        new_name=$(cat "$original_file")
        rm -f "$original_file"
    else
        # Fallback: strip indicator
        new_name="${current_name#${INDICATOR}}"
        new_name="${new_name# }"
        [[ -z "$new_name" ]] && new_name="claude"
    fi
    tmux rename-window -t "${SESSION}:${WINDOW}" "$new_name" 2>/dev/null
fi

# Mark window as viewed (tells watcher not to re-add indicator until Claude works again)
~/dotfiles/scripts/tmux/tmux-claude-watcher.sh mark-viewed "$WINDOW"

# Refresh status bar
tmux refresh-client -S 2>/dev/null
