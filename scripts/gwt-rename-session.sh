#!/usr/bin/env bash
# gwt-rename-session.sh - Deliver prompt and rename session on completion
#
# Usage: gwt-rename-session.sh <pane_id> <window_name> [prompt_cmd_file] [prompt_meta_file]
#
# Waits for the TUI to be ready (❯ prompt), names the session via /rename,
# enables Remote Control (/rc) so the session is accessible from phone/web,
# delivers the initial prompt command, then waits for the ralph-loop to complete.
#
# When prompt_meta_file is provided (--edit mode), waits for the user to save
# prompt.local.md in nvim before constructing and delivering the command.
#
# Text and Enter MUST be separate send-keys calls — ink's TUI batches
# combined calls and the Enter doesn't trigger submission.

set -euo pipefail

PANE_ID="${1:?Usage: gwt-rename-session.sh <pane_id> <session_name> [prompt_cmd_file] [prompt_meta_file]}"
WINDOW_NAME="${2:?Missing session name}"
PROMPT_CMD_FILE="${3:-}"
PROMPT_META="${4:-}"

# Wait for Claude TUI to show the ❯ prompt indicator.
# Uses a sliding window: requires ❯ in at least $threshold out of
# the last $window checks. This tolerates brief TUI redraws that
# momentarily hide ❯ while still requiring sustained idle.
# $1 = max wait seconds, $2 = window size, $3 = threshold hits needed
wait_for_idle() {
    local max_wait="${1:-90}"
    local window="${2:-4}"
    local threshold="${3:-3}"
    local sleep_interval="${4:-1}"
    local wait_count=0

    # Ring buffer: 0=not idle, 1=idle
    local -a ring=()
    local hits=0

    while [ $wait_count -lt "$max_wait" ]; do
        local is_idle=0
        if tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
            is_idle=1
        fi

        # Evict oldest entry if ring is full
        if [ ${#ring[@]} -ge "$window" ]; then
            hits=$((hits - ring[0]))
            ring=("${ring[@]:1}")
        fi

        ring+=("$is_idle")
        hits=$((hits + is_idle))

        # Check threshold once window is full
        if [ ${#ring[@]} -ge "$window" ] && [ $hits -ge "$threshold" ]; then
            return 0
        fi

        sleep "$sleep_interval"
        wait_count=$((wait_count + 1))
    done
    return 1
}

# Initial startup: ❯ in 3 out of 4 checks (lenient, just needs to appear)
if ! wait_for_idle 90 4 3; then
    echo "Warning: Claude TUI did not become idle within 90s, skipping" >&2
    exit 0
fi

# Step 0a: Name the session before anything else, so /rc and phone show the right name.
tmux send-keys -l -t "$PANE_ID" "/rename $WINDOW_NAME"
sleep 0.2
tmux send-keys -t "$PANE_ID" Enter

if ! wait_for_idle 10 4 3; then
    echo "Warning: /rename did not return to idle within 10s, continuing" >&2
fi

# Step 0b: Enable Remote Control so session is accessible from phone/web.
# /rc registers with the Anthropic API (~1-3s) and returns to ❯.
# If it fails (auth, plan limits), we continue — prompt delivery is critical.
tmux send-keys -l -t "$PANE_ID" "/rc"
sleep 0.2
tmux send-keys -t "$PANE_ID" Enter

# 15s timeout, 3/4 threshold — same leniency as initial startup.
# /rc typically completes in 1-3s; 15s covers slow network.
if ! wait_for_idle 15 4 3; then
    echo "Warning: /rc did not return to idle within 15s, continuing" >&2
fi

# Step 1: Deliver prompt
if [ -n "$PROMPT_META" ] && [ -f "$PROMPT_META" ]; then
    # --- Interactive mode (--edit): wait for user to save prompt.local.md ---
    # shellcheck source=/dev/null
    source "$PROMPT_META"
    # SLASH_COMMAND, MAX_ITERATIONS, COMPLETION_PROMISE, PROMPT_FILE now set

    initial_mtime=$(stat -f %m "$PROMPT_FILE" 2>/dev/null || stat -c %Y "$PROMPT_FILE")
    echo "edit-mode: waiting for prompt save in nvim..." >&2

    # Poll until file is modified and stable for 5s (debounce rapid saves)
    max_edit_wait=3600  # 1 hour max
    edit_wait=0
    while [ $edit_wait -lt $max_edit_wait ]; do
        sleep 2
        edit_wait=$((edit_wait + 2))
        current_mtime=$(stat -f %m "$PROMPT_FILE" 2>/dev/null || stat -c %Y "$PROMPT_FILE")
        if [ "$current_mtime" != "$initial_mtime" ]; then
            # File was modified — debounce: wait 5s then check stability
            sleep 5
            final_mtime=$(stat -f %m "$PROMPT_FILE" 2>/dev/null || stat -c %Y "$PROMPT_FILE")
            if [ "$final_mtime" = "$current_mtime" ]; then
                # Stable — user is done editing
                break
            fi
            # Still changing, update baseline and keep waiting
            initial_mtime="$final_mtime"
        fi
    done

    if [ $edit_wait -ge $max_edit_wait ]; then
        echo "Warning: edit mode timed out after 1h, skipping prompt delivery" >&2
    else
        echo "edit-mode: prompt saved, delivering to Claude..." >&2
        # Read prompt, collapse newlines, escape quotes
        PROMPT_TEXT=$(<"$PROMPT_FILE")
        PROMPT_TEXT=$(printf '%s' "$PROMPT_TEXT" | tr '\n' ' ')
        # Escape backslashes then double quotes
        PROMPT_TEXT="${PROMPT_TEXT//\\/\\\\}"
        PROMPT_TEXT="${PROMPT_TEXT//\"/\\\"}"

        if [[ "$SLASH_COMMAND" == *"ralph-wiggum:ralph-loop"* ]]; then
            PROMPT_CMD="$SLASH_COMMAND \"$PROMPT_TEXT\" --max-iterations $MAX_ITERATIONS --completion-promise $COMPLETION_PROMISE"
        else
            PROMPT_CMD="$SLASH_COMMAND \"$PROMPT_TEXT\""
        fi

        tmux send-keys -l -t "$PANE_ID" "$PROMPT_CMD"
        sleep 0.2
        tmux send-keys -t "$PANE_ID" Enter
    fi
elif [ -n "$PROMPT_CMD_FILE" ] && [ -f "$PROMPT_CMD_FILE" ]; then
    # --- Normal mode: send pre-built command from file ---
    PROMPT_CMD=$(<"$PROMPT_CMD_FILE")
    tmux send-keys -l -t "$PANE_ID" "$PROMPT_CMD"
    sleep 0.2
    tmux send-keys -t "$PANE_ID" Enter
fi

# Step 2: Wait for agent to go busy (prompt accepted), then idle again (work done)
# First confirm the TUI left idle state (no ❯ for 5s means the agent is working)
busy_wait=0
while [ $busy_wait -lt 30 ]; do
    if ! tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -qF '❯'; then
        break
    fi
    sleep 1
    busy_wait=$((busy_wait + 1))
done

# Now wait for the ralph-loop to finish (TUI returns to idle ❯)
# Long timeout — ralph-loop can run for hours.
# Require ❯ in 10 out of 12 checks (~83%). This avoids false triggers from
# brief inter-iteration pauses (1-3s = at most 3/12 = 25%) while tolerating
# occasional TUI redraws that briefly hide ❯ during true idle.
# Wait for ralph-loop to finish. /rename was already sent in Step 0a.
wait_for_idle 14400 12 10 2
