#!/usr/bin/env bash
# Monitors for activity completion (activity followed by 10s of silence)

SESSION="$1"
WINDOW="$2"
SILENCE_PERIOD=10

STATE_DIR="/tmp/tmux-activity"
STATE_FILE="$STATE_DIR/${SESSION}-${WINDOW}"

mkdir -p "$STATE_DIR"

# Track that activity occurred
echo "$(date +%s)" > "$STATE_FILE"

# Background process to check for silence after 10 seconds
(
  sleep "$SILENCE_PERIOD"

  # Check if file still exists and hasn't been updated
  if [[ -f "$STATE_FILE" ]]; then
    LAST_ACTIVITY=$(cat "$STATE_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_ACTIVITY))

    # If 10+ seconds have passed since last activity, mark as complete
    if [[ $TIME_DIFF -ge $SILENCE_PERIOD ]]; then
      echo "complete" > "${STATE_FILE}.complete"

      # Send system notification
      tmux display-message "Activity completed in window ${WINDOW}"
    fi
  fi
) &
