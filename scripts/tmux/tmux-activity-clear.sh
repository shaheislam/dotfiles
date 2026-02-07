#!/usr/bin/env bash
# Clears activity indicator and marks window as viewed

SESSION="$1"
WINDOW="$2"

# Remove any indicator prefix from window name (current, legacy emoji, legacy text)
current_name=$(tmux display-message -t "${SESSION}:${WINDOW}" -p "#{window_name}" 2>/dev/null)

new_name="$current_name"
# Strip current indicators (●/◆)
new_name="${new_name#●◆ }"
new_name="${new_name#● }"
new_name="${new_name#◆ }"
# Strip legacy emoji indicators (🟢/🔵)
new_name="${new_name#🟢🔵 }"
new_name="${new_name#🟢 }"
new_name="${new_name#🔵 }"
# Strip legacy text indicators (*, +, *+)
new_name="${new_name#\*+ }"
new_name="${new_name#\* }"
new_name="${new_name#+ }"

if [[ "$current_name" != "$new_name" ]]; then
    [[ -z "$new_name" ]] && new_name="shell"
    tmux rename-window -t "${SESSION}:${WINDOW}" "$new_name" 2>/dev/null
fi

# Mark window as viewed (tells watcher not to re-add indicator until Claude works again)
~/dotfiles/scripts/tmux/tmux-claude-watcher.sh mark-viewed "$WINDOW"

# Refresh status bar
tmux refresh-client -S 2>/dev/null
