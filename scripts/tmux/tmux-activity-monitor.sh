#!/usr/bin/env bash
# Monitors for activity completion (activity followed by 10s of silence)
# Optimized with debouncing to prevent spawning duplicate background monitors

SESSION="$1"
WINDOW="$2"
SILENCE_PERIOD=10

STATE_DIR="/tmp/tmux-activity"
STATE_FILE="$STATE_DIR/${SESSION}-${WINDOW}"
LOCK_FILE="${STATE_FILE}.lock"

mkdir -p "$STATE_DIR"

# Track that activity occurred (always update timestamp)
echo "$(date +%s)" > "$STATE_FILE"

# Debounce: Skip if a monitor is already running for this window
# This prevents spawning hundreds of background processes during rapid activity
[[ -f "$LOCK_FILE" ]] && exit 0

# Create lock file to indicate monitor is running
touch "$LOCK_FILE"

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

      # Send system notification ONLY if this is NOT the current window
      # (Prevents notification spam when activity-action is set to 'any')
      CURRENT_WINDOW=$(tmux display-message -p '#I')
      if [[ "$WINDOW" != "$CURRENT_WINDOW" ]]; then
        tmux display-message "Activity completed in window ${WINDOW}"
      fi
    fi
  fi

  # Clean up lock file when monitor completes
  rm -f "$LOCK_FILE"
) &
