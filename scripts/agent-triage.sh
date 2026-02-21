#!/usr/bin/env bash
#
# agent-triage.sh - Intelligent agent restart decisions
#
# When worktree-witness or a human detects an agent problem, triage decides
# WHAT to do. Uses agent-state.sh for ground truth, then applies a decision
# matrix with retry limits to prevent infinite recovery loops.
#
# Decision matrix:
#   dead   + ticket active → START  (crash recovery)
#   idle   + >5 minutes    → WAKE   (send keystroke to tmux pane)
#   stuck  + iteration unchanged → NUDGE (kill claude, restart with continue prompt)
#   running/completed/none → NOTHING
#
# Usage:
#   agent-triage.sh <worktree-path>              # Assess and act
#   agent-triage.sh <worktree-path> --dry-run    # Assess only, don't act
#   agent-triage.sh <worktree-path> --json       # Output decision as JSON
#
# Exit codes:
#   0 - Decision made and executed (or dry-run)
#   1 - Error (bad args, missing dependencies)
#   2 - Retry limit exceeded

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/json-helpers.sh"
AGENT_STATE="$SCRIPT_DIR/agent-state.sh"

# Retry limits
MAX_START_RETRIES=3
MAX_NUDGE_RETRIES=2
MAX_WAKE_RETRIES=5

# Idle threshold before WAKE action (seconds)
IDLE_THRESHOLD="${IDLE_THRESHOLD:-300}" # 5 minutes

# Log file
TRIAGE_LOG="${TRIAGE_LOG:-$HOME/.claude/triage-log.jsonl}"

DRY_RUN=false
JSON_OUTPUT=false
ALL_MODE=false
QUIET=false
AI_TRIAGE=false
WORKTREE_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --json)
        JSON_OUTPUT=true
        shift
        ;;
    --all)
        ALL_MODE=true
        shift
        ;;
    --quiet)
        QUIET=true
        shift
        ;;
    --ai-triage)
        AI_TRIAGE=true
        shift
        ;;
    --help | -h)
        echo "Usage: agent-triage.sh <worktree-path> [--dry-run] [--json]"
        echo "       agent-triage.sh --all [--quiet] [--dry-run] [--json]"
        echo ""
        echo "Intelligent agent restart decisions."
        echo ""
        echo "Options:"
        echo "  --dry-run     Assess only, don't execute actions"
        echo "  --json        Output decision as JSON"
        echo "  --all         Triage all active worktrees"
        echo "  --quiet       Suppress output when action is NOTHING (useful for cron)"
        echo "  --ai-triage   Use Claude AI for triage decisions instead of heuristics"
        echo "  --help        Show this help"
        echo ""
        echo "Actions:"
        echo "  START    Restart dead agent (crash recovery)"
        echo "  WAKE     Send keystroke to idle agent"
        echo "  NUDGE    Kill and restart stuck agent"
        echo "  NOTHING  No action needed"
        exit 0
        ;;
    -*)
        echo "Error: Unknown option $1" >&2
        exit 1
        ;;
    *)
        WORKTREE_PATH="$1"
        shift
        ;;
    esac
done

if [[ -z "$WORKTREE_PATH" ]] && ! $ALL_MODE; then
    echo "Error: worktree-path required (or use --all)" >&2
    echo "Usage: agent-triage.sh <worktree-path> [--dry-run] [--json]" >&2
    exit 1
fi

# Resolve to absolute path
WORKTREE_PATH=$(cd "$WORKTREE_PATH" 2>/dev/null && pwd || echo "$WORKTREE_PATH")

if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo "Error: Not a directory: $WORKTREE_PATH" >&2
    exit 1
fi

if [[ ! -x "$AGENT_STATE" ]]; then
    echo "Error: agent-state.sh not found at $AGENT_STATE" >&2
    exit 1
fi

RETRY_FILE="$WORKTREE_PATH/.claude/triage-retries.json"

# --- Helper functions ---
# json_val is provided by lib/json-helpers.sh (jq-based, <5ms vs python3's 30-50ms)

# Read retry counters (creates file if missing)
read_retries() {
    if [[ -f "$RETRY_FILE" ]]; then
        cat "$RETRY_FILE"
    else
        echo '{"start_count":0,"nudge_count":0,"wake_count":0,"last_action":"","last_iteration":""}'
    fi
}

# Write retry counters
write_retries() {
    local json="$1"
    mkdir -p "$(dirname "$RETRY_FILE")"
    echo "$json" >"$RETRY_FILE"
}

# Increment a counter in the retry file
increment_retry() {
    local counter="$1"
    local retries
    retries=$(read_retries)

    local current
    current=$(json_val "$counter" "$retries")
    current=${current:-0}
    local new_val=$((current + 1))

    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Rebuild JSON with updated counter
    local start_count nudge_count wake_count last_iteration
    start_count=$(json_val "start_count" "$retries")
    nudge_count=$(json_val "nudge_count" "$retries")
    wake_count=$(json_val "wake_count" "$retries")
    last_iteration=$(json_val "last_iteration" "$retries")

    case "$counter" in
    start_count) start_count=$new_val ;;
    nudge_count) nudge_count=$new_val ;;
    wake_count) wake_count=$new_val ;;
    esac

    write_retries "{\"start_count\":${start_count:-0},\"nudge_count\":${nudge_count:-0},\"wake_count\":${wake_count:-0},\"last_action\":\"$now\",\"last_iteration\":\"$last_iteration\"}"
}

# Reset counters when iteration advances
maybe_reset_retries() {
    local current_iteration="$1"
    local retries
    retries=$(read_retries)

    local saved_iteration
    saved_iteration=$(json_val "last_iteration" "$retries")

    if [[ -n "$current_iteration" && "$current_iteration" != "0" && "$current_iteration" != "$saved_iteration" ]]; then
        # Iteration advanced — reset all counters
        local now
        now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        write_retries "{\"start_count\":0,\"nudge_count\":0,\"wake_count\":0,\"last_action\":\"$now\",\"last_iteration\":\"$current_iteration\"}"
    fi
}

# Append to JSONL triage log
log_decision() {
    local action="$1" reason="$2" executed="$3"
    mkdir -p "$(dirname "$TRIAGE_LOG")"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{\"timestamp\":\"$now\",\"worktree\":\"$WORKTREE_PATH\",\"action\":\"$action\",\"reason\":\"$reason\",\"executed\":$executed}" >>"$TRIAGE_LOG"
}

# Output the decision result
output_result() {
    local action="$1" reason="$2" state="$3" executed="$4"
    # --quiet suppresses NOTHING output entirely
    if $QUIET && [[ "$action" == "NOTHING" ]]; then
        return 0
    fi
    if $JSON_OUTPUT; then
        echo "{\"action\":\"$action\",\"reason\":\"$reason\",\"worktree\":\"$WORKTREE_PATH\",\"state\":\"$state\",\"executed\":$executed}"
    elif [[ "$action" != "NOTHING" ]]; then
        local prefix="[triage]"
        if $DRY_RUN; then prefix="[triage/dry-run]"; fi
        echo "$prefix $action: $reason"
    fi
}

# Parse YAML value from state file
parse_yaml() {
    local key="$1" file="$2"
    grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}: *//" | tr -d '"'
}

# --- Action implementations ---

# Find launch script for restarting agent
find_launch_script() {
    local local_launch="$WORKTREE_PATH/.claude/start-claude-pane.fish"
    if [[ -f "$local_launch" ]]; then
        echo "$local_launch"
        return 0
    fi

    local wt_name
    wt_name=$(basename "$WORKTREE_PATH")
    local instance_launch="$HOME/.devcontainer/instances/$wt_name/env/launch-claude.fish"
    if [[ -f "$instance_launch" ]]; then
        echo "$instance_launch"
        return 0
    fi

    return 1
}

# Get tmux target from agent state or ticket state
get_tmux_target() {
    local state_json="$1"
    local target
    target=$(json_val "tmux" "$state_json")

    if [[ -z "$target" ]]; then
        # Fallback to ticket state file
        local ticket_file="$WORKTREE_PATH/.claude/ticket-execute.local.md"
        if [[ -f "$ticket_file" ]]; then
            local session window
            session=$(parse_yaml "tmux_session" "$ticket_file")
            window=$(parse_yaml "tmux_window" "$ticket_file")
            if [[ -n "$session" && -n "$window" ]]; then
                target="${session}:${window}"
            fi
        fi
    fi

    echo "$target"
}

# START: restart a dead agent
action_start() {
    local state_json="$1"
    local target
    target=$(get_tmux_target "$state_json")

    if [[ -z "$target" ]]; then
        log_decision "START" "failed: no tmux target" false
        return 1
    fi

    local session="${target%%:*}"
    if ! tmux has-session -t "$session" 2>/dev/null; then
        log_decision "START" "failed: tmux session gone" false
        return 1
    fi

    local launch_script
    launch_script=$(find_launch_script) || {
        log_decision "START" "failed: no launch script" false
        return 1
    }

    tmux send-keys -t "${target}.0" "fish $launch_script" Enter 2>/dev/null || {
        log_decision "START" "failed: tmux send-keys failed" false
        return 1
    }

    increment_retry "start_count"
    return 0
}

# WAKE: send keystroke to idle agent
action_wake() {
    local state_json="$1"
    local target
    target=$(get_tmux_target "$state_json")

    if [[ -z "$target" ]]; then
        log_decision "WAKE" "failed: no tmux target" false
        return 1
    fi

    # Send empty Enter to wake up
    tmux send-keys -t "${target}.0" "" Enter 2>/dev/null || {
        log_decision "WAKE" "failed: tmux send-keys failed" false
        return 1
    }

    increment_retry "wake_count"
    return 0
}

# NUDGE: kill stuck claude and restart with continuation prompt
action_nudge() {
    local state_json="$1"

    local pid
    pid=$(json_val "pid" "$state_json")
    local target
    target=$(get_tmux_target "$state_json")

    if [[ -z "$target" ]]; then
        log_decision "NUDGE" "failed: no tmux target" false
        return 1
    fi

    # Kill the stuck claude process
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        sleep 2
    fi

    # Restart with a continuation prompt via claude --continue
    local session="${target%%:*}"
    if ! tmux has-session -t "$session" 2>/dev/null; then
        log_decision "NUDGE" "failed: tmux session gone after kill" false
        return 1
    fi

    # Use --continue flag so claude picks up where it left off
    local launch_script
    launch_script=$(find_launch_script) || {
        # Fallback: start claude directly with --continue in the worktree
        tmux send-keys -t "${target}.0" "cd $WORKTREE_PATH && claude --continue" Enter 2>/dev/null || {
            log_decision "NUDGE" "failed: fallback restart failed" false
            return 1
        }
        increment_retry "nudge_count"
        return 0
    }

    tmux send-keys -t "${target}.0" "fish $launch_script" Enter 2>/dev/null || {
        log_decision "NUDGE" "failed: tmux send-keys failed" false
        return 1
    }

    increment_retry "nudge_count"
    return 0
}

# --- Main decision logic ---

# Get current agent state
STATE_JSON=$("$AGENT_STATE" "$WORKTREE_PATH" --json 2>/dev/null) || {
    echo "Error: Failed to get agent state" >&2
    exit 1
}

STATE=$(json_val "state" "$STATE_JSON")
ITERATION=$(json_val "iteration" "$STATE_JSON")

# Reset retry counters if iteration has advanced
maybe_reset_retries "$ITERATION"

# Read current retry counts
RETRIES=$(read_retries)
START_COUNT=$(json_val "start_count" "$RETRIES")
NUDGE_COUNT=$(json_val "nudge_count" "$RETRIES")
WAKE_COUNT=$(json_val "wake_count" "$RETRIES")
START_COUNT=${START_COUNT:-0}
NUDGE_COUNT=${NUDGE_COUNT:-0}
WAKE_COUNT=${WAKE_COUNT:-0}

case "$STATE" in
dead)
    REASON="agent dead: $(json_val "reason" "$STATE_JSON")"

    if [[ "$START_COUNT" -ge "$MAX_START_RETRIES" ]]; then
        log_decision "START" "retry limit ($MAX_START_RETRIES) exceeded" false
        output_result "START" "retry limit exceeded ($START_COUNT/$MAX_START_RETRIES)" "$STATE" false
        exit 2
    fi

    if $DRY_RUN; then
        log_decision "START" "$REASON (dry-run)" false
        output_result "START" "$REASON" "$STATE" false
    else
        if action_start "$STATE_JSON"; then
            log_decision "START" "$REASON" true
            output_result "START" "$REASON" "$STATE" true
        else
            output_result "START" "$REASON (action failed)" "$STATE" false
        fi
    fi
    ;;

idle)
    # Check how long idle — we use the stuck_for field if available,
    # otherwise approximate from the iteration tracking file
    IDLE_FOR=""
    ITERATION_FILE="/tmp/tmux-claude-state/ralph-iter-$(echo "$WORKTREE_PATH" | tr '/' '-')"
    if [[ -f "$ITERATION_FILE" ]]; then
        SAVED_TS=$(cut -d: -f2 "$ITERATION_FILE" 2>/dev/null) || SAVED_TS=""
        if [[ -n "$SAVED_TS" ]]; then
            NOW=$(date +%s)
            IDLE_FOR=$((NOW - SAVED_TS))
        fi
    fi

    if [[ -n "$IDLE_FOR" && "$IDLE_FOR" -gt "$IDLE_THRESHOLD" ]]; then
        IDLE_MINUTES=$((IDLE_FOR / 60))
        REASON="idle for ${IDLE_MINUTES}m (threshold: $((IDLE_THRESHOLD / 60))m)"

        if [[ "$WAKE_COUNT" -ge "$MAX_WAKE_RETRIES" ]]; then
            # Escalate to NUDGE after too many failed wakes
            if [[ "$NUDGE_COUNT" -ge "$MAX_NUDGE_RETRIES" ]]; then
                log_decision "NUDGE" "wake+nudge retry limits exceeded" false
                output_result "NUDGE" "retry limits exceeded (wake: $WAKE_COUNT/$MAX_WAKE_RETRIES, nudge: $NUDGE_COUNT/$MAX_NUDGE_RETRIES)" "$STATE" false
                exit 2
            fi

            REASON="idle for ${IDLE_MINUTES}m, wake failed $WAKE_COUNT times — escalating to NUDGE"
            if $DRY_RUN; then
                log_decision "NUDGE" "$REASON (dry-run)" false
                output_result "NUDGE" "$REASON" "$STATE" false
            else
                if action_nudge "$STATE_JSON"; then
                    log_decision "NUDGE" "$REASON" true
                    output_result "NUDGE" "$REASON" "$STATE" true
                else
                    output_result "NUDGE" "$REASON (action failed)" "$STATE" false
                fi
            fi
        else
            if $DRY_RUN; then
                log_decision "WAKE" "$REASON (dry-run)" false
                output_result "WAKE" "$REASON" "$STATE" false
            else
                if action_wake "$STATE_JSON"; then
                    log_decision "WAKE" "$REASON" true
                    output_result "WAKE" "$REASON" "$STATE" true
                else
                    output_result "WAKE" "$REASON (action failed)" "$STATE" false
                fi
            fi
        fi
    else
        output_result "NOTHING" "idle but within threshold" "$STATE" false
    fi
    ;;

stuck)
    STUCK_FOR=$(json_val "stuck_for" "$STATE_JSON")
    STUCK_MINUTES=$((${STUCK_FOR:-0} / 60))
    REASON="stuck on iteration $ITERATION for ${STUCK_MINUTES}m"

    if [[ "$NUDGE_COUNT" -ge "$MAX_NUDGE_RETRIES" ]]; then
        log_decision "NUDGE" "retry limit ($MAX_NUDGE_RETRIES) exceeded" false
        output_result "NUDGE" "retry limit exceeded ($NUDGE_COUNT/$MAX_NUDGE_RETRIES)" "$STATE" false
        exit 2
    fi

    if $DRY_RUN; then
        log_decision "NUDGE" "$REASON (dry-run)" false
        output_result "NUDGE" "$REASON" "$STATE" false
    else
        if action_nudge "$STATE_JSON"; then
            log_decision "NUDGE" "$REASON" true
            output_result "NUDGE" "$REASON" "$STATE" true
        else
            output_result "NUDGE" "$REASON (action failed)" "$STATE" false
        fi
    fi
    ;;

running | completed | none | *)
    output_result "NOTHING" "state is $STATE" "$STATE" false
    ;;
esac
