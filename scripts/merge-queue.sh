#!/usr/bin/env bash
#
# merge-queue.sh - Serialize merges through a queue (Refinery pattern)
#
# Prevents merge conflicts when multiple agents complete simultaneously
# by queuing merges and processing them one at a time with validation,
# retry, and conflict detection.
#
# Usage:
#   merge-queue.sh add <worktree-path>         # Add worktree to queue
#   merge-queue.sh process                      # Process next pending item
#   merge-queue.sh list                         # Show queue with status
#   merge-queue.sh retry <index>                # Reset failed/conflict/respawned → pending
#   merge-queue.sh reject <index>               # Mark item as rejected
#   merge-queue.sh daemon [--poll-interval 30]  # Continuous processing loop
#   merge-queue.sh stop                         # Stop daemon
#   merge-queue.sh status                       # Daemon status + queue summary
#   --rebase                                    # Rebase onto main before merging
#
# Exit codes:
#   0 - Success
#   1 - Error (bad args, missing deps, etc.)
#   2 - Queue empty (nothing to process)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
QUEUE_FILE="${HOME}/.claude/merge-queue.json"
PID_FILE="/tmp/merge-queue-daemon.pid"
LOG_FILE="${HOME}/.claude/merge-queue.log"
LOCK_FILE="/tmp/merge-queue.lock"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTO_MERGE="${SCRIPT_DIR}/auto-merge.sh"
POLL_INTERVAL=30
REBASE_MODE=false

# Ensure queue dir exists
mkdir -p "$(dirname "$QUEUE_FILE")"

# --- Locking ---

acquire_lock() {
    local max_wait=10
    local waited=0
    while ! mkdir "$LOCK_FILE" 2>/dev/null; do
        waited=$((waited + 1))
        if [[ $waited -ge $max_wait ]]; then
            echo -e "${RED}Error: Could not acquire lock after ${max_wait}s${NC}" >&2
            return 1
        fi
        sleep 1
    done
    # Clean up lock on exit
    trap 'release_lock' EXIT
}

release_lock() {
    rmdir "$LOCK_FILE" 2>/dev/null || true
    trap - EXIT
}

# --- Queue helpers ---

ensure_queue() {
    if [[ ! -f "$QUEUE_FILE" ]]; then
        echo '[]' >"$QUEUE_FILE"
    fi
}

log_msg() {
    local msg="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$timestamp] $msg" >>"$LOG_FILE"
}

# --- Commands ---

cmd_add() {
    local worktree_path="$1"

    if [[ ! -d "$worktree_path" ]]; then
        echo -e "${RED}Error: Not a directory: $worktree_path${NC}" >&2
        exit 1
    fi

    # Resolve to absolute path
    worktree_path=$(cd "$worktree_path" && pwd)

    # Get branch name
    local branch
    branch=$(git -C "$worktree_path" branch --show-current 2>/dev/null || true)
    if [[ -z "$branch" ]]; then
        echo -e "${RED}Error: Could not determine branch in $worktree_path${NC}" >&2
        exit 1
    fi

    acquire_lock
    ensure_queue

    # Check for duplicate (same worktree_path with pending/processing status)
    local existing
    existing=$(jq -r --arg path "$worktree_path" \
        '[.[] | select(.worktree_path == $path and (.status == "pending" or .status == "processing"))] | length' \
        "$QUEUE_FILE")

    if [[ "$existing" -gt 0 ]]; then
        echo -e "${YELLOW}Already queued: $worktree_path ($branch)${NC}"
        release_lock
        return 0
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Add to queue
    local tmp
    tmp=$(mktemp)
    jq --arg path "$worktree_path" \
        --arg branch "$branch" \
        --arg ts "$timestamp" \
        '. += [{
           "worktree_path": $path,
           "branch": $branch,
           "submitted_at": $ts,
           "status": "pending",
           "retries": 0,
           "max_retries": 3,
           "last_error": ""
       }]' "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"

    release_lock

    echo -e "${GREEN}Queued: $branch ($worktree_path)${NC}"
    log_msg "QUEUED branch=$branch path=$worktree_path"
}

cmd_process() {
    acquire_lock
    ensure_queue

    # Find first pending item
    local idx
    idx=$(jq '[.[] | .status] | to_entries | map(select(.value == "pending")) | .[0].key // -1' "$QUEUE_FILE")

    if [[ "$idx" -eq -1 ]]; then
        release_lock
        echo -e "${YELLOW}Queue empty, nothing to process${NC}"
        return 2
    fi

    # Extract item details
    local worktree_path branch
    worktree_path=$(jq -r ".[$idx].worktree_path" "$QUEUE_FILE")
    branch=$(jq -r ".[$idx].branch" "$QUEUE_FILE")

    # Set status to processing
    local tmp
    tmp=$(mktemp)
    jq ".[$idx].status = \"processing\"" "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
    release_lock

    echo -e "${BLUE}Processing: $branch ($worktree_path)${NC}"
    log_msg "PROCESSING branch=$branch path=$worktree_path"

    # Derive repo root to fetch and push
    local repo_root
    if [[ -d "$worktree_path" ]]; then
        local git_common_dir
        git_common_dir=$(git -C "$worktree_path" rev-parse --git-common-dir 2>/dev/null || true)
        if [[ -n "$git_common_dir" ]]; then
            repo_root=$(cd "$worktree_path" && cd "$git_common_dir/.." && pwd)
        fi
    fi

    if [[ -z "${repo_root:-}" ]]; then
        mark_item "$idx" "failed" "Could not determine repo root"
        echo -e "${RED}Error: Could not determine repo root for $worktree_path${NC}"
        return 1
    fi

    # Fetch latest main
    echo "Fetching latest from origin..."
    git -C "$repo_root" fetch origin 2>/dev/null || true

    # Rebase onto main if --rebase mode is enabled
    if [[ "$REBASE_MODE" == true ]]; then
        echo "Rebasing $branch onto origin/main..."
        if ! git -C "$worktree_path" rebase origin/main 2>/dev/null; then
            # Rebase failed with conflicts - abort and respawn
            git -C "$worktree_path" rebase --abort 2>/dev/null || true

            # Extract task metadata for respawn
            local ticket_file="$worktree_path/.claude/ticket-execute.local.md"
            local issue_key="" title="" description=""
            if [[ -f "$ticket_file" ]]; then
                issue_key=$(sed -n 's/^issue_key: *//p' "$ticket_file" | head -1)
                title=$(sed -n 's/^title: *//p' "$ticket_file" | head -1)
                # Extract description from "Prompt Given" section
                description=$(sed -n '/^## Prompt Given/,/^## /{ /^## Prompt Given/d; /^## /d; p; }' "$ticket_file" | head -20)
            fi

            mark_item "$idx" "respawned" "Rebase conflicts with origin/main"
            log_msg "RESPAWNED branch=$branch path=$worktree_path issue_key=${issue_key:-none} reason=rebase_conflict"
            echo -e "${YELLOW}Respawned: $branch (rebase conflicts, needs re-execution)${NC}"
            send_notification "Rebase Conflict" "$branch has rebase conflicts - marked for respawn"
            return 0
        fi
        log_msg "REBASED branch=$branch path=$worktree_path"
        echo -e "${GREEN}Rebased $branch onto origin/main${NC}"
    fi

    # Run auto-merge
    local merge_exit=0
    "$AUTO_MERGE" "$worktree_path" || merge_exit=$?

    case $merge_exit in
    0)
        # Success - push and remove from queue
        local main_branch
        main_branch=$(git -C "$repo_root" branch --show-current)
        echo "Pushing $main_branch to origin..."
        if git -C "$repo_root" push origin "$main_branch" 2>/dev/null; then
            log_msg "MERGED branch=$branch pushed=$main_branch"
            echo -e "${GREEN}Merged and pushed: $branch${NC}"
        else
            log_msg "MERGED branch=$branch push_failed=true"
            echo -e "${YELLOW}Merged but push failed (may need manual push)${NC}"
        fi
        # Remove from queue
        acquire_lock
        tmp=$(mktemp)
        jq "del(.[$idx])" "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
        release_lock
        ;;
    2)
        # Non-additive conflicts
        mark_item "$idx" "conflict" "Non-additive conflicts detected"
        log_msg "CONFLICT branch=$branch path=$worktree_path"
        echo -e "${RED}Conflict: $branch has non-additive conflicts${NC}"
        # Send notification
        send_notification "Merge Conflict" "$branch has non-additive conflicts requiring manual resolution"
        # Abort the in-progress merge so the repo is clean for the next queue item
        git -C "$repo_root" merge --abort 2>/dev/null || true
        ;;
    *)
        # Error - retry logic
        acquire_lock
        ensure_queue
        local retries max_retries
        retries=$(jq -r ".[$idx].retries" "$QUEUE_FILE")
        max_retries=$(jq -r ".[$idx].max_retries" "$QUEUE_FILE")
        retries=$((retries + 1))

        if [[ $retries -lt $max_retries ]]; then
            tmp=$(mktemp)
            jq ".[$idx].retries = $retries | .[$idx].status = \"pending\" | .[$idx].last_error = \"exit code $merge_exit (retry $retries/$max_retries)\"" \
                "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
            release_lock
            log_msg "RETRY branch=$branch attempt=$retries/$max_retries exit=$merge_exit"
            echo -e "${YELLOW}Retry $retries/$max_retries for $branch (exit $merge_exit)${NC}"
        else
            tmp=$(mktemp)
            jq ".[$idx].retries = $retries | .[$idx].status = \"failed\" | .[$idx].last_error = \"exit code $merge_exit (max retries exceeded)\"" \
                "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
            release_lock
            log_msg "FAILED branch=$branch exit=$merge_exit retries_exhausted=true"
            echo -e "${RED}Failed: $branch (exit $merge_exit, retries exhausted)${NC}"
            send_notification "Merge Failed" "$branch failed after $max_retries retries"
        fi
        # Clean up any in-progress merge
        git -C "$repo_root" merge --abort 2>/dev/null || true
        ;;
    esac
}

mark_item() {
    local idx="$1" status="$2" error="$3"
    acquire_lock
    ensure_queue
    local tmp
    tmp=$(mktemp)
    jq --arg status "$status" --arg err "$error" \
        ".[$idx].status = \$status | .[$idx].last_error = \$err" \
        "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
    release_lock
}

send_notification() {
    local title="$1" msg="$2"
    if command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "$title" -message "$msg" -sound default 2>/dev/null || true
    elif command -v osascript &>/dev/null; then
        osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null || true
    fi
}

cmd_retry() {
    local idx="$1"

    acquire_lock
    ensure_queue

    local count
    count=$(jq 'length' "$QUEUE_FILE")
    if [[ "$idx" -lt 0 || "$idx" -ge "$count" ]]; then
        release_lock
        echo -e "${RED}Error: Invalid index $idx (queue has $count items)${NC}" >&2
        return 1
    fi

    local status
    status=$(jq -r ".[$idx].status" "$QUEUE_FILE")
    case "$status" in
    failed | conflict | respawned)
        local tmp
        tmp=$(mktemp)
        jq ".[$idx].status = \"pending\" | .[$idx].retries = 0 | .[$idx].last_error = \"\"" \
            "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
        local branch
        branch=$(jq -r ".[$idx].branch" "$QUEUE_FILE")
        release_lock
        log_msg "RETRY_RESET branch=$branch idx=$idx previous_status=$status"
        echo -e "${GREEN}Reset item $idx ($branch) from $status to pending${NC}"
        ;;
    *)
        release_lock
        echo -e "${RED}Error: Item $idx has status '$status' (must be failed, conflict, or respawned)${NC}" >&2
        return 1
        ;;
    esac
}

cmd_reject() {
    local idx="$1"

    acquire_lock
    ensure_queue

    local count
    count=$(jq 'length' "$QUEUE_FILE")
    if [[ "$idx" -lt 0 || "$idx" -ge "$count" ]]; then
        release_lock
        echo -e "${RED}Error: Invalid index $idx (queue has $count items)${NC}" >&2
        return 1
    fi

    local branch status
    branch=$(jq -r ".[$idx].branch" "$QUEUE_FILE")
    status=$(jq -r ".[$idx].status" "$QUEUE_FILE")

    local tmp
    tmp=$(mktemp)
    jq ".[$idx].status = \"rejected\"" "$QUEUE_FILE" >"$tmp" && mv "$tmp" "$QUEUE_FILE"
    release_lock

    log_msg "REJECTED branch=$branch idx=$idx previous_status=$status"
    echo -e "${YELLOW}Rejected item $idx ($branch)${NC}"
}

cmd_list() {
    ensure_queue

    local count
    count=$(jq 'length' "$QUEUE_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}Queue is empty${NC}"
        return 0
    fi

    echo -e "${BLUE}=== Merge Queue ($count items) ===${NC}"
    echo ""

    local i=0
    while [[ $i -lt $count ]]; do
        local status branch path submitted retries last_error
        status=$(jq -r ".[$i].status" "$QUEUE_FILE")
        branch=$(jq -r ".[$i].branch" "$QUEUE_FILE")
        path=$(jq -r ".[$i].worktree_path" "$QUEUE_FILE")
        submitted=$(jq -r ".[$i].submitted_at" "$QUEUE_FILE")
        retries=$(jq -r ".[$i].retries" "$QUEUE_FILE")
        last_error=$(jq -r ".[$i].last_error" "$QUEUE_FILE")

        local color
        case "$status" in
        pending) color="$YELLOW" ;;
        processing) color="$BLUE" ;;
        completed) color="$GREEN" ;;
        conflict) color="$RED" ;;
        failed) color="$RED" ;;
        respawned) color="$YELLOW" ;;
        rejected) color="$RED" ;;
        *) color="$NC" ;;
        esac

        echo -e "  ${color}[$status]${NC} $branch"
        echo -e "    Path:      $path"
        echo -e "    Submitted: $submitted"
        if [[ $retries -gt 0 ]]; then
            echo -e "    Retries:   $retries"
        fi
        if [[ -n "$last_error" && "$last_error" != "" ]]; then
            echo -e "    Error:     $last_error"
        fi
        echo ""

        i=$((i + 1))
    done
}

cmd_daemon() {
    # Check if daemon is already running
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo -e "${YELLOW}Daemon already running (PID $existing_pid)${NC}"
            exit 1
        fi
        # Stale PID file
        rm -f "$PID_FILE"
    fi

    echo -e "${GREEN}Starting merge-queue daemon (poll every ${POLL_INTERVAL}s)${NC}"
    log_msg "DAEMON_START poll_interval=$POLL_INTERVAL"

    # Fork to background
    (
        # Write PID
        echo $$ >"$PID_FILE"

        # Clean up on exit
        cleanup_daemon() {
            rm -f "$PID_FILE"
            log_msg "DAEMON_STOP"
        }
        trap cleanup_daemon EXIT TERM INT

        while true; do
            # Process next pending item (ignore exit 2 = empty queue)
            if [[ "$REBASE_MODE" == true ]]; then
                "$0" --rebase process 2>/dev/null || true
            else
                "$0" process 2>/dev/null || true
            fi
            sleep "$POLL_INTERVAL"
        done
    ) &

    local daemon_pid=$!
    echo "$daemon_pid" >"$PID_FILE"

    echo -e "${GREEN}Daemon started (PID $daemon_pid)${NC}"
    echo -e "Log: $LOG_FILE"
    echo -e "Stop: $0 stop"
}

cmd_stop() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo -e "${YELLOW}No daemon running (no PID file)${NC}"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        rm -f "$PID_FILE"
        echo -e "${GREEN}Daemon stopped (PID $pid)${NC}"
        log_msg "DAEMON_STOP pid=$pid"
    else
        rm -f "$PID_FILE"
        echo -e "${YELLOW}Daemon not running (stale PID file cleaned)${NC}"
    fi
}

cmd_status() {
    echo -e "${BLUE}=== Merge Queue Status ===${NC}"
    echo ""

    # Daemon status
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "Daemon:  ${GREEN}running${NC} (PID $pid, poll ${POLL_INTERVAL}s)"
        else
            echo -e "Daemon:  ${RED}dead${NC} (stale PID $pid)"
        fi
    else
        echo -e "Daemon:  ${YELLOW}stopped${NC}"
    fi

    # Queue summary
    ensure_queue
    local total pending processing conflict failed respawned rejected
    total=$(jq 'length' "$QUEUE_FILE")
    pending=$(jq '[.[] | select(.status == "pending")] | length' "$QUEUE_FILE")
    processing=$(jq '[.[] | select(.status == "processing")] | length' "$QUEUE_FILE")
    conflict=$(jq '[.[] | select(.status == "conflict")] | length' "$QUEUE_FILE")
    failed=$(jq '[.[] | select(.status == "failed")] | length' "$QUEUE_FILE")
    respawned=$(jq '[.[] | select(.status == "respawned")] | length' "$QUEUE_FILE")
    rejected=$(jq '[.[] | select(.status == "rejected")] | length' "$QUEUE_FILE")

    echo -e "Queue:   $total total, ${GREEN}$pending pending${NC}, ${BLUE}$processing processing${NC}, ${RED}$conflict conflicts${NC}, ${RED}$failed failed${NC}, ${YELLOW}$respawned respawned${NC}, ${RED}$rejected rejected${NC}"
    echo -e "Log:     $LOG_FILE"
    echo -e "Queue:   $QUEUE_FILE"
}

is_daemon_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# --- Main ---

show_help() {
    cat <<'EOF'
merge-queue.sh - Serialize merges through a queue (Refinery pattern)

USAGE:
  merge-queue.sh add <worktree-path>          Add worktree to merge queue
  merge-queue.sh process                       Process next pending merge
  merge-queue.sh list                          Show queue with status
  merge-queue.sh retry <index>                 Reset failed/conflict/respawned item to pending
  merge-queue.sh reject <index>                Mark item as rejected (skip processing)
  merge-queue.sh daemon [--poll-interval 30]   Start continuous processing
  merge-queue.sh stop                          Stop daemon
  merge-queue.sh status                        Show daemon + queue summary

OPTIONS:
  --rebase            Rebase onto origin/main before merging (respawns on conflict)
  --poll-interval N   Seconds between daemon processing cycles (default: 30)
  --help              Show this help

EXIT CODES:
  0 - Success
  1 - Error
  2 - Queue empty (nothing to process)
EOF
}

COMMAND="${1:-}"
shift || true

# Parse global flags before command dispatch
while [[ "$COMMAND" == --* ]]; do
    case "$COMMAND" in
    --rebase)
        REBASE_MODE=true
        COMMAND="${1:-}"
        shift || true
        ;;
    --help | -h)
        show_help
        exit 0
        ;;
    *)
        echo -e "${RED}Error: Unknown flag '$COMMAND'${NC}" >&2
        echo "Run 'merge-queue.sh --help' for usage" >&2
        exit 1
        ;;
    esac
done

case "$COMMAND" in
add)
    if [[ -z "${1:-}" ]]; then
        echo -e "${RED}Error: worktree path required${NC}" >&2
        echo "Usage: merge-queue.sh add <worktree-path>" >&2
        exit 1
    fi
    cmd_add "$1"
    ;;
process)
    cmd_process
    ;;
list)
    cmd_list
    ;;
retry)
    if [[ -z "${1:-}" ]]; then
        echo -e "${RED}Error: queue index required${NC}" >&2
        echo "Usage: merge-queue.sh retry <index>" >&2
        exit 1
    fi
    cmd_retry "$1"
    ;;
reject)
    if [[ -z "${1:-}" ]]; then
        echo -e "${RED}Error: queue index required${NC}" >&2
        echo "Usage: merge-queue.sh reject <index>" >&2
        exit 1
    fi
    cmd_reject "$1"
    ;;
daemon)
    # Parse daemon-specific flags
    while [[ $# -gt 0 ]]; do
        case $1 in
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --rebase)
            REBASE_MODE=true
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown daemon option $1${NC}" >&2
            exit 1
            ;;
        esac
    done
    cmd_daemon
    ;;
stop)
    cmd_stop
    ;;
status)
    cmd_status
    ;;
help)
    show_help
    ;;
"")
    show_help
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    echo "Run 'merge-queue.sh --help' for usage" >&2
    exit 1
    ;;
esac
