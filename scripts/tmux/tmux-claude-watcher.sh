#!/usr/bin/env bash
# Daemon that watches for Claude and Opencode windows needing input
# Shows indicators only when tools have done work since you last viewed the window
#
# Indicators:
#   🟢 = Claude is idle and has worked since last view
#   🔵 = Opencode is idle and has worked since last view
#   🟢🔵 = Both are idle in the same window
#
# State machine (flag-based, not timestamp-based):
# - When tool is BUSY: Set "worked" flag, remove its indicator
# - When tool is IDLE: Show indicator only if "worked" flag exists and not already notified
# - When user VIEWS: Clear all flags, remove all indicators immediately
#
# Run with: tmux-claude-watcher.sh start
# Stop with: tmux-claude-watcher.sh stop

CLAUDE_INDICATOR="🟢"
OPENCODE_INDICATOR="🔵"
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
            check_all_windows
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

# Strip all known indicators from window name
get_clean_window_name() {
    local win_name="$1"
    # Strip combined indicator first (with space)
    win_name="${win_name#${CLAUDE_INDICATOR}${OPENCODE_INDICATOR} }"
    # Strip individual indicators (with space)
    win_name="${win_name#${CLAUDE_INDICATOR} }"
    win_name="${win_name#${OPENCODE_INDICATOR} }"
    # Strip indicators without space (edge case)
    win_name="${win_name#${CLAUDE_INDICATOR}${OPENCODE_INDICATOR}}"
    win_name="${win_name#${CLAUDE_INDICATOR}}"
    win_name="${win_name#${OPENCODE_INDICATOR}}"
    echo "$win_name"
}

# Centralized function to update window indicators based on state files
update_window_indicators() {
    local win_idx="$1"
    local current_name
    current_name=$(tmux display-message -t ":${win_idx}" -p "#{window_name}" 2>/dev/null) || return

    local clean_name
    clean_name=$(get_clean_window_name "$current_name")

    local prefix=""

    # Build prefix from notification state (consistent order: Claude first)
    [[ -f "$STATE_DIR/claude-notified-$win_idx" ]] && prefix+="$CLAUDE_INDICATOR"
    [[ -f "$STATE_DIR/opencode-notified-$win_idx" ]] && prefix+="$OPENCODE_INDICATOR"

    local new_name
    if [[ -n "$prefix" ]]; then
        new_name="${prefix} ${clean_name}"
    else
        new_name="$clean_name"
    fi

    # Only rename if changed (avoid unnecessary tmux operations)
    if [[ "$current_name" != "$new_name" ]]; then
        tmux rename-window -t ":${win_idx}" "$new_name" 2>/dev/null
    fi
}

check_all_windows() {
    local active_window
    active_window=$(tmux display-message -p "#{window_index}" 2>/dev/null) || return

    for win_info in $(tmux list-windows -F "#{window_index}:#{window_name}" 2>/dev/null); do
        local win_idx="${win_info%%:*}"

        # Skip active window
        [[ "$win_idx" == "$active_window" ]] && continue

        # Process each tool independently
        # Claude: matches /opt/homebrew/bin/claude (full path)
        # Opencode: matches "opencode" (appears without path in ps, preceded by space)
        process_tool_state "$win_idx" "claude" '/claude( |$)'
        process_tool_state "$win_idx" "opencode" '(^| |/)opencode( |$)'
    done
}

# Process state machine for a single tool in a window
process_tool_state() {
    local win_idx="$1"
    local tool="$2"
    local pattern="$3"

    local worked_file="$STATE_DIR/${tool}-worked-$win_idx"
    local notified_file="$STATE_DIR/${tool}-notified-$win_idx"

    local status
    status=$(get_tool_status "$win_idx" "$tool" "$pattern")

    if [[ "$status" == "busy" ]]; then
        # Mark that tool has done work since last view
        touch "$worked_file"
        # Remove notification (tool is actively working)
        if [[ -f "$notified_file" ]]; then
            rm -f "$notified_file"
            update_window_indicators "$win_idx"
        fi

    elif [[ "$status" == "idle" ]]; then
        # Show indicator if:
        # 1. Not already notified
        # 2. Tool has worked since user last viewed
        if [[ ! -f "$notified_file" ]] && [[ -f "$worked_file" ]]; then
            touch "$notified_file"
            update_window_indicators "$win_idx"
        fi
    fi
    # If status is "none", do nothing
}

# Generic tool status detection
get_tool_status() {
    local win_idx="$1"
    local tool="$2"
    local pattern="$3"

    # First: try local detection
    for pane_idx in $(tmux list-panes -t ":${win_idx}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t ":${win_idx}.${pane_idx}" -p "#{pane_tty}" 2>/dev/null)
        [[ -z "$tty" ]] && continue

        local tool_pid
        tool_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E "$pattern" | head -1 | awk '{print $1}')
        [[ -z "$tool_pid" ]] && continue

        # Found tool - check if busy using tool-specific detection
        if [[ "$tool" == "opencode" ]]; then
            # Opencode: compare stdout offset against baseline from when user last viewed
            # If offset increased significantly since viewing, work was done
            local stdout_offset
            stdout_offset=$(lsof -p "$tool_pid" 2>/dev/null | grep "1u.*tty" | awk '{print $7}' | sed 's/0t//')
            local baseline_file="$STATE_DIR/opencode-baseline-$win_idx"
            local worked_file="$STATE_DIR/opencode-worked-$win_idx"

            if [[ -n "$stdout_offset" ]] && [[ -f "$baseline_file" ]]; then
                local baseline
                baseline=$(cat "$baseline_file")
                # If offset increased by more than 100 bytes since user viewed, work happened
                if [[ "$stdout_offset" -gt "$baseline" ]]; then
                    local diff=$(( stdout_offset - baseline ))
                    if [[ "$diff" -gt 100 ]]; then
                        # Work detected! Set worked flag (only once)
                        if [[ ! -f "$worked_file" ]]; then
                            touch "$worked_file"
                        fi
                    fi
                fi
            fi
            # For Opencode, we don't return "busy" - we just set worked flag above
            # Always return "idle" so the indicator logic can run
        else
            # Claude: busy = has non-MCP child processes
            for child_pid in $(pgrep -P "$tool_pid" 2>/dev/null); do
                local cmd
                cmd=$(ps -o args= -p "$child_pid" 2>/dev/null)
                if ! echo "$cmd" | grep -qE 'mcp|/private/tmp/bunx'; then
                    echo "busy"
                    return 0
                fi
            done
        fi

        # Tool exists but not busy = idle
        echo "idle"
        return 0
    done

    # Second: check for devcontainer
    if command -v docker >/dev/null 2>&1; then
        local container
        container=$(find_devcontainer_for_window "$win_idx")
        if [[ -n "$container" ]]; then
            get_tool_status_in_container "$container" "$tool" "$pattern"
            return 0
        fi
    fi

    echo "none"  # No tool matching pattern in this window
}

# Find devcontainer instance name for a tmux window
find_devcontainer_for_window() {
    local win_idx="$1"
    local win_name
    win_name=$(tmux display-message -t ":${win_idx}" -p "#{window_name}" 2>/dev/null)

    # Strip any indicator prefix
    win_name=$(get_clean_window_name "$win_name")

    # Look for running container matching the window name
    local container
    container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "[-_]${win_name}$" | head -1)

    if [[ -n "$container" ]]; then
        echo "$container"
        return 0
    fi

    return 1
}

# Check if tool is idle inside a container
get_tool_status_in_container() {
    local container="$1"
    local tool="$2"
    local pattern="$3"

    # Find tool process in container
    local tool_pid
    tool_pid=$(docker exec "$container" pgrep -f "$pattern" 2>/dev/null | head -1)

    [[ -z "$tool_pid" ]] && { echo "none"; return 0; }

    # Check if busy using tool-specific detection
    if [[ "$tool" == "opencode" ]]; then
        # Opencode: busy = has active network connections (API call in progress)
        # Note: lsof may not be available in all containers, fall back to ss
        if docker exec "$container" sh -c "lsof -i -a -p $tool_pid 2>/dev/null | grep -q ESTABLISHED" 2>/dev/null; then
            echo "busy"
            return 0
        fi
    else
        # Claude: busy = has non-MCP child processes
        local children
        children=$(docker exec "$container" sh -c "pgrep -P $tool_pid 2>/dev/null" 2>/dev/null)

        for child_pid in $children; do
            local cmd
            cmd=$(docker exec "$container" ps -o args= -p "$child_pid" 2>/dev/null)
            if ! echo "$cmd" | grep -qE 'mcp|bunx'; then
                echo "busy"
                return 0
            fi
        done
    fi

    echo "idle"
}

# Called by tmux hook when user switches to a window
mark_viewed() {
    local win_idx="$1"
    mkdir -p "$STATE_DIR"

    # Clear all state files for both tools
    rm -f "$STATE_DIR/claude-worked-$win_idx"
    rm -f "$STATE_DIR/claude-notified-$win_idx"
    rm -f "$STATE_DIR/opencode-worked-$win_idx"
    rm -f "$STATE_DIR/opencode-notified-$win_idx"

    # For Opencode: record current stdout offset as baseline when viewing
    # This lets us detect work that happens AFTER user leaves
    for pane_idx in $(tmux list-panes -t ":${win_idx}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t ":${win_idx}.${pane_idx}" -p "#{pane_tty}" 2>/dev/null)
        [[ -z "$tty" ]] && continue

        local tool_pid
        tool_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E '(^| |/)opencode( |$)' | head -1 | awk '{print $1}')
        [[ -z "$tool_pid" ]] && continue

        # Record stdout offset baseline
        local stdout_offset
        stdout_offset=$(lsof -p "$tool_pid" 2>/dev/null | grep "1u.*tty" | awk '{print $7}' | sed 's/0t//')
        if [[ -n "$stdout_offset" ]]; then
            echo "$stdout_offset" > "$STATE_DIR/opencode-baseline-$win_idx"
        fi
    done

    # Remove all indicators from window name
    update_window_indicators "$win_idx"
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
