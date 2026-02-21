#!/usr/bin/env bash
#
# agent-state.sh - Derive agent state from tmux + git + ralph-loop state
#
# Instead of maintaining separate state tracking, derives the current state
# of an autonomous agent by inspecting tmux processes, git status, and
# ralph-loop/ticket-execute state files.
#
# Inspired by Gastown's ZFC (Zero-File-Cache) pattern: derive state from
# ground truth rather than caching it.
#
# Usage:
#   agent-state.sh <worktree-path>              # Human-readable output
#   agent-state.sh <worktree-path> --json        # JSON output
#   agent-state.sh <session>:<window>            # By tmux target
#   agent-state.sh --all                         # All active worktrees
#   agent-state.sh --all --json                  # All active worktrees as JSON
#
# States:
#   running    - Agent is actively processing (has child processes or growing stdout)
#   idle       - Agent process exists but not actively working
#   stuck      - Ralph-loop active but iteration unchanged for >10 minutes
#   completed  - Ralph-loop finished (active: false)
#   dead       - No agent process found but ticket is still active
#   none       - No ticket execution in this worktree
#
# Exit codes:
#   0 - State determined successfully
#   1 - Error (bad args, path not found)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/json-helpers.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# How long before we consider an agent stuck (seconds)
STUCK_THRESHOLD="${STUCK_THRESHOLD:-600}" # 10 minutes default

JSON_OUTPUT=false
SHOW_ALL=false
TARGET=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --json)
        JSON_OUTPUT=true
        shift
        ;;
    --all)
        SHOW_ALL=true
        shift
        ;;
    --help | -h)
        echo "Usage: agent-state.sh <worktree-path|session:window> [--json]"
        echo "       agent-state.sh --all [--json]"
        echo ""
        echo "Derive agent state from tmux + git + ralph-loop state files."
        echo ""
        echo "States: running | idle | stuck | completed | dead | none"
        echo ""
        echo "Options:"
        echo "  --json   Output as JSON"
        echo "  --all    Show all active worktrees"
        echo "  --help   Show this help"
        exit 0
        ;;
    -*)
        echo "Error: Unknown option $1" >&2
        exit 1
        ;;
    *)
        TARGET="$1"
        shift
        ;;
    esac
done

# Parse YAML frontmatter value from a state file
parse_yaml_value() {
    local key="$1"
    local file="$2"
    grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}: *//" | tr -d '"'
}

# Find the tmux session:window for a worktree path
find_tmux_target() {
    local worktree_path="$1"
    local state_file="$worktree_path/.claude/ticket-execute.local.md"

    if [[ -f "$state_file" ]]; then
        local session window
        session=$(parse_yaml_value "tmux_session" "$state_file")
        window=$(parse_yaml_value "tmux_window" "$state_file")
        if [[ -n "$session" && -n "$window" ]]; then
            echo "${session}:${window}"
            return 0
        fi
    fi

    # Fallback: search tmux panes for matching current path
    while IFS= read -r line; do
        local target pane_path
        target=$(echo "$line" | cut -d: -f1-2)
        pane_path=$(echo "$line" | cut -d: -f3-)
        # Check if any pane in this window is in the worktree
        if [[ "$pane_path" == "$worktree_path" || "$pane_path" == "$worktree_path/"* ]]; then
            # Return session:window (strip pane index)
            echo "${target%.*}" | head -1
            return 0
        fi
    done < <(tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}:#{pane_current_path}" 2>/dev/null)

    return 1
}

# Find worktree path from tmux target
find_worktree_from_tmux() {
    local target="$1"
    local session="${target%%:*}"
    local win_idx="${target#*:}"

    # Check pane current paths
    for pane_path in $(tmux list-panes -t "${session}:${win_idx}" -F "#{pane_current_path}" 2>/dev/null); do
        if [[ -f "$pane_path/.claude/ticket-execute.local.md" ]]; then
            echo "$pane_path"
            return 0
        fi
        # Check parent dirs (agent might cd into subdirectory)
        local check_path="$pane_path"
        for _ in 1 2 3; do
            check_path=$(dirname "$check_path")
            if [[ -f "$check_path/.claude/ticket-execute.local.md" ]]; then
                echo "$check_path"
                return 0
            fi
        done
    done

    return 1
}

# Check if claude process is alive in a tmux window
find_claude_pid() {
    local target="$1"
    local session="${target%%:*}"
    local win_idx="${target#*:}"

    for pane_idx in $(tmux list-panes -t "${session}:${win_idx}" -F "#{pane_index}" 2>/dev/null); do
        local tty
        tty=$(tmux display-message -t "${session}:${win_idx}.${pane_idx}" -p "#{pane_tty}" 2>/dev/null) || continue
        [[ -z "$tty" ]] && continue

        local pid
        pid=$(ps -o pid=,args= -t "$tty" 2>/dev/null | grep -E '/claude( |$)' | head -1 | awk '{print $1}')
        if [[ -n "$pid" ]]; then
            echo "$pid"
            return 0
        fi
    done

    return 1
}

# Check if claude has active child processes (not just MCP servers)
has_active_children() {
    local pid="$1"
    local children
    children=$(pgrep -P "$pid" 2>/dev/null) || return 1

    for child_pid in $children; do
        local cmd
        cmd=$(ps -o args= -p "$child_pid" 2>/dev/null) || continue
        # Skip MCP servers and caffeinate - these are always running
        if ! echo "$cmd" | grep -qE 'mcp|bunx|caffeinate|node.*server'; then
            return 0
        fi
    done

    return 1
}

# Determine agent state for a worktree
get_agent_state() {
    local worktree_path="$1"

    local ticket_file="$worktree_path/.claude/ticket-execute.local.md"
    local ralph_file="$worktree_path/.claude/ralph-loop.local.md"

    # No ticket execution state → none
    if [[ ! -f "$ticket_file" ]]; then
        echo '{"state":"none","worktree":"'"$worktree_path"'"}'
        return 0
    fi

    local ticket_active issue_key title
    ticket_active=$(parse_yaml_value "active" "$ticket_file")
    issue_key=$(parse_yaml_value "issue_key" "$ticket_file")
    title=$(parse_yaml_value "title" "$ticket_file")

    # Ticket marked inactive → completed
    if [[ "$ticket_active" == "false" ]]; then
        local completed_at pr_url
        completed_at=$(parse_yaml_value "completed_at" "$ticket_file")
        pr_url=$(parse_yaml_value "pr_url" "$ticket_file")
        echo '{"state":"completed","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","completed_at":"'"$completed_at"'","pr_url":"'"$pr_url"'"}'
        return 0
    fi

    # Ralph-loop state
    local ralph_active="" iteration="" max_iterations="" started_at=""
    if [[ -f "$ralph_file" ]]; then
        ralph_active=$(parse_yaml_value "active" "$ralph_file")
        iteration=$(parse_yaml_value "iteration" "$ralph_file")
        max_iterations=$(parse_yaml_value "max_iterations" "$ralph_file")
        started_at=$(parse_yaml_value "started_at" "$ralph_file")
    fi

    # Ralph-loop completed but ticket still active → completed
    # Check explicit active:false OR file deleted by ralph-wiggum stop hook
    if [[ "$ralph_active" == "false" ]]; then
        echo '{"state":"completed","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","iteration":"'"${iteration:-0}"'","max_iterations":"'"${max_iterations:-0}"'"}'
        return 0
    fi

    # Ralph file deleted by stop hook on completion
    # If ticket active + witness monitoring + ralph file gone → ralph completed
    if [[ ! -f "$ralph_file" ]]; then
        local witness_file="$worktree_path/.claude/witness.local.md"
        if [[ -f "$witness_file" ]]; then
            local witness_active
            witness_active=$(parse_yaml_value "active" "$witness_file")
            if [[ "$witness_active" == "true" ]]; then
                echo '{"state":"completed","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","iteration":"0","max_iterations":"0"}'
                return 0
            fi
        fi
    fi

    # Find tmux target to check process state
    local tmux_target
    tmux_target=$(find_tmux_target "$worktree_path") || tmux_target=""

    if [[ -z "$tmux_target" ]]; then
        # No tmux window found → dead
        echo '{"state":"dead","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","reason":"no tmux window","iteration":"'"${iteration:-0}"'","max_iterations":"'"${max_iterations:-0}"'"}'
        return 0
    fi

    # Check if tmux window exists
    if ! tmux has-session -t "${tmux_target%%:*}" 2>/dev/null; then
        echo '{"state":"dead","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","reason":"tmux session gone","iteration":"'"${iteration:-0}"'","max_iterations":"'"${max_iterations:-0}"'"}'
        return 0
    fi

    # Check if claude process is alive
    local claude_pid
    claude_pid=$(find_claude_pid "$tmux_target") || claude_pid=""

    if [[ -z "$claude_pid" ]]; then
        echo '{"state":"dead","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","reason":"claude process not found","tmux":"'"$tmux_target"'","iteration":"'"${iteration:-0}"'","max_iterations":"'"${max_iterations:-0}"'"}'
        return 0
    fi

    # Check for stuck state (iteration unchanged for >STUCK_THRESHOLD)
    if [[ -n "$iteration" && "$ralph_active" == "true" ]]; then
        local iteration_file="/tmp/tmux-claude-state/ralph-iter-$(echo "$worktree_path" | tr '/' '-')"
        mkdir -p /tmp/tmux-claude-state

        if [[ -f "$iteration_file" ]]; then
            local saved_iteration saved_timestamp
            saved_iteration=$(cut -d: -f1 "$iteration_file")
            saved_timestamp=$(cut -d: -f2 "$iteration_file")
            local now
            now=$(date +%s)

            if [[ "$iteration" == "$saved_iteration" ]]; then
                local elapsed=$((now - saved_timestamp))
                if [[ "$elapsed" -gt "$STUCK_THRESHOLD" ]]; then
                    echo '{"state":"stuck","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","iteration":"'"$iteration"'","max_iterations":"'"${max_iterations:-0}"'","stuck_for":"'"$elapsed"'","tmux":"'"$tmux_target"'","pid":"'"$claude_pid"'"}'
                    return 0
                fi
            else
                # Iteration advanced, update tracking
                echo "${iteration}:${now}" >"$iteration_file"
            fi
        else
            # First time seeing this worktree, record current state
            echo "${iteration}:$(date +%s)" >"$iteration_file"
        fi
    fi

    # Check for active work (child processes)
    if has_active_children "$claude_pid"; then
        echo '{"state":"running","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","iteration":"'"${iteration:-0}"'","max_iterations":"'"${max_iterations:-0}"'","tmux":"'"$tmux_target"'","pid":"'"$claude_pid"'"}'
        return 0
    fi

    # Process exists but no active children → idle
    echo '{"state":"idle","worktree":"'"$worktree_path"'","issue_key":"'"$issue_key"'","title":"'"$(echo "$title" | sed 's/"/\\"/g')"'","iteration":"'"${iteration:-0}"'","max_iterations":"'"${max_iterations:-0}"'","tmux":"'"$tmux_target"'","pid":"'"$claude_pid"'"}'
    return 0
}

# Render state for human consumption
render_state() {
    local json="$1"

    # Extract all fields in a single jq call (replaces 8 separate python3 spawns)
    local fields
    fields=$(printf '%s' "$json" | jq -r '[
        (.state // ""),
        (.worktree // ""),
        (.issue_key // ""),
        (.title // ""),
        (.iteration // ""),
        (.max_iterations // ""),
        (.reason // ""),
        (.stuck_for // "")
    ] | join("\t")' 2>/dev/null) || return 0

    local state worktree issue_key title iteration max_iterations reason stuck_for
    IFS=$'\t' read -r state worktree issue_key title iteration max_iterations reason stuck_for <<<"$fields"

    if [[ "$state" == "none" || -z "$state" ]]; then
        return 0
    fi

    local color="$NC"
    local icon=""
    case "$state" in
    running)
        color="$GREEN"
        icon="▶"
        ;;
    idle)
        color="$YELLOW"
        icon="⏸"
        ;;
    stuck)
        color="$RED"
        icon="⚠"
        ;;
    completed)
        color="$CYAN"
        icon="✓"
        ;;
    dead)
        color="$RED"
        icon="✗"
        ;;
    esac

    local iter_display=""
    if [[ -n "$iteration" && -n "$max_iterations" && "$iteration" != "0" ]]; then
        iter_display=" [${iteration}/${max_iterations}]"
    fi

    local reason_display=""
    if [[ -n "$reason" ]]; then
        reason_display=" ($reason)"
    fi

    local stuck_display=""
    if [[ -n "$stuck_for" ]]; then
        local minutes=$((stuck_for / 60))
        stuck_display=" (${minutes}m)"
    fi

    local wt_display
    wt_display=$(basename "$worktree")

    printf "${icon} ${color}%-12s${NC} %-30s %-12s %s${stuck_display}${reason_display}\n" \
        "$state${iter_display}" "$wt_display" "${issue_key:-N/A}" "$title"
}

# Show all active worktrees
show_all() {
    local found=false

    if ! $JSON_OUTPUT; then
        echo ""
        printf "  %-12s %-30s %-12s %s\n" "STATE" "WORKTREE" "ISSUE" "TITLE"
        printf "  %-12s %-30s %-12s %s\n" "────────────" "──────────────────────────────" "────────────" "──────────────────────"
    fi

    if $JSON_OUTPUT; then
        echo "["
        local first=true
    fi

    # Find all worktrees with ticket-execute state files
    while IFS= read -r state_file; do
        local worktree_path
        worktree_path=$(dirname "$(dirname "$state_file")")

        local json
        json=$(get_agent_state "$worktree_path")
        local state
        state=$(printf '%s' "$json" | jq -r '.state // ""' 2>/dev/null)

        if [[ "$state" != "none" ]]; then
            found=true
            if $JSON_OUTPUT; then
                if ! $first; then echo ","; fi
                echo "  $json"
                first=false
            else
                render_state "$json"
            fi
        fi
    done < <(find "$HOME" -maxdepth 5 -path "*/.claude/ticket-execute.local.md" -type f 2>/dev/null)

    if $JSON_OUTPUT; then
        echo ""
        echo "]"
    elif ! $found; then
        echo "  No active agent executions found"
    fi

    if ! $JSON_OUTPUT; then
        echo ""
    fi
}

# Main
if $SHOW_ALL; then
    show_all
    exit 0
fi

if [[ -z "$TARGET" ]]; then
    echo "Usage: agent-state.sh <worktree-path|session:window> [--json]" >&2
    echo "       agent-state.sh --all [--json]" >&2
    exit 1
fi

# Determine if target is a tmux reference or path
WORKTREE_PATH=""
if [[ "$TARGET" == *:* && ! -d "$TARGET" ]]; then
    # Looks like session:window
    WORKTREE_PATH=$(find_worktree_from_tmux "$TARGET") || {
        if $JSON_OUTPUT; then
            echo '{"state":"none","error":"no worktree found for tmux target","target":"'"$TARGET"'"}'
        else
            echo -e "${RED}Error: No worktree found for tmux target: $TARGET${NC}" >&2
        fi
        exit 1
    }
else
    WORKTREE_PATH="$TARGET"
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo -e "${RED}Error: Directory not found: $WORKTREE_PATH${NC}" >&2
    exit 1
fi

# Get and output state
JSON=$(get_agent_state "$WORKTREE_PATH")

if $JSON_OUTPUT; then
    echo "$JSON"
else
    render_state "$JSON"
fi
