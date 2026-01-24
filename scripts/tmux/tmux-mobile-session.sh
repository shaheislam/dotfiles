#!/usr/bin/env bash

# tmux-mobile-session.sh - Create a mobile-optimized tmux layout
#
# Layout:
# ┌─────────────────────────────────┐
# │          claude (main)          │  ← Primary pane (70% height)
# ├─────────────────────────────────┤
# │    editor    │      shell       │  ← Secondary panes (30% height)
# └─────────────────────────────────┘
#
# Usage:
#   tmux-mobile-session.sh [session-name]
#
# Behavior:
#   1. If any tmux session exists → attach to it (detaching other clients)
#   2. If no sessions exist → create new mobile-optimized layout
#
# Default session name (for new sessions): mobile

SESSION_NAME="${1:-mobile}"

# Check if ANY tmux session exists (not just the named one)
if tmux list-sessions 2>/dev/null | grep -q .; then
    # Get the most recent session name
    EXISTING_SESSION=$(tmux list-sessions -F "#{session_name}" | head -1)
    echo "Attaching to existing session '$EXISTING_SESSION'..."
    tmux attach-session -d -t "$EXISTING_SESSION"
    exit 0
fi

# No sessions exist - create new mobile-optimized layout
echo "No existing sessions. Creating mobile session '$SESSION_NAME'..."

# Create new session with main pane for Claude Code
tmux new-session -d -s "$SESSION_NAME" -n main

# Split horizontally (top 70%, bottom 30%)
tmux split-window -v -p 30

# Split the bottom pane vertically (left: editor, right: shell)
tmux split-window -h -p 50

# Select the top pane (claude)
tmux select-pane -t 0

# Send commands to each pane
# Top pane: Start claude
tmux send-keys -t 0 'claude' Enter

# Bottom-left pane: Ready for nvim
tmux send-keys -t 1 '# Editor pane - run: nvim' Enter

# Bottom-right pane: Shell prompt
tmux send-keys -t 2 '# Shell pane' Enter

# Attach to session
tmux attach-session -t "$SESSION_NAME"
