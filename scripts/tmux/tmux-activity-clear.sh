#!/usr/bin/env bash
# Clears activity completion notification and lock files

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-activity"
# Remove state file, completion marker, and lock file
rm -f "$STATE_DIR/${SESSION}-${WINDOW}"*
