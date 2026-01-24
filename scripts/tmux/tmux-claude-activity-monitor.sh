#!/usr/bin/env bash
# Monitor Claude activity and highlight window when idle
# Triggered by alert-activity hook, then polls until Claude is idle
# Adds 🟢 indicator to window name when Claude has no active commands
# Indicator clears automatically when you switch to that window

SESSION="$1"
WINDOW="$2"

# Debug logging
echo "$(date '+%H:%M:%S') Called: session=$SESSION window=$WINDOW" >> /tmp/claude-monitor.log

# Skip if window 1 (that's typically where you're working, not Claude)
# This prevents false triggers from your main work window
# Remove this check if you want to monitor all Claude windows
# [[ "$WINDOW" == "1" ]] && exit 0

# Configuration
STATE_DIR="/tmp/tmux-claude-activity"
STATE_FILE="$STATE_DIR/${SESSION}-${WINDOW}.state"
LOCK_FILE="$STATE_DIR/${SESSION}-${WINDOW}.lock"
POLL_INTERVAL=3  # Seconds between checks
MAX_POLLS=20     # Max polls before giving up (60 seconds)

# Notification indicator
NEEDS_INPUT_INDICATOR="🟢"

# Create state directory
mkdir -p "$STATE_DIR"

# Find Claude pane in this window
find_claude_pane() {
    for pane in $(tmux list-panes -t "${SESSION}:${WINDOW}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t "${SESSION}:${WINDOW}.$pane" -p '#{pane_tty}' 2>/dev/null)
        if ps -o args= -t "$tty" 2>/dev/null | grep -q '/claude'; then
            echo "$pane"
            return 0
        fi
    done
    return 1
}

# Check if Claude is idle (no active non-MCP child processes)
is_claude_idle() {
    local pane="$1"
    local tty claude_pid

    tty=$(tmux display-message -t "${SESSION}:${WINDOW}.$pane" -p '#{pane_tty}' 2>/dev/null)
    [[ -z "$tty" ]] && return 0

    claude_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E '/claude( |$)' | head -1 | awk '{print $1}')
    [[ -z "$claude_pid" ]] && return 0

    # Check for non-MCP child processes
    local has_active=false
    for pid in $(pgrep -P "$claude_pid" 2>/dev/null); do
        local cmd
        cmd=$(ps -o args= -p "$pid" 2>/dev/null)
        if ! echo "$cmd" | grep -qE 'mcp|/private/tmp/bunx'; then
            has_active=true
            break
        fi
    done

    [[ "$has_active" == "false" ]]
}

# Exit if no Claude in this window
CLAUDE_PANE=$(find_claude_pane)
[[ -z "$CLAUDE_PANE" ]] && exit 0

# Update timestamp (activity detected)
echo "$(date +%s)" > "$STATE_FILE"

# Exit if already monitoring this window
[[ -f "$LOCK_FILE" ]] && exit 0

# Start background monitor
(
    echo $$ > "$LOCK_FILE"
    trap "rm -f '$LOCK_FILE'" EXIT

    polls=0
    while [[ $polls -lt $MAX_POLLS ]]; do
        sleep "$POLL_INTERVAL"
        ((polls++))

        # Stop if state file removed (manual clear)
        [[ ! -f "$STATE_FILE" ]] && exit 0

        # Stop if session/window gone
        tmux has-session -t "${SESSION}" 2>/dev/null || exit 0

        # Check if window is now active (user switched to it)
        active=$(tmux display-message -t "${SESSION}" -p "#{window_index}" 2>/dev/null)
        [[ "$active" == "$WINDOW" ]] && { rm -f "$STATE_FILE"; exit 0; }

        # Check if Claude is idle
        if is_claude_idle "$CLAUDE_PANE"; then
            # Add indicator if not present
            current_name=$(tmux display-message -t "${SESSION}:${WINDOW}" -p "#{window_name}" 2>/dev/null)
            if [[ "$current_name" != "${NEEDS_INPUT_INDICATOR}"* ]]; then
                tmux rename-window -t "${SESSION}:${WINDOW}" "${NEEDS_INPUT_INDICATOR} ${current_name}"
                tmux refresh-client -S
            fi
            rm -f "$STATE_FILE"
            exit 0
        fi
    done

    # Timed out - clean up
    rm -f "$STATE_FILE"
) &

exit 0
