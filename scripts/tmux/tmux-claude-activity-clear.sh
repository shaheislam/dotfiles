#!/usr/bin/env bash
# Manually clear Claude activity highlighting

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-claude-activity"

# Remove state files
rm -f "$STATE_DIR/${SESSION}-${WINDOW}"*

# Reset window styling to default (unset custom options)
tmux set-window-option -t "${SESSION}:${WINDOW}" -u window-status-style 2>/dev/null
tmux set-window-option -t "${SESSION}:${WINDOW}" -u window-status-current-style 2>/dev/null
