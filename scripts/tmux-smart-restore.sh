#!/bin/bash

# Smart tmux launcher that restores sessions if needed
# Works with continuum auto-restore

# Check if tmux server is already running
if tmux has-session 2>/dev/null; then
    # Server is running, just attach to main or create it
    tmux new-session -A -s main
else
    # No server running - this is a fresh start
    echo "Starting tmux with session restoration..."
    
    # Start tmux server without attaching (allows auto-restore to run)
    tmux start-server
    
    # Give continuum time to auto-restore
    sleep 2
    
    # Check if any sessions were restored
    if tmux has-session 2>/dev/null; then
        # Sessions were restored! Check if main exists
        if tmux has-session -t main 2>/dev/null; then
            # Attach to main
            tmux attach -t main
        else
            # Attach to the first available session
            first_session=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)
            if [ -n "$first_session" ]; then
                tmux attach -t "$first_session"
            else
                # Shouldn't happen, but create main as fallback
                tmux new-session -s main
            fi
        fi
    else
        # No sessions were restored, create main
        tmux new-session -s main
    fi
fi