#!/usr/bin/env bash
#
# gwt-mayor.sh - Global coordinator daemon (Mayor pattern)
#
# Lightweight coordinator that periodically scans all active worktrees,
# checks convoy progress, reads agent mail, and makes coordination
# decisions. Logs decisions to ~/.claude/mayor-log.jsonl.
#
# Usage:
#   gwt-mayor.sh start [--poll-interval 60]
#   gwt-mayor.sh stop
#   gwt-mayor.sh status [--json]
#   gwt-mayor.sh report
#   gwt-mayor.sh decide
#   gwt-mayor.sh log [N]
#
# Exit codes:
#   0 - Success
#   1 - Error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="/tmp/gwt-mayor.pid"
LOG_FILE="${HOME}/.claude/mayor-log.jsonl"
MAYOR_LOG="${HOME}/.claude/mayor-daemon.log"
POLL_INTERVAL=60

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

AGENT_STATE="$SCRIPT_DIR/agent-state.sh"
CONVOY_SCRIPT="$SCRIPT_DIR/convoy.sh"
MAIL_SCRIPT="$SCRIPT_DIR/agent-mail.sh"
TRIAGE_SCRIPT="$SCRIPT_DIR/agent-triage.sh"
QUEUE_SCRIPT="$SCRIPT_DIR/../.config/fish/functions/gwt-queue.fish"
MERGE_QUEUE="$SCRIPT_DIR/merge-queue.sh"

source "$SCRIPT_DIR/lib/json-helpers.sh"

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

log_decision() {
    local action="$1" reason="$2" target="${3:-}"
    mkdir -p "$(dirname "$LOG_FILE")"
    local ts
    ts="$(timestamp_now)"
    printf '{"timestamp":"%s","action":"%s","reason":"%s","target":"%s"}\n' \
        "$ts" "$(json_escape "$action")" "$(json_escape "$reason")" "$(json_escape "$target")" >>"$LOG_FILE"
}

daemon_log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >>"$MAYOR_LOG"
}

# --- Decision Engine ---

decide_cycle() {
    local decisions=0

    # 1. Scan all active worktrees
    local agents_json=""
    if [[ -x "$AGENT_STATE" ]]; then
        agents_json=$("$AGENT_STATE" --all --json 2>/dev/null) || agents_json="[]"
    else
        agents_json="[]"
    fi

    # Parse agent states into separate variables in one jq call
    # Handle both list and dict formats
    local stuck_agents idle_agents running_agents dead_agents completed_agents
    local state_lines
    state_lines=$(echo "$agents_json" | jq -r '
      (if type == "array" then . else [.[] | . as $v | $v] end)
      | .[] | "\(.state // "unknown"):\(.worktree // .path // "?")"
    ' 2>/dev/null) || state_lines=""

    stuck_agents=$(echo "$state_lines" | grep "^stuck:" | cut -d: -f2-)
    idle_agents=$(echo "$state_lines" | grep "^idle:" | cut -d: -f2-)
    dead_agents=$(echo "$state_lines" | grep "^dead:" | cut -d: -f2-)

    # 2. Handle stuck agents
    if [[ -n "$stuck_agents" ]]; then
        while IFS= read -r worktree; do
            [[ -z "$worktree" ]] && continue
            log_decision "TRIAGE" "Agent stuck >20min" "$worktree"
            daemon_log "Decision: TRIAGE stuck agent at $worktree"
            if [[ -x "$TRIAGE_SCRIPT" ]]; then
                "$TRIAGE_SCRIPT" "$worktree" 2>/dev/null || true
            fi
            decisions=$((decisions + 1))
        done <<<"$stuck_agents"
    fi

    # 3. Handle dead agents
    if [[ -n "$dead_agents" ]]; then
        while IFS= read -r worktree; do
            [[ -z "$worktree" ]] && continue
            log_decision "TRIAGE" "Agent dead, needs recovery" "$worktree"
            daemon_log "Decision: TRIAGE dead agent at $worktree"
            if [[ -x "$TRIAGE_SCRIPT" ]]; then
                "$TRIAGE_SCRIPT" "$worktree" 2>/dev/null || true
            fi
            decisions=$((decisions + 1))
        done <<<"$dead_agents"
    fi

    # 4. Check convoy progress
    if [[ -x "$CONVOY_SCRIPT" ]]; then
        local convoy_json
        convoy_json=$("$CONVOY_SCRIPT" list --json 2>/dev/null) || convoy_json="[]"

        echo "$convoy_json" | jq -r '
          .[] | select(
            (.summary.total // 0) > 0
            and (.summary.remaining // 0) == 0
            and (.summary.completed // 0) == (.summary.total // 0)
          ) | "COMPLETE:\(.id):\(.name)"
        ' 2>/dev/null | while IFS=: read -r status convoy_id convoy_name; do
            if [[ "$status" == "COMPLETE" ]]; then
                log_decision "CONVOY_COMPLETE" "All tickets in convoy complete" "$convoy_id"
                daemon_log "Decision: Convoy '$convoy_name' ($convoy_id) is complete"
                decisions=$((decisions + 1))
            fi
        done
    fi

    # 5. Check for idle agents when queue has items
    local idle_count=0
    if [[ -n "$idle_agents" ]]; then
        idle_count=$(echo "$idle_agents" | grep -c . 2>/dev/null) || idle_count=0
    fi

    if [[ "$idle_count" -gt 0 ]]; then
        # Check if ticket queue has items
        local queue_file="${HOME}/.claude/ticket-queue.json"
        if [[ -f "$queue_file" ]] && [[ -s "$queue_file" ]]; then
            local pending_tickets
            pending_tickets=$(jq '[.tickets // [] | .[] | select(.status == "pending")] | length' "$queue_file" 2>/dev/null) || pending_tickets=0

            if [[ "$pending_tickets" -gt 0 ]]; then
                log_decision "SUGGEST_DISPATCH" "$idle_count agents idle, $pending_tickets tickets queued" ""
                daemon_log "Decision: SUGGEST_DISPATCH - $idle_count idle agents, $pending_tickets pending tickets"
                decisions=$((decisions + 1))
            fi
        fi
    fi

    # 6. Check merge queue depth
    if [[ -x "$MERGE_QUEUE" ]]; then
        local queue_depth
        queue_depth=$("$MERGE_QUEUE" list 2>/dev/null | grep -c "pending" 2>/dev/null) || queue_depth=0
        if [[ "$queue_depth" -gt 3 ]]; then
            log_decision "WARN_QUEUE_DEPTH" "Merge queue has $queue_depth pending items" ""
            daemon_log "Decision: WARN - merge queue depth $queue_depth"
            decisions=$((decisions + 1))
        fi
    fi

    # 7. Detect repo conflicts (multiple agents on same repo)
    if [[ -n "$agents_json" && "$agents_json" != "[]" ]]; then
        local conflicts
        conflicts=$(echo "$agents_json" | jq -r '
          # Normalize: handle both list and dict formats
          (if type == "array" then . else [.[] | . as $v | $v] end)
          # Filter to running/idle agents, extract repo from parent dir of path
          | [.[] | select(.state == "running" or .state == "idle")
             | (.worktree // .path // "") as $p
             | ($p | split("/") | if length > 1 then .[-2] else "" end)
             | select(. != "")]
          # Group by repo name and count
          | group_by(.) | map({repo: .[0], count: length})
          | .[] | select(.count > 1) | "\(.repo):\(.count)"
        ' 2>/dev/null) || true

        if [[ -n "$conflicts" ]]; then
            while IFS=: read -r repo count; do
                log_decision "WARN_CONFLICT" "$count agents on same repo" "$repo"
                daemon_log "Decision: WARN - $count agents on repo $repo, potential conflicts"
                decisions=$((decisions + 1))
            done <<<"$conflicts"
        fi
    fi

    echo "$decisions"
}

# --- Commands ---

cmd_start() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    # Check for existing daemon
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo -e "${YELLOW}Mayor already running (PID $existing_pid)${NC}"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$MAYOR_LOG")"

    # Start daemon
    (
        trap 'rm -f "$PID_FILE"; daemon_log "Mayor stopped"' EXIT
        echo $BASHPID >"$PID_FILE"
        daemon_log "Mayor started (PID $BASHPID, poll ${POLL_INTERVAL}s)"

        # Patrol exponential backoff: back off when idle, reset when busy
        local patrol_sleep="$POLL_INTERVAL"
        local patrol_max_sleep=300
        while true; do
            local decisions
            decisions=$(decide_cycle 2>/dev/null) || decisions=0
            # Reset backoff when agents are actively working, even if no decisions needed
            local active_worktrees=0
            if [[ -x "$AGENT_STATE" ]]; then
                active_worktrees=$("$AGENT_STATE" --all --json 2>/dev/null |
                    jq '[.[] | select(.state != "completed" and .state != "none")] | length' 2>/dev/null) || active_worktrees=0
            fi
            if [[ "$decisions" -gt 0 || "$active_worktrees" -gt 0 ]]; then
                daemon_log "Cycle complete: $decisions decisions, $active_worktrees active worktrees"
                patrol_sleep="$POLL_INTERVAL" # Reset on activity
            else
                # Back off when nothing to do
                patrol_sleep=$((patrol_sleep * 2 > patrol_max_sleep ? patrol_max_sleep : patrol_sleep * 2))
            fi
            sleep "$patrol_sleep"
        done
    ) &
    disown

    echo -e "${GREEN}Mayor started${NC} (poll interval: ${POLL_INTERVAL}s)"
    echo "  Log: $MAYOR_LOG"
    echo "  Decisions: $LOG_FILE"
    echo "  Stop: gwt-mayor stop"
}

cmd_run() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$MAYOR_LOG")"

    trap 'rm -f "$PID_FILE"; daemon_log "Mayor stopped"; exit 0' INT TERM
    echo $$ >"$PID_FILE"
    daemon_log "Mayor started foreground (PID $$, poll ${POLL_INTERVAL}s)"

    # Patrol exponential backoff: back off when idle, reset when busy
    local patrol_sleep="$POLL_INTERVAL"
    local patrol_max_sleep=300
    while true; do
        local decisions
        decisions=$(decide_cycle 2>/dev/null) || decisions=0
        # Reset backoff when agents are actively working, even if no decisions needed
        local active_worktrees=0
        if [[ -x "$AGENT_STATE" ]]; then
            active_worktrees=$("$AGENT_STATE" --all --json 2>/dev/null |
                jq '[.[] | select(.state != "completed" and .state != "none")] | length' 2>/dev/null) || active_worktrees=0
        fi
        if [[ "$decisions" -gt 0 || "$active_worktrees" -gt 0 ]]; then
            daemon_log "Cycle complete: $decisions decisions, $active_worktrees active worktrees"
            patrol_sleep="$POLL_INTERVAL" # Reset on activity
        else
            patrol_sleep=$((patrol_sleep * 2 > patrol_max_sleep ? patrol_max_sleep : patrol_sleep * 2))
        fi
        sleep "$patrol_sleep"
    done
}

cmd_stop() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo -e "${GREEN}Mayor stopped${NC} (PID $pid)"
        else
            rm -f "$PID_FILE"
            echo "Mayor was not running (stale PID removed)"
        fi
    else
        echo "Mayor not running"
    fi
}

cmd_status() {
    local json_mode=false
    while [[ $# -gt 0 ]]; do
        case $1 in
        --json)
            json_mode=true
            shift
            ;;
        *) shift ;;
        esac
    done

    local running=false pid=""
    if [[ -f "$PID_FILE" ]]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            running=true
        fi
    fi

    # Get agent overview
    local agents_json="[]"
    if [[ -x "$AGENT_STATE" ]]; then
        agents_json=$("$AGENT_STATE" --all --json 2>/dev/null) || agents_json="[]"
    fi

    # Count states
    local state_counts
    state_counts=$(echo "$agents_json" | jq -r '
      # Normalize: handle both list and dict formats
      (if type == "array" then . else [.[] | . as $v | $v] end)
      | [.[] | .state // "unknown"]
      | group_by(.) | map({state: .[0], count: length})
      | sort_by(.state) | .[] | "\(.state):\(.count)"
    ' 2>/dev/null) || true

    # Recent decisions
    local recent_count=0
    if [[ -f "$LOG_FILE" ]]; then
        recent_count=$(wc -l <"$LOG_FILE" | tr -d ' ')
    fi

    if $json_mode; then
        local running_str="false"
        $running && running_str="true"
        # Build state_counts as JSON object from colon-separated lines
        local counts_json="{}"
        if [[ -n "$state_counts" ]]; then
            counts_json=$(echo "$state_counts" | jq -Rn '
              [inputs | select(length > 0) | split(":") | {(.[0]): (.[1] | tonumber)}]
              | add // {}
            ' 2>/dev/null) || counts_json="{}"
        fi
        jq -n \
            --argjson running "$running_str" \
            --arg pid "${pid:-}" \
            --argjson poll_interval "$POLL_INTERVAL" \
            --argjson total_decisions "$recent_count" \
            --argjson agents "$agents_json" \
            --argjson state_counts "$counts_json" \
            '{
              running: $running,
              pid: $pid,
              poll_interval: $poll_interval,
              total_decisions: $total_decisions,
              agents: $agents,
              state_counts: $state_counts
            }' 2>/dev/null
        return
    fi

    echo -e "${BLUE}=== Mayor Status ===${NC}"
    if $running; then
        echo -e "  Daemon:    ${GREEN}running${NC} (PID $pid)"
    else
        echo -e "  Daemon:    ${RED}not running${NC}"
    fi
    echo "  Poll:      ${POLL_INTERVAL}s"
    echo "  Decisions: $recent_count total"
    echo ""

    echo -e "${BOLD}Agent Overview:${NC}"
    if [[ -z "$state_counts" ]]; then
        echo "  No active agents"
    else
        while IFS=: read -r state count; do
            [[ -z "$state" ]] && continue
            local color="$NC"
            case "$state" in
            running) color="$GREEN" ;;
            stuck) color="$RED" ;;
            idle) color="$YELLOW" ;;
            dead) color="$RED" ;;
            completed) color="$GREEN" ;;
            esac
            echo -e "  ${color}${state}${NC}: ${count}"
        done <<<"$state_counts"
    fi
}

cmd_report() {
    echo -e "${BLUE}=== Mayor Report ===${NC}"
    echo ""

    # Agents
    echo -e "${BOLD}Agents:${NC}"
    if [[ -x "$AGENT_STATE" ]]; then
        "$AGENT_STATE" --all 2>/dev/null || echo "  No agents found"
    else
        echo "  agent-state.sh not found"
    fi
    echo ""

    # Convoys
    echo -e "${BOLD}Convoys:${NC}"
    if [[ -x "$CONVOY_SCRIPT" ]]; then
        "$CONVOY_SCRIPT" list --active 2>/dev/null || echo "  No active convoys"
    else
        echo "  convoy.sh not found"
    fi
    echo ""

    # Merge Queue
    echo -e "${BOLD}Merge Queue:${NC}"
    if [[ -x "$MERGE_QUEUE" ]]; then
        "$MERGE_QUEUE" list 2>/dev/null || echo "  Queue empty"
    else
        echo "  merge-queue.sh not found"
    fi
    echo ""

    # Recent Decisions
    echo -e "${BOLD}Recent Decisions (last 10):${NC}"
    if [[ -f "$LOG_FILE" ]] && [[ -s "$LOG_FILE" ]]; then
        tail -10 "$LOG_FILE" | while IFS= read -r line; do
            local action ts reason
            action=$(echo "$line" | jq -r '.action // ""' 2>/dev/null) || continue
            ts=$(echo "$line" | jq -r '.timestamp // ""' 2>/dev/null) || continue
            reason=$(echo "$line" | jq -r '.reason // ""' 2>/dev/null) || reason=""
            echo -e "  ${DIM}${ts}${NC}  ${BOLD}${action}${NC}: ${reason}"
        done
    else
        echo "  No decisions yet"
    fi
}

cmd_decide() {
    echo -e "${BLUE}Running decision cycle...${NC}"
    local decisions
    decisions=$(decide_cycle)
    echo "Made $decisions decision(s)"

    # Show recent decisions
    if [[ -f "$LOG_FILE" ]] && [[ "$decisions" -gt 0 ]]; then
        echo ""
        tail -"$decisions" "$LOG_FILE" | while IFS= read -r line; do
            local action reason target
            action=$(echo "$line" | jq -r '.action // ""' 2>/dev/null) || continue
            reason=$(echo "$line" | jq -r '.reason // ""' 2>/dev/null) || continue
            target=$(echo "$line" | jq -r '.target // ""' 2>/dev/null) || target=""
            echo -e "  ${BOLD}${action}${NC}: ${reason}"
            [[ -n "$target" ]] && echo -e "    target: ${target}"
        done
    fi
}

cmd_log() {
    local count="${1:-20}"

    if [[ ! -f "$LOG_FILE" ]] || [[ ! -s "$LOG_FILE" ]]; then
        echo "No decisions logged yet."
        return 0
    fi

    echo -e "${BLUE}=== Mayor Decision Log (last ${count}) ===${NC}"
    tail -"$count" "$LOG_FILE" | while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local action ts reason target
        action=$(echo "$line" | jq -r '.action // ""' 2>/dev/null) || continue
        ts=$(echo "$line" | jq -r '.timestamp // ""' 2>/dev/null) || continue
        reason=$(echo "$line" | jq -r '.reason // ""' 2>/dev/null) || reason=""
        target=$(echo "$line" | jq -r '.target // ""' 2>/dev/null) || target=""

        local color="$NC"
        case "$action" in
        TRIAGE) color="$YELLOW" ;;
        CONVOY_COMPLETE) color="$GREEN" ;;
        SUGGEST_DISPATCH) color="$BLUE" ;;
        WARN_*) color="$RED" ;;
        esac

        echo -e "  ${DIM}${ts}${NC}  ${color}${action}${NC}: ${reason}"
        [[ -n "$target" ]] && echo -e "    ${DIM}→ ${target}${NC}"
    done
}

# --- Main ---

show_help() {
    echo "gwt-mayor.sh - Global coordinator daemon (Mayor pattern)"
    echo ""
    echo "USAGE:"
    echo "  gwt-mayor.sh <command> [args...]"
    echo ""
    echo "COMMANDS:"
    echo "  start [--poll-interval N]  Start mayor daemon in background (default: 60s)"
    echo "  run [--poll-interval N]    Run mayor in foreground (for LaunchAgent)"
    echo "  stop                       Stop mayor daemon"
    echo "  status [--json]            Show mayor status + agent overview"
    echo "  report                     Generate full summary report"
    echo "  decide                     Run single decision cycle"
    echo "  log [N]                    Show recent decisions (default: 20)"
    echo ""
    echo "DECISION TYPES:"
    echo "  TRIAGE           - Stuck/dead agent detected, triage invoked"
    echo "  CONVOY_COMPLETE  - All tickets in convoy complete"
    echo "  SUGGEST_DISPATCH - Idle agents + queued tickets"
    echo "  WARN_CONFLICT    - Multiple agents on same repo"
    echo "  WARN_QUEUE_DEPTH - Merge queue growing large"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
start) cmd_start "$@" ;;
run) cmd_run "$@" ;;
stop) cmd_stop ;;
status) cmd_status "$@" ;;
report) cmd_report ;;
decide) cmd_decide ;;
log) cmd_log "${1:-20}" ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    exit 1
    ;;
esac
