#!/usr/bin/env bash
#
# worktree-witness.sh - Per-worktree agent lifecycle monitor
#
# Lightweight watcher that monitors a single agent's lifecycle in a worktree.
# Spawned by gwt-ticket, one witness per worktree.
#
# Monitors:
#   1. Ralph-loop progress (iteration counter advancing)
#   2. Stuck agent detection (iteration unchanged >10min)
#   3. Crash detection (claude process died but ticket still active)
#   4. Auto-retry on crash (restart with same prompt, up to N retries)
#   5. Completion detection → submit to merge queue or auto-merge
#
# Usage:
#   worktree-witness.sh <worktree-path> [options]
#   worktree-witness.sh stop <worktree-path>
#   worktree-witness.sh status <worktree-path>
#
# Options:
#   --poll-interval N   Seconds between checks (default: 30)
#   --max-retries N     Max crash recovery retries (default: 3)
#   --no-merge          Skip auto-merge on completion
#   --no-notify         Skip notifications
#   --foreground        Run in foreground (default: background)
#
# Exit codes:
#   0 - Agent completed successfully
#   1 - Error
#   2 - Max retries exceeded

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

POLL_INTERVAL=30
MAX_RETRIES=3
DO_MERGE=true
DO_NOTIFY=true
FOREGROUND=false
AUTO_CLEANUP=false
GRACE_PERIOD=3600 # 1 hour default
WORKTREE_PATH=""
COMMAND=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/json-helpers.sh"
AGENT_STATE="$SCRIPT_DIR/agent-state.sh"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    stop | status)
        COMMAND="$1"
        shift
        ;;
    --poll-interval)
        POLL_INTERVAL="$2"
        shift 2
        ;;
    --max-retries)
        MAX_RETRIES="$2"
        shift 2
        ;;
    --no-merge)
        DO_MERGE=false
        shift
        ;;
    --no-notify)
        DO_NOTIFY=false
        shift
        ;;
    --foreground)
        FOREGROUND=true
        shift
        ;;
    --auto-cleanup)
        AUTO_CLEANUP=true
        shift
        ;;
    --no-auto-cleanup)
        AUTO_CLEANUP=false
        shift
        ;;
    --grace-period)
        GRACE_PERIOD="$2"
        shift 2
        ;;
    --help | -h)
        echo "Usage: worktree-witness.sh <worktree-path> [options]"
        echo "       worktree-witness.sh stop <worktree-path>"
        echo "       worktree-witness.sh status <worktree-path>"
        echo ""
        echo "Per-worktree agent lifecycle monitor."
        echo ""
        echo "Options:"
        echo "  --poll-interval N   Check interval in seconds (default: 30)"
        echo "  --max-retries N     Crash recovery retries (default: 3)"
        echo "  --no-merge          Skip auto-merge on completion"
        echo "  --no-notify         Skip notifications"
        echo "  --foreground        Run in foreground"
        echo "  --auto-cleanup      Remove worktree after successful merge (with grace period)"
        echo "  --grace-period N    Seconds to wait before auto-cleanup (default: 3600)"
        exit 0
        ;;
    -*)
        echo -e "${RED}Error: Unknown option $1${NC}" >&2
        exit 1
        ;;
    *)
        WORKTREE_PATH="$1"
        shift
        ;;
    esac
done

if [[ -z "$WORKTREE_PATH" ]]; then
    echo -e "${RED}Error: worktree-path required${NC}" >&2
    exit 1
fi

# Resolve to absolute path
WORKTREE_PATH=$(cd "$WORKTREE_PATH" 2>/dev/null && pwd || echo "$WORKTREE_PATH")

PID_FILE="$WORKTREE_PATH/.claude/witness.pid"
WITNESS_STATE="$WORKTREE_PATH/.claude/witness.local.md"
TICKET_STATE="$WORKTREE_PATH/.claude/ticket-execute.local.md"
LOG_FILE="$WORKTREE_PATH/.claude/witness.log"

# Parse YAML value from a file
parse_yaml() {
    local key="$1" file="$2"
    grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}: *//" | tr -d '"'
}

# Log with timestamp
log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >>"$LOG_FILE"
}

# Send notification
notify() {
    local title="$1" msg="$2"
    $DO_NOTIFY || return 0

    if command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "$title" -message "$msg" -sound default 2>/dev/null || true
    elif command -v osascript &>/dev/null; then
        osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
    fi
}

# Handle stop command
if [[ "$COMMAND" == "stop" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        local_pid=$(cat "$PID_FILE")
        if kill -0 "$local_pid" 2>/dev/null; then
            kill "$local_pid"
            rm -f "$PID_FILE"
            echo "Witness stopped (PID $local_pid)"
        else
            rm -f "$PID_FILE"
            echo "Witness was not running (stale PID file removed)"
        fi
    else
        echo "No witness running for $WORKTREE_PATH"
    fi
    exit 0
fi

# Handle status command
if [[ "$COMMAND" == "status" ]]; then
    if [[ -f "$WITNESS_STATE" ]]; then
        echo -e "${BLUE}=== Witness Status ===${NC}"
        echo "Worktree: $WORKTREE_PATH"

        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo -e "Witness:  ${GREEN}running${NC} (PID $(cat "$PID_FILE"))"
        else
            echo -e "Witness:  ${RED}not running${NC}"
        fi

        local retries
        retries=$(parse_yaml "retries" "$WITNESS_STATE")
        echo "Retries:  ${retries:-0}/$MAX_RETRIES"

        if [[ -x "$AGENT_STATE" ]]; then
            local state_json
            state_json=$("$AGENT_STATE" "$WORKTREE_PATH" --json 2>/dev/null)
            local state
            state=$(json_val "state" "$state_json") || state="unknown"
            [[ -z "$state" ]] && state="unknown"
            echo "Agent:    $state"
        fi
    else
        echo "No witness state for $WORKTREE_PATH"
    fi
    exit 0
fi

# Validate
if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo -e "${RED}Error: Not a directory: $WORKTREE_PATH${NC}" >&2
    exit 1
fi

if [[ ! -f "$TICKET_STATE" ]]; then
    echo -e "${RED}Error: No active ticket in $WORKTREE_PATH${NC}" >&2
    exit 1
fi

if [[ ! -x "$AGENT_STATE" ]]; then
    echo -e "${RED}Error: agent-state.sh not found at $AGENT_STATE${NC}" >&2
    exit 1
fi

# Check for existing witness
if [[ -f "$PID_FILE" ]]; then
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo -e "${YELLOW}Witness already running (PID $existing_pid)${NC}"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

mkdir -p "$WORKTREE_PATH/.claude"

# Initialize witness state
issue_key=$(parse_yaml "issue_key" "$TICKET_STATE")
title=$(parse_yaml "title" "$TICKET_STATE")
tmux_session=$(parse_yaml "tmux_session" "$TICKET_STATE")
tmux_window=$(parse_yaml "tmux_window" "$TICKET_STATE")

max_iterations=$(parse_yaml "max_iterations" "$TICKET_STATE")

cat >"$WITNESS_STATE" <<EOF
---
active: true
worktree: "$WORKTREE_PATH"
issue_key: "$issue_key"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
retries: 0
max_retries: $MAX_RETRIES
last_state: "starting"
last_check: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
iterations_observed: 0
last_iteration: 0
---

# Witness Monitor

Monitoring agent execution for $issue_key in $WORKTREE_PATH.
EOF

# Write initial progress file
echo "{\"iteration\":0,\"max_iterations\":${max_iterations:-20},\"state\":\"starting\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >"$WORKTREE_PATH/.claude/progress.json"

# Main monitoring loop
monitor_loop() {
    trap 'cleanup' EXIT
    echo $BASHPID >"$PID_FILE"
    log "Witness started for $issue_key (PID $BASHPID)"

    local retries=0
    local last_state=""
    local consecutive_dead=0
    local last_observed_iteration=0
    local iterations_observed=0

    while true; do
        # Check for active gates — pause monitoring while gated
        local gates_script="$SCRIPT_DIR/phase-gates.sh"
        if [[ -x "$gates_script" ]] && "$gates_script" has-active "$WORKTREE_PATH" 2>/dev/null; then
            log "Gate active — pausing monitoring"
            # Try to resolve gate conditions
            "$gates_script" check ci-pipeline "$WORKTREE_PATH" 2>/dev/null || true
            "$gates_script" check pr-review "$WORKTREE_PATH" 2>/dev/null || true
            "$gates_script" check dependency "$WORKTREE_PATH" 2>/dev/null || true
            # human-input gates resolve via signal command only
            sleep "$POLL_INTERVAL"
            continue
        fi

        # Get current agent state
        local state_json
        state_json=$("$AGENT_STATE" "$WORKTREE_PATH" --json 2>/dev/null) || state_json='{"state":"unknown"}'

        local state
        state=$(json_val_default "state" "unknown" "$state_json")

        local iteration
        iteration=$(json_val_default "iteration" "0" "$state_json")

        # Track iteration progress
        local now_ts
        now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        if [[ "$iteration" != "0" && "$iteration" != "$last_observed_iteration" ]]; then
            iterations_observed=$((iterations_observed + 1))
            last_observed_iteration="$iteration"
            # Update progress file for gwt-status
            echo "{\"iteration\":$iteration,\"max_iterations\":${max_iterations:-20},\"state\":\"$state\",\"updated_at\":\"$now_ts\"}" >"$WORKTREE_PATH/.claude/progress.json"
        fi

        # Batch update witness state (single awk pass replaces 4 separate sed calls)
        awk -v iobs="$iterations_observed" -v liter="$iteration" -v lstate="$state" -v lcheck="$now_ts" '
            /^iterations_observed:/ { print "iterations_observed: " iobs; next }
            /^last_iteration:/ { print "last_iteration: " liter; next }
            /^last_state:/ { print "last_state: \"" lstate "\""; next }
            /^last_check:/ { print "last_check: \"" lcheck "\""; next }
            { print }
        ' "$WITNESS_STATE" >"${WITNESS_STATE}.tmp" && mv "${WITNESS_STATE}.tmp" "$WITNESS_STATE" 2>/dev/null || true

        # State transitions
        case "$state" in
        completed)
            log "Agent completed (iteration: $iteration)"
            notify "Agent Complete" "$issue_key: $title"
            # Log CV event
            local cv_script="$SCRIPT_DIR/agent-cv.sh"
            if [[ -x "$cv_script" ]]; then
                local started_at
                started_at=$(parse_yaml "started_at" "$WITNESS_STATE")
                local duration_s=0
                if [[ -n "$started_at" ]]; then
                    local start_epoch
                    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null) || start_epoch=0
                    if [[ "$start_epoch" -gt 0 ]]; then
                        duration_s=$(($(date +%s) - start_epoch))
                    fi
                fi
                "$cv_script" log "$WORKTREE_PATH" --event completed --detail "iteration=$iteration duration=${duration_s}s" 2>/dev/null || true
            fi
            # Send mail notification
            local mail_script="$SCRIPT_DIR/agent-mail.sh"
            if [[ -x "$mail_script" ]]; then
                "$mail_script" send all -s "Agent Complete: $issue_key" -m "$title completed at iteration $iteration" --from "witness-$(basename "$WORKTREE_PATH")" 2>/dev/null || true
            fi
            # Update progress file
            echo "{\"iteration\":$iteration,\"max_iterations\":${max_iterations:-20},\"state\":\"completed\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >"$WORKTREE_PATH/.claude/progress.json"
            on_completion
            break
            ;;

        dead)
            consecutive_dead=$((consecutive_dead + 1))
            # Wait for 2 consecutive dead readings to confirm (avoids race with startup)
            if [[ "$consecutive_dead" -ge 2 ]]; then
                local reason
                reason=$(json_val_default "reason" "unknown" "$state_json")
                log "Agent dead: $reason (retry $retries/$MAX_RETRIES)"

                # Log CV crash event
                local cv_script="$SCRIPT_DIR/agent-cv.sh"
                if [[ -x "$cv_script" ]]; then
                    "$cv_script" log "$WORKTREE_PATH" --event crash --detail "reason=$reason retry=$retries/$MAX_RETRIES" 2>/dev/null || true
                fi

                if [[ "$retries" -lt "$MAX_RETRIES" ]]; then
                    retries=$((retries + 1))
                    sed -i '' "s/^retries:.*/retries: $retries/" "$WITNESS_STATE" 2>/dev/null || true
                    notify "Agent Crashed" "$issue_key: Attempting retry $retries/$MAX_RETRIES"
                    on_crash_retry "$retries"
                    consecutive_dead=0
                    sleep 10 # Give restart time to initialize
                else
                    log "Max retries exceeded"
                    notify "Agent Failed" "$issue_key: Max retries ($MAX_RETRIES) exceeded"
                    if [[ -x "$cv_script" ]]; then
                        "$cv_script" log "$WORKTREE_PATH" --event failed --detail "max retries ($MAX_RETRIES) exceeded" 2>/dev/null || true
                    fi
                    # Convoy: mark ticket failed
                    local fail_convoy_id
                    fail_convoy_id=$(parse_yaml "convoy_id" "$TICKET_STATE")
                    if [[ -n "$fail_convoy_id" ]]; then
                        local convoy_script="$SCRIPT_DIR/convoy.sh"
                        if [[ -x "$convoy_script" ]]; then
                            "$convoy_script" fail "$fail_convoy_id" "$issue_key" --reason "max retries exceeded" 2>/dev/null || true
                        fi
                    fi
                    # Molecule: mark current step failed
                    local fail_molecule_id
                    fail_molecule_id=$(parse_yaml "molecule_id" "$TICKET_STATE")
                    if [[ -n "$fail_molecule_id" ]]; then
                        local molecule_script="$SCRIPT_DIR/molecule.sh"
                        if [[ -x "$molecule_script" ]]; then
                            "$molecule_script" fail "$fail_molecule_id" --reason "max retries exceeded" 2>/dev/null || true
                        fi
                    fi
                    # Send failure mail
                    local mail_script="$SCRIPT_DIR/agent-mail.sh"
                    if [[ -x "$mail_script" ]]; then
                        "$mail_script" send all -s "Agent Failed: $issue_key" -m "$title failed after $MAX_RETRIES retries" --from "witness-$(basename "$WORKTREE_PATH")" 2>/dev/null || true
                    fi
                    sed -i '' 's/^active: true/active: false/' "$WITNESS_STATE" 2>/dev/null || true
                    exit 2
                fi
            fi
            ;;

        stuck)
            if [[ "$last_state" != "stuck" ]]; then
                local stuck_for
                stuck_for=$(json_val "stuck_for" "$state_json")
                [[ -z "$stuck_for" ]] && stuck_for="?"
                local minutes=$((${stuck_for:-0} / 60))
                log "Agent stuck on iteration $iteration for ${minutes}m"
                notify "Agent Stuck" "$issue_key: Stuck on iteration $iteration for ${minutes}m"

                # Log CV stuck event
                local cv_script="$SCRIPT_DIR/agent-cv.sh"
                if [[ -x "$cv_script" ]]; then
                    "$cv_script" log "$WORKTREE_PATH" --event stuck --detail "iteration=$iteration stuck_for=${minutes}m" 2>/dev/null || true
                fi

                # Call triage if available
                local triage_script="$SCRIPT_DIR/agent-triage.sh"
                if [[ -x "$triage_script" ]]; then
                    log "Calling triage..."
                    "$triage_script" "$WORKTREE_PATH" 2>/dev/null || true
                fi
            fi
            ;;

        running | idle)
            consecutive_dead=0
            ;;

        none)
            # Ticket state file removed
            log "Ticket state removed, exiting"
            break
            ;;
        esac

        last_state="$state"
        sleep "$POLL_INTERVAL"
    done
}

# Handle agent completion
on_completion() {
    log "Running post-completion actions"

    # Sync beads agent memory before merge and close the bead
    if command -v bd &>/dev/null && [[ -d "$WORKTREE_PATH/.beads" ]]; then
        log "Syncing beads state"
        (cd "$WORKTREE_PATH" && bd sync 2>/dev/null) || true
        # Close the bead for this issue
        if [[ -n "$issue_key" ]]; then
            (cd "$WORKTREE_PATH" && bd close "$issue_key" 2>/dev/null) || true
        fi
    fi

    # Convoy: mark ticket complete in convoy
    local convoy_id
    convoy_id=$(parse_yaml "convoy_id" "$TICKET_STATE")
    if [[ -n "$convoy_id" ]]; then
        local convoy_script="$SCRIPT_DIR/convoy.sh"
        if [[ -x "$convoy_script" ]]; then
            log "Marking $issue_key complete in convoy $convoy_id"
            "$convoy_script" complete "$convoy_id" "$issue_key" 2>/dev/null || true
        fi
    fi

    # Molecule: advance to next step
    local molecule_id
    molecule_id=$(parse_yaml "molecule_id" "$TICKET_STATE")
    if [[ -n "$molecule_id" ]]; then
        local molecule_script="$SCRIPT_DIR/molecule.sh"
        if [[ -x "$molecule_script" ]]; then
            log "Advancing molecule $molecule_id"
            local mol_exit=0
            "$molecule_script" advance "$molecule_id" 2>/dev/null || mol_exit=$?
            if [[ "$mol_exit" -eq 2 ]]; then
                log "Molecule $molecule_id complete (all steps done)"
                local mail_script_mol="$SCRIPT_DIR/agent-mail.sh"
                if [[ -x "$mail_script_mol" ]]; then
                    "$mail_script_mol" send all -s "Molecule complete: $molecule_id" -m "All steps finished for $issue_key" --from "witness-$(basename "$WORKTREE_PATH")" 2>/dev/null || true
                fi
            elif [[ "$mol_exit" -eq 0 ]]; then
                # More steps remain - send mail with next step info
                local next_step
                next_step=$("$molecule_script" resume "$molecule_id" 2>/dev/null | head -5) || true
                local mail_script_mol="$SCRIPT_DIR/agent-mail.sh"
                if [[ -x "$mail_script_mol" ]]; then
                    "$mail_script_mol" send all -s "Molecule $molecule_id: next step" -m "Next: $next_step" --from "witness-$(basename "$WORKTREE_PATH")" 2>/dev/null || true
                fi
            fi
        fi
    fi

    # Town beads: sync to cross-project memory
    local town_sync
    town_sync=$(parse_yaml "town_sync" "$TICKET_STATE")
    if [[ "$town_sync" == "true" ]]; then
        local town_script="$SCRIPT_DIR/town-beads.sh"
        if [[ -x "$town_script" ]]; then
            log "Syncing town bead for $issue_key"
            "$town_script" sync "$issue_key" --from "$WORKTREE_PATH" 2>/dev/null || true
        fi
    fi

    # Restore OpenClaw sandbox defaults after devcontainer session
    local sandbox_script="$SCRIPT_DIR/openclaw/sandbox-profile.sh"
    if [[ -x "$sandbox_script" ]]; then
        "$sandbox_script" default 2>/dev/null || true
    fi

    local merge_exit=0
    if $DO_MERGE; then
        # Check if merge-queue daemon is running
        local merge_queue="$SCRIPT_DIR/merge-queue.sh"
        if [[ -x "$merge_queue" ]] && [[ -f "/tmp/merge-queue-daemon.pid" ]] && kill -0 "$(cat /tmp/merge-queue-daemon.pid)" 2>/dev/null; then
            log "Submitting to merge queue"
            "$merge_queue" add "$WORKTREE_PATH" 2>/dev/null || {
                log "Merge queue submission failed, falling back to direct merge"
                "$SCRIPT_DIR/auto-merge.sh" "$WORKTREE_PATH" --open-diffview "${tmux_session}:${tmux_window}" 2>/dev/null || merge_exit=$?
            }
        else
            log "Direct auto-merge (no queue daemon)"
            "$SCRIPT_DIR/auto-merge.sh" "$WORKTREE_PATH" --open-diffview "${tmux_session}:${tmux_window}" 2>/dev/null || merge_exit=$?
        fi

        # Handle merge conflicts — auto-merge.sh handles DiffviewOpen via --open-diffview
        if [[ "$merge_exit" -eq 2 ]]; then
            log "Merge conflicts detected (auto-merge handles DiffviewOpen)"
            notify "Merge Conflict" "$issue_key: Non-additive conflicts need resolution"
        fi
    fi

    # Run ticket-complete for PR creation and ticket transition
    local ticket_complete="$SCRIPT_DIR/ticket-complete.sh"
    if [[ -x "$ticket_complete" ]]; then
        log "Running ticket-complete"
        "$ticket_complete" "$WORKTREE_PATH" 2>/dev/null || {
            log "ticket-complete failed (exit $?)"
        }
    fi

    # Log CV merge event and archive CV
    local cv_script="$SCRIPT_DIR/agent-cv.sh"
    if [[ -x "$cv_script" ]]; then
        if [[ "$merge_exit" -eq 0 ]]; then
            "$cv_script" log "$WORKTREE_PATH" --event merged --detail "merge_exit=$merge_exit" 2>/dev/null || true
        fi
        # Archive CV to permanent storage
        local cv_file="$WORKTREE_PATH/.claude/worker-cv.jsonl"
        if [[ -f "$cv_file" && -n "$issue_key" ]]; then
            mkdir -p "$HOME/.claude/agent-cvs"
            cp "$cv_file" "$HOME/.claude/agent-cvs/${issue_key}.jsonl" 2>/dev/null || true
            log "CV archived to ~/.claude/agent-cvs/${issue_key}.jsonl"
        fi
    fi

    # Mark witness as done
    sed -i '' 's/^active: true/active: false/' "$WITNESS_STATE" 2>/dev/null || true

    # Self-nuke: remove worktree after grace period if auto-cleanup enabled
    if $AUTO_CLEANUP; then
        self_nuke &
        disown
    fi
}

# Self-nuke: wait grace period then remove worktree and kill tmux session
self_nuke() {
    log "Self-nuke scheduled in ${GRACE_PERIOD}s"
    sleep "$GRACE_PERIOD"

    # Verify the branch was actually merged before nuking
    local branch
    branch=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null) || return 1
    local repo_root
    local git_common_dir
    git_common_dir=$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir 2>/dev/null) || return 1
    repo_root=$(cd "$WORKTREE_PATH" && cd "$git_common_dir/.." && pwd)

    # Check if branch is merged into main
    if ! git -C "$repo_root" branch --merged main 2>/dev/null | grep -q "$branch"; then
        log "Self-nuke aborted: $branch not merged into main"
        return 1
    fi

    log "Self-nuke executing: removing worktree $WORKTREE_PATH"

    # Remove worktree
    git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || {
        log "Self-nuke: git worktree remove failed, trying rm"
        rm -rf "$WORKTREE_PATH" 2>/dev/null || true
        git -C "$repo_root" worktree prune 2>/dev/null || true
    }

    # Kill tmux window if it still exists
    if [[ -n "${tmux_session:-}" && -n "${tmux_window:-}" ]]; then
        tmux kill-window -t "${tmux_session}:${tmux_window}" 2>/dev/null || true
    fi

    # Clean up witness state files
    rm -f "$PID_FILE" "$WITNESS_STATE" 2>/dev/null || true

    log "Self-nuke complete"
}

# Handle crash recovery
on_crash_retry() {
    local retry_num="$1"
    log "Crash recovery attempt $retry_num"

    # Get the launch script from ticket state
    local launch_script="$WORKTREE_PATH/.claude/ticket-execute.local.md"
    if [[ ! -f "$launch_script" ]]; then
        log "No ticket state file for recovery"
        return 1
    fi

    # Find the tmux target
    local session window
    session=$(parse_yaml "tmux_session" "$TICKET_STATE")
    window=$(parse_yaml "tmux_window" "$TICKET_STATE")

    if [[ -z "$session" || -z "$window" ]]; then
        log "No tmux target in ticket state"
        return 1
    fi

    # Check if tmux window still exists
    if ! tmux has-session -t "$session" 2>/dev/null; then
        log "Tmux session $session no longer exists"
        return 1
    fi

    # Find the launch script
    local instance_env="$HOME/.devcontainer/instances/$(basename "$WORKTREE_PATH")/env"
    local fish_launch="$instance_env/launch-claude.fish"
    local local_launch="$WORKTREE_PATH/.claude/start-claude-pane.fish"

    if [[ -f "$local_launch" ]]; then
        log "Restarting via $local_launch"
        # Find an empty pane or the claude pane (leftmost typically)
        tmux send-keys -t "${session}:${window}.0" "fish $local_launch" Enter 2>/dev/null || {
            log "Failed to restart in tmux pane"
            return 1
        }
    elif [[ -f "$fish_launch" ]]; then
        log "Restarting via $fish_launch (local mode)"
        tmux send-keys -t "${session}:${window}.0" "fish $fish_launch" Enter 2>/dev/null || {
            log "Failed to restart in tmux pane"
            return 1
        }
    else
        log "No launch script found for recovery"
        return 1
    fi

    log "Restart command sent"
    return 0
}

# Cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
    log "Witness exiting"
}

# Run
if $FOREGROUND; then
    echo -e "${BLUE}Witness starting for $issue_key${NC} (foreground)"
    echo "  Worktree: $WORKTREE_PATH"
    echo "  Poll:     ${POLL_INTERVAL}s"
    echo "  Retries:  $MAX_RETRIES"
    echo ""
    monitor_loop
else
    # Background mode
    monitor_loop &
    disown
    echo "Witness started for $issue_key (PID $!)"
    echo "  Log: $LOG_FILE"
    echo "  Status: worktree-witness.sh status $WORKTREE_PATH"
    echo "  Stop: worktree-witness.sh stop $WORKTREE_PATH"
fi
