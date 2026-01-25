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

        # Track if we've already notified for this idle period
        local notified_file="$STATE_DIR/notified-$win_idx"

        if [[ "$claude_status" == "idle" ]]; then
            # Record when Claude became idle (only on transition from busy/none)
            if [[ ! -f "$idle_file" ]]; then
                date +%s > "$idle_file"
            fi

            # Show indicator if:
            # 1. Not already notified for this idle period
            # 2. Claude became idle AFTER user last viewed the window
            if [[ ! -f "$notified_file" ]]; then
                local idle_time=$(cat "$idle_file")
                local viewed_time=0
                [[ -f "$viewed_file" ]] && viewed_time=$(cat "$viewed_file")

                if (( idle_time > viewed_time )); then
                    # Add indicator if not present
                    if [[ "$win_name" != "${INDICATOR}"* ]]; then
                        echo "$win_name" > "$STATE_DIR/original-name-$win_idx"
                        tmux rename-window -t ":${win_idx}" "${INDICATOR} ${win_name}" 2>/dev/null
                    fi
                    touch "$notified_file"
                fi
            fi

        elif [[ "$claude_status" == "busy" ]]; then
            # Claude is working - reset idle tracking for next idle period
            rm -f "$idle_file"
            rm -f "$notified_file"

            # Remove indicator if present (Claude is working now)
            if [[ "$win_name" == "${INDICATOR}"* ]]; then
                local clean_name="${win_name#${INDICATOR} }"
                tmux rename-window -t ":${win_idx}" "$clean_name" 2>/dev/null
            fi
        fi
    done
}

# Find devcontainer instance name for a tmux window
# Uses window name to guess the instance pattern
find_devcontainer_for_window() {
    local win_idx="$1"
    local win_name
    win_name=$(tmux display-message -t ":${win_idx}" -p "#{window_name}" 2>/dev/null)

    # Strip any indicator prefix
    win_name="${win_name#${INDICATOR} }"

    # Look for running container matching the window name
    # devcontainer instances are named like "repo-branch"
    # Window names are like "branch" or "feature-branch"
    local container
    container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "[-_]${win_name}$" | head -1)

    if [[ -n "$container" ]]; then
        echo "$container"
        return 0
    fi

    return 1
}

# Check if Claude is idle inside a container
get_claude_status_in_container() {
    local container="$1"

    # Find Claude process in container
    local claude_pid
    claude_pid=$(docker exec "$container" pgrep -f '/claude( |$)' 2>/dev/null | head -1)

    [[ -z "$claude_pid" ]] && { echo "none"; return 0; }

    # Check for non-MCP children (indicates busy)
    local children
    children=$(docker exec "$container" sh -c "pgrep -P $claude_pid 2>/dev/null" 2>/dev/null)

    for child_pid in $children; do
        local cmd
        cmd=$(docker exec "$container" ps -o args= -p "$child_pid" 2>/dev/null)
        if ! echo "$cmd" | grep -qE 'mcp|bunx'; then
            echo "busy"
            return 0
        fi
    done

    echo "idle"
}

get_claude_status() {
    local win_idx="$1"

    # First: try local detection (existing logic)
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

    # Second: check for devcontainer
    if command -v docker >/dev/null 2>&1; then
        local container
        container=$(find_devcontainer_for_window "$win_idx")
        if [[ -n "$container" ]]; then
            get_claude_status_in_container "$container"
            return 0
        fi
    fi

    echo "none"  # No Claude in this window
}

# Called by tmux hook when user switches to a window
mark_viewed() {
    local win_idx="$1"
    mkdir -p "$STATE_DIR"
    date +%s > "$STATE_DIR/viewed-$win_idx"
    # Clear notification flag - indicator won't re-show unless Claude works and becomes idle again
    # Keep idle_file so timestamp comparison works correctly
    rm -f "$STATE_DIR/notified-$win_idx"
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
