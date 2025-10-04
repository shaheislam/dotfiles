#!/usr/bin/env bash
# Clears activity completion notification

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-activity"
rm -f "$STATE_DIR/${SESSION}-${WINDOW}"*
