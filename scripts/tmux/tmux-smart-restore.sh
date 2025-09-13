#!/bin/bash

# Smart tmux launcher that properly restores sessions
# Manually triggers resurrect restore since continuum auto-restore is unreliable

# Check if tmux server is already running
if tmux has-session 2>/dev/null; then
    # Server is running, just attach to main or create it
    tmux new-session -A -s main
else
    # No server running - fresh start, manually restore
    echo "Starting tmux with session restoration..."
    
    # Start a temporary session to run the restore
    tmux new-session -d -s temp-restore
    
    # Manually trigger resurrect restore
    tmux run-shell "$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
    
    # Give it a moment to restore
    sleep 1
    
    # Kill the temp session
    tmux kill-session -t temp-restore 2>/dev/null
    
    # Now attach to main or first available session
    if tmux has-session -t main 2>/dev/null; then
        tmux attach -t main
    else
        # Attach to first available session
        first_session=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)
        if [ -n "$first_session" ]; then
            tmux attach -t "$first_session"
        else
            # No sessions restored, create main
            tmux new-session -s main
        fi
    fi
fi