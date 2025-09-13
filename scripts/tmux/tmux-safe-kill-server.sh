#!/bin/bash

# Safe tmux kill-server that saves all sessions first
# This ensures both resurrect and trash systems capture the state

echo "Saving all tmux sessions before killing server..."

# Trigger a manual resurrect save
if [ -n "$TMUX" ]; then
    # If we're inside tmux, use the keybinding
    tmux send-keys C-Space C-s
    sleep 1
else
    # If outside tmux, run the save script directly
    if [ -x "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh" ]; then
        tmux run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
        sleep 1
    fi
fi

# Save each session to trash
for session in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do
    "$HOME/dotfiles/scripts/tmux-session-trash.sh" save "$session"
done

echo "All sessions saved. Killing tmux server..."
tmux kill-server

echo "✅ Tmux server killed. Sessions saved to:"
echo "  • Resurrect: Will auto-restore on next tmux start"
echo "  • Trash: Available via Ctrl-Space + T"