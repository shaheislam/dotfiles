#!/usr/bin/env bash
# Daemon that watches for Claude and Opencode windows needing input
# Shows indicators only when tools have done work since you last viewed the window
#
# Indicators:
#   ● = Claude is idle and has worked since last view
#   ◆ = Opencode is idle and has worked since last view
#   ●◆ = Both are idle in the same window
#   ⚠ = ralph-loop stuck (iteration unchanged for >STUCK_THRESHOLD seconds)
#
# Detection method:
# - Uses stdout offset tracking to detect when tools produce output
# - When user views a window: clear all state (baseline, worked, notified)
# - When user leaves: daemon's next poll establishes a new baseline
# - On subsequent polls: compare current offset to baseline
# - If offset increased by >2048 bytes: tool has done work, show indicator
#
# State files (in /tmp/tmux-claude-state/):
# - *-baseline-N: stdout offset established after user left window N
# - *-pending-N: offset snapshot when growth first detected (confirmation pending)
# - *-worked-N: flag indicating tool produced confirmed output since last view
# - *-notified-N: flag indicating indicator is currently shown
# - ralph-iteration-N: last seen iteration:timestamp for stuck detection
# - ralph-stuck-N: flag indicating ralph-loop is stuck
#
# Run with: tmux-claude-watcher.sh start
# Stop with: tmux-claude-watcher.sh stop

# Unicode indicators (BMP characters — no locale workarounds needed)
CLAUDE_INDICATOR="●"
OPENCODE_INDICATOR="◆"
STUCK_INDICATOR="⚠"

# How long (seconds) an active ralph-loop can go without incrementing iteration
# before it's considered stuck. Default 600s (10 min).
STUCK_THRESHOLD="${STUCK_THRESHOLD:-600}"

# Get tmux socket for explicit connection (needed for daemon)
TMUX_SOCKET="${TMUX%%,*}"
PID_FILE="/tmp/tmux-claude-watcher.pid"
STATE_DIR="/tmp/tmux-claude-state"
POLL_INTERVAL=10

# Per-poll-cycle caches (populated by check_all_windows)
declare -A PANE_TTYS         # key=session:win_idx, val="pane_idx:tty pane_idx:tty ..."
declare -A ACTIVE_SET        # key=session:win_idx, val=1 if active
declare -A PANE_PATHS        # key=session:win_idx, val=pane_current_path of first pane
declare -A WNAME_STYLE_CACHE # key=session:win_idx, val=current @wname_style value
declare -A NO_TOOL_CACHE     # key=session:win_idx, val=epoch when "none" was cached
NO_TOOL_TTL=60               # seconds before re-checking windows with no agents

start_daemon() {
    # Kill ALL existing watcher instances (not just PID file tracked one)
    # This handles stale processes from old code, crashed restarts, etc.
    local my_pid=$$
    pgrep -f "tmux-claude-watcher.sh start" 2>/dev/null | while read pid; do
        [[ "$pid" != "$my_pid" ]] && kill "$pid" 2>/dev/null
    done
    rm -f "$PID_FILE"
    sleep 0.2 # Brief pause for processes to exit

    mkdir -p "$STATE_DIR"

    (
        trap "rm -f '$PID_FILE'" EXIT

        # Ensure variables are set correctly in daemon context
        TMUX_SOCKET="${TMUX%%,*}"
        CLAUDE_INDICATOR="●"
        OPENCODE_INDICATOR="◆"
        STUCK_INDICATOR="⚠"
        STUCK_THRESHOLD="${STUCK_THRESHOLD:-600}"

        while true; do
            check_all_windows
            sleep "$POLL_INTERVAL"
        done
    ) &

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

# Strip all known indicators from window name
get_clean_window_name() {
    local win_name="$1"
    # Strip stuck indicator (appears first when present)
    win_name="${win_name#⚠ }"
    win_name="${win_name#⚠}"
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
    # Strip convoy progress suffix like " [2/4]"
    win_name=$(echo "$win_name" | sed 's/ \[[0-9]*\/[0-9]*\]$//')
    echo "$win_name"
}

# Get convoy progress for a worktree (cached per poll cycle)
# Returns "N/M" string or empty if not in a convoy
CONVOY_CACHE_TS=0
declare -A CONVOY_PROGRESS_CACHE

get_convoy_progress() {
    local pane_path="$1"
    local now
    now=$(date +%s)

    # Refresh convoy cache every 30s (avoid hammering JSONL on every window)
    if ((now - CONVOY_CACHE_TS > 30)); then
        CONVOY_CACHE_TS=$now
        CONVOY_PROGRESS_CACHE=()

        local convoy_file="${HOME}/.claude/convoys.jsonl"
        [[ -f "$convoy_file" ]] || return

        # Build cache: convoy_id → "completed/total"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local cid progress
            read -r cid progress < <(python3 -c "
import sys, json
c = json.loads('''$line''')
total = len(c['status'])
completed = sum(1 for v in c['status'].values() if v == 'completed')
print(c['id'], f'{completed}/{total}')" 2>/dev/null) || continue
            [[ -n "$cid" ]] && CONVOY_PROGRESS_CACHE["$cid"]="$progress"
        done <"$convoy_file"
    fi

    # Find convoy_id from worktree state file
    [[ -z "$pane_path" ]] && return
    local state_file="${pane_path}/.claude/gwt-ticket.local.md"
    [[ -f "$state_file" ]] || return

    local convoy_id=""
    local in_fm=false
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if $in_fm; then break; else
                in_fm=true
                continue
            fi
        fi
        $in_fm || continue
        case "$line" in
        convoy_id:*)
            convoy_id="${line#convoy_id:}"
            convoy_id="${convoy_id// /}"
            ;;
        esac
    done <"$state_file"

    [[ -n "$convoy_id" ]] && [[ -n "${CONVOY_PROGRESS_CACHE[$convoy_id]:-}" ]] && echo "${CONVOY_PROGRESS_CACHE[$convoy_id]}"
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

    # Strip any existing convoy suffix like " [2/4]"
    clean_name=$(echo "$clean_name" | sed 's/ \[[0-9]*\/[0-9]*\]$//')

    local prefix=""

    # Stuck indicator comes first (most urgent)
    [[ -f "$STATE_DIR/ralph-stuck-$state_key" ]] && prefix+="$STUCK_INDICATOR"

    # Build prefix from notification state (consistent order: Claude first)
    [[ -f "$STATE_DIR/claude-notified-$state_key" ]] && prefix+="$CLAUDE_INDICATOR"
    [[ -f "$STATE_DIR/opencode-notified-$state_key" ]] && prefix+="$OPENCODE_INDICATOR"

    # Convoy progress suffix
    local convoy_suffix=""
    local pane_path="${PANE_PATHS[${session}:${win_idx}]:-}"
    if [[ -z "$pane_path" ]]; then
        pane_path=$(tmux display-message -t "${session}:${win_idx}.0" -p "#{pane_current_path}" 2>/dev/null)
    fi
    if [[ -n "$pane_path" ]]; then
        local progress
        progress=$(get_convoy_progress "$pane_path")
        [[ -n "$progress" ]] && convoy_suffix=" [${progress}]"
    fi

    local new_name
    if [[ -n "$prefix" ]]; then
        new_name="${prefix} ${clean_name}${convoy_suffix}"
    else
        new_name="${clean_name}${convoy_suffix}"
    fi

    # Only rename if changed (avoid unnecessary tmux operations)
    if [[ "$current_name" != "$new_name" ]]; then
        # Execute rename with explicit socket and session targeting
        tmux -S "$TMUX_SOCKET" rename-window -t "${session}:${win_idx}" "$new_name"
    fi
}

# Check ralph-loop state for stuck agents in a window
check_ralph_loop_state() {
    local session="$1"
    local win_idx="$2"
    local state_key="${session}-${win_idx}"
    local stuck_file="$STATE_DIR/ralph-stuck-$state_key"
    local iter_file="$STATE_DIR/ralph-iteration-$state_key"

    # Use pre-fetched pane path (from check_all_windows) or fall back to tmux
    local pane_path="${3:-${PANE_PATHS[${session}:${win_idx}]:-}}"
    [[ -z "$pane_path" ]] && return

    local ralph_file="${pane_path}/.claude/ralph-loop.local.md"
    if [[ ! -f "$ralph_file" ]]; then
        # No ralph-loop state — clear any stale stuck/iteration files
        rm -f "$stuck_file" "$iter_file"
        return
    fi

    # Parse YAML frontmatter for active and iteration fields
    local active="" iteration=""
    local in_frontmatter=false
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if $in_frontmatter; then
                break # end of frontmatter
            else
                in_frontmatter=true
                continue
            fi
        fi
        $in_frontmatter || continue
        case "$line" in
        active:*)
            active="${line#active:}"
            active="${active// /}"
            ;;
        iteration:*)
            iteration="${line#iteration:}"
            iteration="${iteration// /}"
            ;;
        esac
    done <"$ralph_file"

    # Not active — clear stuck state
    if [[ "$active" != "true" ]]; then
        rm -f "$stuck_file" "$iter_file"
        return
    fi

    # Active — track iteration progress
    local now
    now=$(date +%s)

    if [[ -f "$iter_file" ]]; then
        local stored
        stored=$(cat "$iter_file")
        local stored_iter="${stored%%:*}"
        local stored_ts="${stored#*:}"

        if [[ "$iteration" == "$stored_iter" ]]; then
            # Iteration hasn't changed — check how long
            local elapsed=$((now - stored_ts))
            if [[ "$elapsed" -ge "$STUCK_THRESHOLD" ]]; then
                if [[ ! -f "$stuck_file" ]]; then
                    touch "$stuck_file"
                    update_window_indicators "$session" "$win_idx"
                    # Notify on first stuck detection
                    osascript -e "display notification \"ralph-loop stuck in window ${session}:${win_idx} (iteration $iteration unchanged for ${elapsed}s)\" with title \"Agent Stuck ⚠\"" 2>/dev/null || true
                fi
            fi
        else
            # Iteration advanced — reset tracking, clear stuck
            echo "${iteration}:${now}" >"$iter_file"
            if [[ -f "$stuck_file" ]]; then
                rm -f "$stuck_file"
                update_window_indicators "$session" "$win_idx"
            fi
        fi
    else
        # First time seeing this ralph-loop — record baseline
        echo "${iteration}:${now}" >"$iter_file"
    fi
}

# Update per-window @wname_style option for choose-tree color coding
# Mirrors icon indicator logic: only color idle/stuck states (notification-driven)
# Clears on mark_viewed (user switches to window), same as icons
# Priority: stuck (red) > idle (yellow) > none (default green from pane fg)
update_agent_state() {
    local session="$1"
    local win_idx="$2"
    local state_key="${session}-${win_idx}"
    local target="${session}:${win_idx}"

    local style=""
    if [[ -f "$STATE_DIR/ralph-stuck-$state_key" ]]; then
        style="#[fg=#f7768e]" # red — stuck (ralph-loop stalled)
    elif [[ -f "$STATE_DIR/claude-notified-$state_key" ]] || [[ -f "$STATE_DIR/opencode-notified-$state_key" ]]; then
        style="#[fg=#e0af68]" # yellow — idle (agent waiting for input)
    fi

    # Read from bash cache instead of tmux IPC
    local current="${WNAME_STYLE_CACHE[$target]:-}"

    if [[ -z "$style" ]]; then
        if [[ -n "$current" ]]; then
            tmux set-window-option -t "$target" -u @wname_style 2>/dev/null || true
            unset "WNAME_STYLE_CACHE[$target]"
        fi
    elif [[ "$style" != "$current" ]]; then
        tmux set-window-option -t "$target" @wname_style "$style" 2>/dev/null || true
        WNAME_STYLE_CACHE[$target]="$style"
    fi
}

check_all_windows() {
    # Single tmux IPC call to get all pane data across all sessions
    local pane_data
    pane_data=$(tmux list-panes -a -F $'#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_tty}\t#{window_active}\t#{pane_current_path}' 2>/dev/null)
    [[ -z "$pane_data" ]] && return

    # Reset per-cycle lookup tables
    PANE_TTYS=()
    ACTIVE_SET=()
    PANE_PATHS=()

    # Build lookup tables from single query
    declare -A seen_windows
    local all_windows=()
    local session win_idx pane_idx pane_tty win_active pane_path
    while IFS=$'\t' read -r session win_idx pane_idx pane_tty win_active pane_path; do
        [[ -z "$session" ]] && continue
        local key="${session}:${win_idx}"

        # Track unique windows for iteration
        if [[ -z "${seen_windows[$key]:-}" ]]; then
            seen_windows[$key]=1
            all_windows+=("$key")
        fi

        # Accumulate TTYs per window (space-separated "pane_idx:tty" pairs)
        if [[ -n "${PANE_TTYS[$key]:-}" ]]; then
            PANE_TTYS[$key]+=" ${pane_idx}:${pane_tty}"
        else
            PANE_TTYS[$key]="${pane_idx}:${pane_tty}"
        fi

        # Record active windows
        [[ "$win_active" == "1" ]] && ACTIVE_SET[$key]=1

        # Store path of first pane (pane 0) for each window
        [[ "$pane_idx" == "0" ]] && PANE_PATHS[$key]="$pane_path"
    done <<< "$pane_data"

    local now
    now=$(date +%s)

    for entry in "${all_windows[@]}"; do
        session="${entry%%:*}"
        win_idx="${entry#*:}"
        local state_key="${session}-${win_idx}"

        # Init status globals for update_agent_state
        LAST_CLAUDE_STATUS="none"
        LAST_OPENCODE_STATUS="none"

        # Skip if this is the active window in its session
        [[ -n "${ACTIVE_SET[$entry]:-}" ]] && continue

        # Check for cache invalidation signal from mark_viewed
        if [[ -f "$STATE_DIR/invalidate-$state_key" ]]; then
            rm -f "$STATE_DIR/invalidate-$state_key"
            unset "NO_TOOL_CACHE[$entry]"
        fi

        # No-tool cache: skip expensive ps/docker detection for non-agent windows
        local cached_ts="${NO_TOOL_CACHE[$entry]:-0}"
        if ((cached_ts > 0 && now - cached_ts < NO_TOOL_TTL)); then
            update_agent_state "$session" "$win_idx"
            continue
        fi

        # Process each tool independently
        # Claude: matches /opt/homebrew/bin/claude (full path)
        # Opencode: matches "opencode" (appears without path in ps, preceded by space)
        process_tool_state "$session" "$win_idx" "claude" '/claude( |$)'
        process_tool_state "$session" "$win_idx" "opencode" '(^| |/)opencode( |$)'

        # Update no-tool cache: skip expensive detection next time
        if [[ "$LAST_CLAUDE_STATUS" == "none" ]] && [[ "$LAST_OPENCODE_STATUS" == "none" ]]; then
            NO_TOOL_CACHE[$entry]=$now
        else
            unset "NO_TOOL_CACHE[$entry]"
        fi

        # Check for stuck ralph-loop agents (pass pre-fetched path)
        check_ralph_loop_state "$session" "$win_idx" "${PANE_PATHS[$entry]:-}"

        # Update per-window agent state for choose-tree coloring
        update_agent_state "$session" "$win_idx"
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

    # Expose status via globals for update_agent_state
    if [[ "$tool" == "claude" ]]; then
        LAST_CLAUDE_STATUS="$status"
    elif [[ "$tool" == "opencode" ]]; then
        LAST_OPENCODE_STATUS="$status"
    fi

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

    # First: try local detection using pre-fetched pane TTYs
    local key="${session}:${win_idx}"
    local tty_data="${PANE_TTYS[$key]:-}"
    for tty_entry in $tty_data; do
        local pane_idx="${tty_entry%%:*}"
        local tty="${tty_entry#*:}"
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
            local pending_file="$STATE_DIR/${tool}-pending-$state_key"
            if [[ -f "$baseline_file" ]]; then
                local baseline
                baseline=$(cat "$baseline_file")
                local diff=$((stdout_offset - baseline))
                if [[ "$diff" -gt 2048 ]]; then
                    if [[ -f "$pending_file" ]]; then
                        # Second consecutive detection — confirm as real work
                        local pending_offset
                        pending_offset=$(cat "$pending_file")
                        if [[ "$stdout_offset" -gt "$pending_offset" ]]; then
                            # Output is still growing — this is real work
                            if [[ ! -f "$worked_file" ]]; then
                                touch "$worked_file"
                            fi
                            rm -f "$pending_file"
                        else
                            # Output stopped growing — was just a UI burst, reset
                            rm -f "$pending_file"
                            echo "$stdout_offset" >"$baseline_file"
                        fi
                    else
                        # First detection — record pending, confirm on next poll
                        echo "$stdout_offset" >"$pending_file"
                    fi
                else
                    # Below threshold — clear any pending state
                    rm -f "$pending_file"
                fi
            else
                # No baseline yet — record current offset as starting point
                # Don't assume work was done; only future output beyond this
                # point counts as new work. This prevents false indicators when
                # the user views a window then leaves without the tool doing
                # any actual work (idle UI redraws would otherwise trigger it).
                echo "$stdout_offset" >"$baseline_file"
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

    echo "none" # No tool matching pattern in this window
}

# Find devcontainer instance name for a tmux window
find_devcontainer_for_window() {
    local target="$1" # session:win_idx format
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

    [[ -z "$tool_pid" ]] && {
        echo "none"
        return 0
    }

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

    # Clear all state files for both tools — including baselines.
    # The daemon will re-establish baselines on the next poll after the user
    # leaves this window. This prevents false indicators caused by idle UI
    # output (prompt redraws, status updates) that occurs while the user is
    # viewing the window.
    rm -f "$STATE_DIR/claude-worked-$state_key" \
          "$STATE_DIR/claude-notified-$state_key" \
          "$STATE_DIR/claude-baseline-$state_key" \
          "$STATE_DIR/claude-pending-$state_key" \
          "$STATE_DIR/opencode-worked-$state_key" \
          "$STATE_DIR/opencode-notified-$state_key" \
          "$STATE_DIR/opencode-baseline-$state_key" \
          "$STATE_DIR/opencode-pending-$state_key" \
          "$STATE_DIR/ralph-stuck-$state_key" \
          "$STATE_DIR/ralph-iteration-$state_key"

    # Signal daemon to invalidate no-tool cache for this window
    touch "$STATE_DIR/invalidate-$state_key"

    # Clear agent state color for choose-tree
    tmux set-window-option -t "${session}:${win_idx}" -u @wname_style 2>/dev/null || true

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
