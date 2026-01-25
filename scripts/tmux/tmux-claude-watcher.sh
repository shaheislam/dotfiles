#!/usr/bin/env bash
# Daemon that watches for Claude windows needing input
# Shows indicator only when Claude becomes idle AFTER you last viewed the window
#
# Run with: tmux-claude-watcher.sh start
# Stop with: tmux-claude-watcher.sh stop

INDICATOR="🟢"
PID_FILE="/tmp/tmux-claude-watcher.pid"
STATE_DIR="/tmp/tmux-claude-state"
POLL_INTERVAL=3

start_daemon() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Watcher already running (PID $(cat "$PID_FILE"))"
        return 1
    fi

    mkdir -p "$STATE_DIR"

    (
        trap "rm -f '$PID_FILE'" EXIT

        while true; do
            check_claude_windows
            sleep "$POLL_INTERVAL"
        done
    ) &

    echo $! > "$PID_FILE"
    echo "Watcher started (PID $!)"
}

stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
        echo "Watcher stopped"
    else
        echo "Watcher not running"
    fi
}

check_claude_windows() {
    local active_window
    active_window=$(tmux display-message -p "#{window_index}" 2>/dev/null) || return

    for win_info in $(tmux list-windows -F "#{window_index}:#{window_name}" 2>/dev/null); do
        local win_idx="${win_info%%:*}"
        local win_name="${win_info#*:}"

        # Skip active window
        [[ "$win_idx" == "$active_window" ]] && continue

        # State files for this window
        local idle_file="$STATE_DIR/idle-$win_idx"
        local viewed_file="$STATE_DIR/viewed-$win_idx"
        local was_busy_file="$STATE_DIR/was-busy-$win_idx"

        # Check if window has Claude and if it's idle
        local claude_status
        claude_status=$(get_claude_status "$win_idx")

        if [[ "$claude_status" == "idle" ]]; then
            # Claude is idle - record when it became idle (if not already recorded)
            if [[ ! -f "$idle_file" ]]; then
                date +%s > "$idle_file"
            fi

            # Only show indicator if:
            # 1. Claude was busy at some point (we saw it working)
            # 2. Claude became idle AFTER user last viewed the window
            if [[ -f "$was_busy_file" ]]; then
                local idle_time=$(cat "$idle_file")
                local viewed_time=0
                [[ -f "$viewed_file" ]] && viewed_time=$(cat "$viewed_file")

                if (( idle_time > viewed_time )); then
                    # Add indicator if not present
                    if [[ "$win_name" != "${INDICATOR}"* ]]; then
                        # Store original name for restoration
                        echo "$win_name" > "$STATE_DIR/original-name-$win_idx"
                        tmux rename-window -t ":${win_idx}" "${INDICATOR} ${win_name}" 2>/dev/null
                    fi
                fi
            fi

        elif [[ "$claude_status" == "busy" ]]; then
            # Claude is busy - mark that we've seen it working
            touch "$was_busy_file"
            rm -f "$idle_file"  # Reset idle timestamp

            # Remove indicator if present (Claude is working now)
            if [[ "$win_name" == "${INDICATOR}"* ]]; then
                local clean_name="${win_name#${INDICATOR} }"
                tmux rename-window -t ":${win_idx}" "$clean_name" 2>/dev/null
            fi
        fi
    done
}

get_claude_status() {
    local win_idx="$1"

    for pane_idx in $(tmux list-panes -t ":${win_idx}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t ":${win_idx}.${pane_idx}" -p "#{pane_tty}" 2>/dev/null)
        [[ -z "$tty" ]] && continue

        local claude_pid
        claude_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E '/claude( |$)' | head -1 | awk '{print $1}')
        [[ -z "$claude_pid" ]] && continue

        # Found Claude - check if busy (has non-MCP children)
        for child_pid in $(pgrep -P "$claude_pid" 2>/dev/null); do
            local cmd
            cmd=$(ps -o args= -p "$child_pid" 2>/dev/null)
            if ! echo "$cmd" | grep -qE 'mcp|/private/tmp/bunx'; then
                echo "busy"
                return 0
            fi
        done

        # Claude exists but no active children = idle
        echo "idle"
        return 0
    done

    echo "none"  # No Claude in this window
}

# Called by tmux hook when user switches to a window
mark_viewed() {
    local win_idx="$1"
    mkdir -p "$STATE_DIR"
    date +%s > "$STATE_DIR/viewed-$win_idx"
    # Clear the was-busy flag so indicator won't show until Claude works again
    rm -f "$STATE_DIR/was-busy-$win_idx"
    rm -f "$STATE_DIR/idle-$win_idx"
}

case "${1:-}" in
    start) start_daemon ;;
    stop) stop_daemon ;;
    status)
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Running (PID $(cat "$PID_FILE"))"
        else
            echo "Not running"
        fi
        ;;
    mark-viewed) mark_viewed "$2" ;;
    *)
        echo "Usage: $0 {start|stop|status|mark-viewed <window>}"
        exit 1
        ;;
esac
