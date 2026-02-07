#!/usr/bin/env bash
# Daemon that watches for Claude and Opencode windows needing input
# Shows indicators only when tools have done work since you last viewed the window
#
# Indicators:
#   ● = Claude is idle and has worked since last view
#   ◆ = Opencode is idle and has worked since last view
#   ●◆ = Both are idle in the same window
#
# Detection method:
# - Uses stdout offset tracking to detect when tools produce output
# - When user views a window: record current stdout offset as baseline
# - When user is away: compare current offset to baseline
# - If offset increased by >100 bytes: tool has done work, show indicator
#
# State files (in /tmp/tmux-claude-state/):
# - *-baseline-N: stdout offset when user last viewed window N
# - *-worked-N: flag indicating tool produced output since last view
# - *-notified-N: flag indicating indicator is currently shown
#
# Run with: tmux-claude-watcher.sh start
# Stop with: tmux-claude-watcher.sh stop

# Unicode indicators (BMP characters — no locale workarounds needed)
CLAUDE_INDICATOR="●"
OPENCODE_INDICATOR="◆"

# Get tmux socket for explicit connection (needed for daemon)
TMUX_SOCKET="${TMUX%%,*}"
PID_FILE="/tmp/tmux-claude-watcher.pid"
STATE_DIR="/tmp/tmux-claude-state"
POLL_INTERVAL=3

start_daemon() {
    # Kill ALL existing watcher instances (not just PID file tracked one)
    # This handles stale processes from old code, crashed restarts, etc.
    local my_pid=$$
    pgrep -f "tmux-claude-watcher.sh start" 2>/dev/null | while read pid; do
        [[ "$pid" != "$my_pid" ]] && kill "$pid" 2>/dev/null
    done
    rm -f "$PID_FILE"
    sleep 0.2  # Brief pause for processes to exit

    mkdir -p "$STATE_DIR"

    (
        trap "rm -f '$PID_FILE'" EXIT

        # Ensure variables are set correctly in daemon context
        TMUX_SOCKET="${TMUX%%,*}"
        CLAUDE_INDICATOR="●"
        OPENCODE_INDICATOR="◆"

        while true; do
            check_all_windows
            sleep "$POLL_INTERVAL"
        done
    ) &

    echo $! > "$PID_FILE"
    echo "Watcher started (PID $!)"
}

stop_daemon() {
    pgrep -f "tmux-claude-watcher.sh start" 2>/dev/null | while read pid; do
        kill "$pid" 2>/dev/null
    done
    rm -f "$PID_FILE"
    echo "Watcher stopped"
}

# Strip all known indicators from window name
get_clean_window_name() {
    local win_name="$1"
    # Strip current indicators (combined first, then individual, with and without space)
    win_name="${win_name#●◆ }"
    win_name="${win_name#● }"
    win_name="${win_name#◆ }"
    win_name="${win_name#●◆}"
    win_name="${win_name#●}"
    win_name="${win_name#◆}"
    # Strip legacy emoji indicators
    win_name="${win_name#🟢🔵 }"
    win_name="${win_name#🟢 }"
    win_name="${win_name#🔵 }"
    win_name="${win_name#🟢🔵}"
    win_name="${win_name#🟢}"
    win_name="${win_name#🔵}"
    # Strip legacy text indicators
    win_name="${win_name#\*+ }"
    win_name="${win_name#\* }"
    win_name="${win_name#+ }"
    win_name="${win_name#\*+}"
    win_name="${win_name#\*}"
    win_name="${win_name#+}"
    echo "$win_name"
}

# Centralized function to update window indicators based on state files
update_window_indicators() {
    local session="$1"
    local win_idx="$2"
    local state_key="${session}-${win_idx}"

    local current_name
    current_name=$(tmux display-message -t "${session}:${win_idx}" -p "#{window_name}" 2>/dev/null) || return

    local clean_name
    clean_name=$(get_clean_window_name "$current_name")

    local prefix=""

    # Build prefix from notification state (consistent order: Claude first)
    [[ -f "$STATE_DIR/claude-notified-$state_key" ]] && prefix+="$CLAUDE_INDICATOR"
    [[ -f "$STATE_DIR/opencode-notified-$state_key" ]] && prefix+="$OPENCODE_INDICATOR"

    local new_name
    if [[ -n "$prefix" ]]; then
        new_name="${prefix} ${clean_name}"
    else
        new_name="$clean_name"
    fi

    # Only rename if changed (avoid unnecessary tmux operations)
    if [[ "$current_name" != "$new_name" ]]; then
        # Execute rename with explicit socket and session targeting
        tmux -S "$TMUX_SOCKET" rename-window -t "${session}:${win_idx}" "$new_name"
    fi
}

check_all_windows() {
    # Get active window per session (to know what user is currently viewing)
    local active_windows
    active_windows=$(tmux list-windows -a -F "#{session_name}:#{window_index}:#{window_active}" 2>/dev/null | grep ':1$')
    [[ -z "$active_windows" ]] && return

    # All windows across all sessions
    local windows
    readarray -t windows < <(tmux list-windows -a -F "#{session_name}:#{window_index}" 2>/dev/null)

    for entry in "${windows[@]}"; do
        local session="${entry%%:*}"
        local win_idx="${entry#*:}"

        # Skip if this is the active window in its session
        echo "$active_windows" | grep -q "^${session}:${win_idx}:" && continue

        # Process each tool independently
        # Claude: matches /opt/homebrew/bin/claude (full path)
        # Opencode: matches "opencode" (appears without path in ps, preceded by space)
        process_tool_state "$session" "$win_idx" "claude" '/claude( |$)'
        process_tool_state "$session" "$win_idx" "opencode" '(^| |/)opencode( |$)'
    done
}

# Process state machine for a single tool in a window
process_tool_state() {
    local session="$1"
    local win_idx="$2"
    local tool="$3"
    local pattern="$4"

    local state_key="${session}-${win_idx}"
    local worked_file="$STATE_DIR/${tool}-worked-$state_key"
    local notified_file="$STATE_DIR/${tool}-notified-$state_key"

    # get_tool_status detects work via stdout offset and sets worked_file
    local status
    status=$(get_tool_status "$session" "$win_idx" "$tool" "$pattern")

    # Show indicator if tool is present and has worked since last view
    if [[ "$status" == "idle" ]]; then
        if [[ ! -f "$notified_file" ]] && [[ -f "$worked_file" ]]; then
            touch "$notified_file"
            update_window_indicators "$session" "$win_idx"
        fi
    fi
    # If status is "none", tool not found - do nothing
}

# Generic tool status detection
get_tool_status() {
    local session="$1"
    local win_idx="$2"
    local tool="$3"
    local pattern="$4"

    local state_key="${session}-${win_idx}"

    # First: try local detection
    for pane_idx in $(tmux list-panes -t "${session}:${win_idx}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t "${session}:${win_idx}.${pane_idx}" -p "#{pane_tty}" 2>/dev/null)
        [[ -z "$tty" ]] && continue

        local tool_pid
        tool_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E "$pattern" | head -1 | awk '{print $1}')
        [[ -z "$tool_pid" ]] && continue

        # Found tool - detect work using stdout offset tracking
        # This works for both Claude and Opencode - if terminal output increased
        # since user last viewed, work was done
        local stdout_offset
        stdout_offset=$(lsof -p "$tool_pid" 2>/dev/null | grep "1u.*tty" | awk '{print $7}' | sed 's/0t//')
        local baseline_file="$STATE_DIR/${tool}-baseline-$state_key"
        local worked_file="$STATE_DIR/${tool}-worked-$state_key"

        if [[ -n "$stdout_offset" ]]; then
            if [[ -f "$baseline_file" ]]; then
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
            else
                # No baseline (window never viewed since daemon start)
                # Create baseline and assume work was done — show indicator
                echo "$stdout_offset" > "$baseline_file"
                if [[ ! -f "$worked_file" ]]; then
                    touch "$worked_file"
                fi
            fi
        fi
        # Always return "idle" - the worked flag handles work detection

        # Tool exists but not busy = idle
        echo "idle"
        return 0
    done

    # Second: check for devcontainer
    if command -v docker >/dev/null 2>&1; then
        local container
        container=$(find_devcontainer_for_window "${session}:${win_idx}")
        if [[ -n "$container" ]]; then
            get_tool_status_in_container "$container" "$tool" "$pattern"
            return 0
        fi
    fi

    echo "none"  # No tool matching pattern in this window
}

# Find devcontainer instance name for a tmux window
find_devcontainer_for_window() {
    local target="$1"  # session:win_idx format
    local win_name
    win_name=$(tmux display-message -t "$target" -p "#{window_name}" 2>/dev/null)

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
            if ! echo "$cmd" | grep -qE 'mcp|bunx|caffeinate'; then
                echo "busy"
                return 0
            fi
        done
    fi

    echo "idle"
}

# Called by tmux hook when user switches to a window
mark_viewed() {
    local session="$1"
    local win_idx="$2"
    local state_key="${session}-${win_idx}"
    mkdir -p "$STATE_DIR"

    # Clear all state files for both tools
    rm -f "$STATE_DIR/claude-worked-$state_key"
    rm -f "$STATE_DIR/claude-notified-$state_key"
    rm -f "$STATE_DIR/claude-baseline-$state_key"
    rm -f "$STATE_DIR/opencode-worked-$state_key"
    rm -f "$STATE_DIR/opencode-notified-$state_key"
    rm -f "$STATE_DIR/opencode-baseline-$state_key"

    # Record stdout offset baseline for both Claude and Opencode
    # This lets us detect work that happens AFTER user leaves
    for pane_idx in $(tmux list-panes -t "${session}:${win_idx}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t "${session}:${win_idx}.${pane_idx}" -p "#{pane_tty}" 2>/dev/null)
        [[ -z "$tty" ]] && continue

        # Check for Claude
        local claude_pid
        claude_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E '/claude( |$)' | head -1 | awk '{print $1}')
        if [[ -n "$claude_pid" ]]; then
            local stdout_offset
            stdout_offset=$(lsof -p "$claude_pid" 2>/dev/null | grep "1u.*tty" | awk '{print $7}' | sed 's/0t//')
            if [[ -n "$stdout_offset" ]]; then
                echo "$stdout_offset" > "$STATE_DIR/claude-baseline-$state_key"
            fi
        fi

        # Check for Opencode
        local opencode_pid
        opencode_pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E '(^| |/)opencode( |$)' | head -1 | awk '{print $1}')
        if [[ -n "$opencode_pid" ]]; then
            local stdout_offset
            stdout_offset=$(lsof -p "$opencode_pid" 2>/dev/null | grep "1u.*tty" | awk '{print $7}' | sed 's/0t//')
            if [[ -n "$stdout_offset" ]]; then
                echo "$stdout_offset" > "$STATE_DIR/opencode-baseline-$state_key"
            fi
        fi
    done

    # Remove all indicators from window name
    update_window_indicators "$session" "$win_idx"
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
    mark-viewed) mark_viewed "$2" "$3" ;;
    *)
        echo "Usage: $0 {start|stop|status|mark-viewed <session> <window>}"
        exit 1
        ;;
esac
