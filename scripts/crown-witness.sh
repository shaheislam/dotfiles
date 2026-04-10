#!/usr/bin/env bash
#
# crown-witness.sh - Barrier + trigger for crown tournament evaluation
#
# Waits for all N contestants to finish, then triggers crown-evaluate.sh
# to compare their implementations and pick a winner.
#
# Usage:
#   crown-witness.sh <crown-dir> [options]
#
# Options:
#   --count N           Number of contestants to wait for
#   --poll-interval N   Seconds between checks (default: 30)
#   --timeout N         Max wait in seconds (default: 7200 = 2hrs)
#   --judge PRESET      Passed through to crown-evaluate.sh (default: council)
#   --base BRANCH       Passed through to crown-evaluate.sh (default: main)
#   --repo PATH         Repository path (default: auto-detect from first branch)
#   --foreground        Run in foreground (default: background)
#   --no-notify         Skip notifications
#   --no-cleanup        Skip cleanup of losing worktrees
#
# Exit codes:
#   0 - Winner determined and submitted
#   1 - Error
#   2 - Timeout waiting for contestants
#   3 - All contestants failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/json-helpers.sh"

# Defaults
CROWN_DIR=""
CONTESTANT_COUNT=0
POLL_INTERVAL=30
TIMEOUT=7200
JUDGE_PRESET="council"
BASE_BRANCH="main"
REPO_PATH=""
FOREGROUND=false
DO_NOTIFY=true
DO_CLEANUP=true

# Colors
RED='\033[0;31m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --count)
        CONTESTANT_COUNT="$2"
        shift 2
        ;;
    --poll-interval)
        POLL_INTERVAL="$2"
        shift 2
        ;;
    --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
    --judge)
        JUDGE_PRESET="$2"
        shift 2
        ;;
    --base)
        BASE_BRANCH="$2"
        shift 2
        ;;
    --repo)
        REPO_PATH="$2"
        shift 2
        ;;
    --foreground)
        FOREGROUND=true
        shift
        ;;
    --no-notify)
        DO_NOTIFY=false
        shift
        ;;
    --no-cleanup)
        DO_CLEANUP=false
        shift
        ;;
    --help | -h)
        echo "Usage: crown-witness.sh <crown-dir> [options]"
        echo ""
        echo "Wait for N contestants to finish, then trigger crown evaluation."
        echo ""
        echo "Options:"
        echo "  --count N           Number of contestants to wait for"
        echo "  --poll-interval N   Seconds between checks (default: 30)"
        echo "  --timeout N         Max wait in seconds (default: 7200)"
        echo "  --judge PRESET      Judge mode: council|review|redteam (default: council)"
        echo "  --base BRANCH       Base branch for diffs (default: main)"
        echo "  --repo PATH         Repository path"
        echo "  --foreground        Run in foreground"
        echo "  --no-notify         Skip notifications"
        echo "  --no-cleanup        Skip cleanup of losing worktrees"
        exit 0
        ;;
    -*)
        echo -e "${RED}Error: Unknown option $1${NC}" >&2
        exit 1
        ;;
    *)
        if [[ -z "$CROWN_DIR" ]]; then
            CROWN_DIR="$1"
        else
            echo -e "${RED}Error: Unexpected argument $1${NC}" >&2
            exit 1
        fi
        shift
        ;;
    esac
done

if [[ -z "$CROWN_DIR" ]]; then
    echo -e "${RED}Error: crown-dir required${NC}" >&2
    exit 1
fi

if [[ "$CONTESTANT_COUNT" -lt 2 ]]; then
    echo -e "${RED}Error: --count must be >= 2${NC}" >&2
    exit 1
fi

# Ensure crown dir exists
mkdir -p "$CROWN_DIR"

LOG_FILE="$CROWN_DIR/crown-witness.log"
PID_FILE="$CROWN_DIR/crown-witness.pid"

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

# Check for existing crown-witness
if [[ -f "$PID_FILE" ]]; then
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo -e "${YELLOW}Crown witness already running (PID $existing_pid)${NC}"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# Main monitoring loop
monitor_loop() {
    trap 'cleanup' EXIT
    echo $BASHPID >"$PID_FILE"
    log "Crown witness started: waiting for $CONTESTANT_COUNT contestants (timeout: ${TIMEOUT}s)"

    local elapsed=0
    local start_time
    start_time=$(date +%s)

    while true; do
        # Count completed contestants
        local done_count=0
        local failed_count=0

        for ((i = 1; i <= CONTESTANT_COUNT; i++)); do
            if [[ -f "$CROWN_DIR/done-$i" ]]; then
                done_count=$((done_count + 1))
            elif [[ -f "$CROWN_DIR/failed-$i" ]]; then
                failed_count=$((failed_count + 1))
            fi
        done

        local total_finished=$((done_count + failed_count))

        log "Progress: $done_count done, $failed_count failed, $((CONTESTANT_COUNT - total_finished)) pending"

        # All contestants finished (success or failure)
        if [[ "$total_finished" -ge "$CONTESTANT_COUNT" ]]; then
            if [[ "$done_count" -eq 0 ]]; then
                log "All contestants failed — no evaluation possible"
                notify "Crown Failed" "All $CONTESTANT_COUNT contestants failed"
                exit 3
            fi

            log "All contestants finished ($done_count succeeded, $failed_count failed) — triggering evaluation"
            run_evaluation "$done_count"
            break
        fi

        # Check timeout
        local now
        now=$(date +%s)
        elapsed=$((now - start_time))

        if [[ "$elapsed" -ge "$TIMEOUT" ]]; then
            log "Timeout reached (${elapsed}s >= ${TIMEOUT}s)"

            # Proceed with whatever we have if at least 1 succeeded
            if [[ "$done_count" -ge 1 ]]; then
                log "Proceeding with $done_count of $CONTESTANT_COUNT contestants (timeout, partial evaluation)"
                notify "Crown Timeout" "Evaluating $done_count of $CONTESTANT_COUNT contestants (timeout)"
                run_evaluation "$done_count"
                break
            else
                log "No contestants completed before timeout"
                notify "Crown Failed" "No contestants completed within ${TIMEOUT}s"
                exit 2
            fi
        fi

        sleep "$POLL_INTERVAL"
    done
}

# Run crown evaluation with completed contestants
run_evaluation() {
    # shellcheck disable=SC2034
    local expected_done="$1"

    # Collect branch names from done files
    local branches=()
    for ((i = 1; i <= CONTESTANT_COUNT; i++)); do
        if [[ -f "$CROWN_DIR/done-$i" ]]; then
            local branch
            branch=$(cat "$CROWN_DIR/done-$i")
            if [[ -n "$branch" ]]; then
                branches+=("$branch")
            fi
        fi
    done

    if [[ ${#branches[@]} -lt 1 ]]; then
        log "Error: No valid branch names found in done files"
        exit 1
    fi

    # Single contestant wins by default
    if [[ ${#branches[@]} -eq 1 ]]; then
        log "Only one contestant succeeded — automatic winner: ${branches[0]}"
        on_winner "${branches[0]}" '{"winner":"'"${branches[0]}"'","reasoning":"sole survivor"}'
        return
    fi

    # Auto-detect repo path from first branch if not set
    if [[ -z "$REPO_PATH" ]]; then
        # Try to find the repo from branch names (they should exist in the working git repo)
        REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    fi

    # Run crown-evaluate.sh
    local evaluate_script="$SCRIPT_DIR/crown-evaluate.sh"
    if [[ ! -x "$evaluate_script" ]]; then
        log "Error: crown-evaluate.sh not found at $evaluate_script"
        exit 1
    fi

    local verdict_file="$CROWN_DIR/verdict.json"

    log "Running evaluation: ${#branches[@]} contestants, judge=$JUDGE_PRESET"
    log "Branches: ${branches[*]}"

    local verdict
    verdict=$(bash "$evaluate_script" \
        --base "$BASE_BRANCH" \
        --judge "$JUDGE_PRESET" \
        --output "$verdict_file" \
        --repo "$REPO_PATH" \
        "${branches[@]}" 2>>"$LOG_FILE") || {
        log "Error: crown-evaluate.sh failed (exit $?)"
        notify "Crown Evaluation Failed" "Judge returned an error"
        exit 1
    }

    log "Verdict: $verdict"

    # Extract winner from verdict JSON
    local winner
    winner=$(printf '%s' "$verdict" | jq -r '.winner // empty' 2>/dev/null)

    if [[ -z "$winner" ]]; then
        log "Error: Could not extract winner from verdict"
        exit 1
    fi

    on_winner "$winner" "$verdict"
}

# Handle winner: submit to merge queue, notify, clean up losers
on_winner() {
    local winner_branch="$1"
    local verdict="$2"

    log "Winner: $winner_branch"
    notify "Crown Winner" "Branch $winner_branch won the tournament"

    # Find winner's worktree path
    local winner_worktree=""
    for ((i = 1; i <= CONTESTANT_COUNT; i++)); do
        if [[ -f "$CROWN_DIR/done-$i" ]]; then
            local branch
            branch=$(cat "$CROWN_DIR/done-$i")
            if [[ "$branch" == "$winner_branch" ]]; then
                # Read worktree path from companion file
                if [[ -f "$CROWN_DIR/worktree-$i" ]]; then
                    winner_worktree=$(cat "$CROWN_DIR/worktree-$i")
                fi
                break
            fi
        fi
    done

    # Submit winner to merge queue
    if [[ -n "$winner_worktree" && -d "$winner_worktree" ]]; then
        local merge_queue="$SCRIPT_DIR/merge-queue.sh"
        if [[ -x "$merge_queue" ]] && [[ -f "/tmp/merge-queue-daemon.pid" ]] && kill -0 "$(cat /tmp/merge-queue-daemon.pid)" 2>/dev/null; then
            log "Submitting winner to merge queue: $winner_worktree"
            "$merge_queue" add "$winner_worktree" 2>/dev/null || {
                log "Merge queue submission failed, trying direct merge"
                "$SCRIPT_DIR/auto-merge.sh" "$winner_worktree" 2>/dev/null || true
            }
        else
            log "Direct merge (no queue daemon): $winner_worktree"
            "$SCRIPT_DIR/auto-merge.sh" "$winner_worktree" 2>/dev/null || true
        fi

        # Run ticket-complete for PR creation
        local ticket_complete="$SCRIPT_DIR/ticket-complete.sh"
        if [[ -x "$ticket_complete" ]]; then
            log "Running ticket-complete for winner"
            "$ticket_complete" "$winner_worktree" 2>/dev/null || true
        fi
    else
        log "Warning: Winner worktree not found, skipping merge"
    fi

    # Send mail notification
    local mail_script="$SCRIPT_DIR/agent-mail.sh"
    if [[ -x "$mail_script" ]]; then
        local issue_key
        # shellcheck disable=SC2034
        issue_key=$(basename "$CROWN_DIR" | sed 's/^crown-//')
        "$mail_script" send all -s "Crown Winner: $winner_branch" \
            -m "Tournament complete. Winner: $winner_branch (judge: $JUDGE_PRESET)" \
            --from "crown-witness" 2>/dev/null || true
    fi

    # Clean up losing worktrees (optional, after grace period)
    if $DO_CLEANUP; then
        cleanup_losers "$winner_branch" &
        disown
    fi

    log "Crown evaluation complete"
}

# Clean up losing worktrees after grace period
cleanup_losers() {
    local winner_branch="$1"
    local grace_period=3600 # 1 hour

    log "Cleanup scheduled for losers in ${grace_period}s"
    sleep "$grace_period"

    for ((i = 1; i <= CONTESTANT_COUNT; i++)); do
        if [[ -f "$CROWN_DIR/done-$i" ]]; then
            local branch
            branch=$(cat "$CROWN_DIR/done-$i")
            if [[ "$branch" != "$winner_branch" && -f "$CROWN_DIR/worktree-$i" ]]; then
                local wt_path
                wt_path=$(cat "$CROWN_DIR/worktree-$i")
                if [[ -d "$wt_path" ]]; then
                    log "Cleaning up loser worktree: $wt_path ($branch)"
                    git worktree remove "$wt_path" --force 2>/dev/null || {
                        rm -rf "$wt_path" 2>/dev/null || true
                        git worktree prune 2>/dev/null || true
                    }
                fi
            fi
        fi
    done

    # Clean up crown dir itself
    log "Cleaning up crown dir: $CROWN_DIR"
    rm -rf "$CROWN_DIR" 2>/dev/null || true
}

# Cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
    log "Crown witness exiting"
}

# Run
if $FOREGROUND; then
    echo -e "${BLUE}Crown witness starting${NC} (foreground)"
    echo "  Crown dir:   $CROWN_DIR"
    echo "  Contestants:  $CONTESTANT_COUNT"
    echo "  Judge:        $JUDGE_PRESET"
    echo "  Poll:         ${POLL_INTERVAL}s"
    echo "  Timeout:      ${TIMEOUT}s"
    echo ""
    monitor_loop
else
    monitor_loop &
    disown
    echo "Crown witness started (PID $!)"
    echo "  Crown dir: $CROWN_DIR"
    echo "  Log: $LOG_FILE"
fi
