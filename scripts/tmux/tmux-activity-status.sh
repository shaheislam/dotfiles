#!/usr/bin/env bash
# Shows 🔔 if activity has completed

SESSION="$1"
WINDOW="$2"

STATE_DIR="/tmp/tmux-activity"
COMPLETE_FILE="$STATE_DIR/${SESSION}-${WINDOW}.complete"

if [[ -f "$COMPLETE_FILE" ]]; then
  echo " 🔔"
fi
