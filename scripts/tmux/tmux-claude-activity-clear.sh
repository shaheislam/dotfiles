#!/usr/bin/env bash
# Manually clear Claude activity highlighting

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-claude-activity"

# Remove state files
rm -f "$STATE_DIR/${SESSION}-${WINDOW}"*

# Reset pane border styling to default (unset custom options)
tmux set-window-option -t "${SESSION}:${WINDOW}" -u pane-border-style 2>/dev/null
tmux set-window-option -t "${SESSION}:${WINDOW}" -u pane-active-border-style 2>/dev/null
