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
# Default session name: mobile

SESSION_NAME="${1:-mobile}"

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

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
