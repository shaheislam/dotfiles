#!/usr/bin/env bash
# Daemon that color-codes tmux windows based on agent state.
#
# 4-state color scheme (purely realtime — no persistent state files):
#   Red (#f7768e)    = Agent actively working (spinner + "… (" visible)
#   Orange (#e0af68) = Waiting for user input (agent present, no spinner)
#   Green (#9ece6a)  = Task completed (COMPLETE or _DONE in pane)
#   Default          = No agent in window
#
# Detection per poll (every 10s):
#   1. tmux list-panes -a to get pane TTYs
#   2. ps -t $tty to check for claude/opencode process
#   3. tmux capture-pane to check for "… (" spinner pattern
#   4. Set @wname_style accordingly
#
# Run with: tmux-claude-watcher.sh start
# Stop with: tmux-claude-watcher.sh stop

TMUX_SOCKET="${TMUX%%,*}"
PID_FILE="/tmp/tmux-claude-watcher.pid"
POLL_INTERVAL=10

start_daemon() {
    # Kill ALL existing watcher instances
    local my_pid=$$
    pgrep -f "tmux-claude-watcher.sh start" 2>/dev/null | while read pid; do
        [[ "$pid" != "$my_pid" ]] && kill "$pid" 2>/dev/null
    done
    rm -f "$PID_FILE"
    sleep 0.2

    # Clean up legacy state directory
    rm -rf /tmp/tmux-claude-state 2>/dev/null

    (
        trap "rm -f '$PID_FILE'" EXIT
        TMUX_SOCKET="${TMUX%%,*}"

        while true; do
            check_all_windows
            sleep "$POLL_INTERVAL"
        done
    ) </dev/null >/dev/null 2>&1 &
    disown

    echo $! >"$PID_FILE"
    echo "Watcher started (PID $!)"
}

stop_daemon() {
    pgrep -f "tmux-claude-watcher.sh start" 2>/dev/null | while read pid; do
        kill "$pid" 2>/dev/null
    done
    rm -f "$PID_FILE"
    echo "Watcher stopped"
}

check_all_windows() {
    local pane_data
    pane_data=$(tmux list-panes -a -F $'#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_tty}\t#{pane_id}' 2>/dev/null)
    [[ -z "$pane_data" ]] && return

    # Build per-window pane lists: key=session:win_idx, val="pane_id:tty ..."
    declare -A window_panes
    declare -A seen_windows
    local all_windows=()

    local session win_idx pane_idx pane_tty pane_id
    while IFS=$'\t' read -r session win_idx pane_idx pane_tty pane_id; do
        [[ -z "$session" ]] && continue
        local key="${session}:${win_idx}"

        if [[ -z "${seen_windows[$key]:-}" ]]; then
            seen_windows[$key]=1
            all_windows+=("$key")
        fi

        if [[ -n "${window_panes[$key]:-}" ]]; then
            window_panes[$key]+=" ${pane_id}:${pane_tty}"
        else
            window_panes[$key]="${pane_id}:${pane_tty}"
        fi
    done <<<"$pane_data"

    for entry in "${all_windows[@]}"; do
        session="${entry%%:*}"
        win_idx="${entry#*:}"
        local target="${session}:${win_idx}"

        local agent_found=false
        local agent_working=false
        local agent_complete=false

        # Check each pane in this window for agent processes
        for pane_entry in ${window_panes[$entry]}; do
            local pid="${pane_entry%%:*}"
            local tty="${pane_entry#*:}"
            [[ -z "$tty" ]] && continue

            # Look for claude or opencode process on this TTY
            # Match with or without path prefix (e.g. "claude ..." or "/opt/homebrew/bin/claude ...")
            if ps -o args= -t "$tty" 2>/dev/null | grep -qE '(^|/)(claude|opencode)( |$)'; then
                agent_found=true

                # Detect state from the bottom of the pane (status area only).
                # Only check last 8 lines to avoid false positives from
                # conversation content that may contain the same patterns.
                # "… (" = spinner with timing = actively working
                #   e.g. "✽ Pontificating… (41s · ↓ 681 tokens)"
                # COMPLETE or _DONE = task finished
                # Otherwise = idle/waiting for input
                local pane_bottom
                pane_bottom=$(tmux capture-pane -t "$pid" -p 2>/dev/null | tail -n 8)
                if echo "$pane_bottom" | grep -q '… ('; then
                    agent_working=true
                elif echo "$pane_bottom" | grep -q 'COMPLETE\|_DONE'; then
                    agent_complete=true
                fi
                break
            fi
        done

        # Determine style (first match wins)
        local style=""
        if $agent_found; then
            if $agent_working; then
                style="#[fg=#f7768e]" # red — actively working
            elif $agent_complete; then
                style="#[fg=#9ece6a]" # green — task completed
            else
                style="#[fg=#e0af68]" # orange — waiting for input
            fi
        fi

        # Update @wname_style only if changed
        local current
        current=$(tmux show-window-option -t "$target" -v @wname_style 2>/dev/null || true)

        if [[ -z "$style" ]]; then
            [[ -n "$current" ]] && tmux set-window-option -t "$target" -u @wname_style 2>/dev/null || true
        elif [[ "$style" != "$current" ]]; then
            tmux set-window-option -t "$target" @wname_style "$style" 2>/dev/null || true
        fi
    done
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
*)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac
