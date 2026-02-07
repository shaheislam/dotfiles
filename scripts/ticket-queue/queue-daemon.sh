#!/usr/bin/env bash
#
# queue-daemon.sh - Background ticket queue dispatcher
#
# Monitors Claude Code usage limits and dispatches queued tickets
# via gwt-ticket when capacity becomes available.
#
# Usage:
#   queue-daemon.sh start              # Start daemon in background
#   queue-daemon.sh stop               # Stop running daemon
#   queue-daemon.sh status             # Show daemon and queue status
#   queue-daemon.sh run                # Run in foreground (for debugging)
#   queue-daemon.sh add <args...>      # Add ticket to queue
#   queue-daemon.sh list               # List queued tickets
#   queue-daemon.sh remove <id>        # Remove ticket from queue
#   queue-daemon.sh clear              # Clear all queued tickets
#   queue-daemon.sh next               # Dispatch next ticket now (skip wait)
#
# Queue file: ~/.claude/ticket-queue.json
# PID file:   ~/.claude/ticket-queue.pid
# Log file:   ~/.claude/ticket-queue.log

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_SCRIPT="$SCRIPT_DIR/claude-usage.sh"

QUEUE_DIR="${HOME}/.claude"
QUEUE_FILE="$QUEUE_DIR/ticket-queue.json"
PID_FILE="$QUEUE_DIR/ticket-queue.pid"
LOG_FILE="$QUEUE_DIR/ticket-queue.log"

# Daemon settings
POLL_INTERVAL="${QUEUE_POLL_INTERVAL:-300}"  # 5 minutes default
THRESHOLD="${QUEUE_THRESHOLD:-80}"           # Start dispatching below 80%
COOLDOWN="${QUEUE_COOLDOWN:-600}"            # 10min between dispatches
MAX_LOG_SIZE=1048576                         # 1MB log rotation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    cat << 'EOF'
queue-daemon.sh - Ticket queue daemon for Claude Code

USAGE:
  queue-daemon.sh start              # Start daemon in background
  queue-daemon.sh stop               # Stop running daemon
  queue-daemon.sh status             # Show daemon and queue status
  queue-daemon.sh run                # Run in foreground (for debugging)
  queue-daemon.sh add <args...>      # Add ticket to queue
  queue-daemon.sh list               # List queued tickets
  queue-daemon.sh remove <id>        # Remove ticket from queue
  queue-daemon.sh clear              # Clear all queued tickets
  queue-daemon.sh next               # Dispatch next ticket immediately

QUEUE ADD FORMAT:
  queue-daemon.sh add [issue-key] <title> [description] [--opts...]

  Accepts the same arguments as gwt-ticket:
    queue-daemon.sh add ENG-123 "Fix auth" "Token expiry bug"
    queue-daemon.sh add "Add dark mode" "Implement theme toggle"
    queue-daemon.sh add ENG-456 "Refactor" --max 30 --devcon
    queue-daemon.sh add --repo /path/to/repo "Fix tests" "Unit tests failing"

  Additional queue-specific options:
    --repo PATH    Git repo to run gwt-ticket in (default: current dir)
    --priority N   Priority 1-10, higher = first (default: 5)
    --sub NAME     Claude subscription profile (dispatches with --sub NAME)
                   If omitted, daemon auto-selects profile with lowest usage

ADDITIONAL COMMANDS:
  queue-daemon.sh profiles           # List subscription profiles + usage

ENVIRONMENT:
  QUEUE_POLL_INTERVAL  Poll interval seconds (default: 300)
  QUEUE_THRESHOLD      Max utilization % to dispatch (default: 80)
  QUEUE_COOLDOWN       Seconds between dispatches (default: 600)

FILES:
  ~/.claude/ticket-queue.json   Queue data
  ~/.claude/ticket-queue.pid    Daemon PID
  ~/.claude/ticket-queue.log    Daemon log
EOF
}

# Ensure queue file exists
ensure_queue() {
    mkdir -p "$QUEUE_DIR"
    if [[ ! -f "$QUEUE_FILE" ]]; then
        echo '{"tickets":[],"completed":[],"failed":[]}' > "$QUEUE_FILE"
    fi
}

# Log with timestamp
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
    # Rotate log if too large
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat --printf=%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "$LOG_FILE.1"
    fi
}

# Generate unique ticket ID
generate_id() {
    date '+%Y%m%d-%H%M%S'
}

# Add ticket to queue
cmd_add() {
    ensure_queue

    local issue_key=""
    local title=""
    local description=""
    local repo_path=""
    local priority=5
    local sub_profile=""
    local gwt_args=()
    local skip_next=false
    local positional_index=0

    for i in $(seq 1 $#); do
        if $skip_next; then
            skip_next=false
            continue
        fi

        local arg="${!i}"
        local next_i=$((i + 1))

        case "$arg" in
            --repo)
                repo_path="${!next_i}"
                skip_next=true
                ;;
            --priority)
                priority="${!next_i}"
                skip_next=true
                ;;
            --sub)
                sub_profile="${!next_i}"
                skip_next=true
                ;;
            --max|--session|--system|--command|--prompt-template|--prompt-prefix|--prompt-suffix|--mount|-m)
                gwt_args+=("$arg" "${!next_i}")
                skip_next=true
                ;;
            --devcon|--help|-h)
                gwt_args+=("$arg")
                ;;
            -*)
                gwt_args+=("$arg")
                ;;
            *)
                positional_index=$((positional_index + 1))
                case $positional_index in
                    1) issue_key="$arg" ;;
                    2) title="$arg" ;;
                    3) description="$arg" ;;
                    *) description="$description $arg" ;;
                esac
                ;;
        esac
    done

    # Detect issue key vs title (same logic as gwt-ticket)
    if [[ -n "$issue_key" ]] && ! echo "$issue_key" | grep -qE '^[A-Z]+-[0-9]+$'; then
        if [[ -n "$title" ]]; then
            description="$title"
        fi
        title="$issue_key"
        issue_key="TASK"
    fi

    if [[ -z "$title" ]]; then
        echo -e "${RED}Error: Title required${NC}" >&2
        echo "Usage: queue-daemon.sh add [issue-key] <title> [description] [--opts...]" >&2
        return 1
    fi

    # Default repo to current directory
    if [[ -z "$repo_path" ]]; then
        repo_path="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
    repo_path="$(cd "$repo_path" && pwd)"

    local ticket_id
    ticket_id=$(generate_id)
    local added_at
    added_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build the JSON entry safely via stdin (avoids shell injection)
    local gwt_args_json="[]"
    if [[ ${#gwt_args[@]} -gt 0 ]]; then
        gwt_args_json=$(printf '%s\n' "${gwt_args[@]}" | python3 -c "
import sys, json
args = [line.strip() for line in sys.stdin]
print(json.dumps(args))
")
    fi

    # Add to queue using env vars for safe JSON handling (avoids shell quoting issues)
    local position total
    read -r position total < <(_QUEUE_TITLE="$title" _QUEUE_DESC="${description:-$title}" _QUEUE_SUB="$sub_profile" python3 << PYEOF
import json, sys, os

# Read inputs safely
ticket_id = "$ticket_id"
issue_key = "$issue_key"
repo_path = "$repo_path"
priority = $priority
added_at = "$added_at"
gwt_args = json.loads('$gwt_args_json')

# Read title/description from env to avoid shell quoting issues
title = os.environ.get('_QUEUE_TITLE', '')
description = os.environ.get('_QUEUE_DESC', title)
sub = os.environ.get('_QUEUE_SUB', '')

ticket = {
    'id': ticket_id,
    'issue_key': issue_key,
    'title': title,
    'description': description,
    'repo_path': repo_path,
    'priority': priority,
    'status': 'queued',
    'added_at': added_at,
    'gwt_args': gwt_args,
    'sub': sub
}

queue_file = "$QUEUE_FILE"
with open(queue_file, 'r') as f:
    queue = json.load(f)
queue['tickets'].append(ticket)
queue['tickets'].sort(key=lambda t: t.get('priority', 5), reverse=True)
with open(queue_file, 'w') as f:
    json.dump(queue, f, indent=2)

# Find position
for i, t in enumerate(queue['tickets']):
    if t['id'] == ticket_id:
        print(f"{i + 1} {len(queue['tickets'])}")
        break
PYEOF
)

    local display_key="$issue_key"
    [[ "$issue_key" == "TASK" ]] && display_key="(auto)"

    echo -e "${GREEN}Queued:${NC} $display_key - $title"
    echo -e "  ID:       $ticket_id"
    echo -e "  Repo:     $repo_path"
    echo -e "  Priority: $priority"
    if [[ -n "$sub_profile" ]]; then
        echo -e "  Sub:      $sub_profile"
    else
        echo -e "  Sub:      (auto - dispatches to any available)"
    fi
    echo -e "  Position: ${position:-?} of ${total:-?}"

    log "Added ticket $ticket_id: $display_key - $title (priority: $priority, sub: ${sub_profile:-auto})"
}

# List queued tickets
cmd_list() {
    ensure_queue

    _QUEUE_FILE="$QUEUE_FILE" python3 << 'PYEOF'
import json, os

with open(os.environ['_QUEUE_FILE']) as f:
    data = json.load(f)
tickets = data.get('tickets', [])
completed = data.get('completed', [])
failed = data.get('failed', [])

if not tickets and not completed and not failed:
    print('Queue is empty')
else:
    if tickets:
        print(f'\033[0;34m=== Queued ({len(tickets)}) ===\033[0m')
        for i, t in enumerate(tickets):
            key = t.get('issue_key', 'TASK')
            key_display = key if key != 'TASK' else '(auto)'
            pri = t.get('priority', 5)
            status = t.get('status', 'queued')
            sub = t.get('sub', '')
            sub_display = f' | Sub: {sub}' if sub else ' | Sub: auto'
            print(f'  {i+1}. [{t["id"]}] {key_display} - {t["title"]}')
            print(f'     Priority: {pri} | Repo: {t.get("repo_path", "?")}{sub_display} | Status: {status}')
        print()

    if completed:
        print(f'\033[0;32m=== Completed ({len(completed)}) ===\033[0m')
        for t in completed[-5:]:  # Show last 5
            key = t.get('issue_key', 'TASK')
            key_display = key if key != 'TASK' else '(auto)'
            print(f'  [{t["id"]}] {key_display} - {t["title"]}')
        print()

    if failed:
        print(f'\033[0;31m=== Failed ({len(failed)}) ===\033[0m')
        for t in failed[-3:]:
            key = t.get('issue_key', 'TASK')
            key_display = key if key != 'TASK' else '(auto)'
            error = t.get('error', 'unknown')
            print(f'  [{t["id"]}] {key_display} - {t["title"]} ({error})')
PYEOF
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error reading queue file${NC}"
        return 1
    fi
}

# Remove ticket from queue
cmd_remove() {
    local ticket_id="$1"
    ensure_queue

    python3 -c "
import json, sys
with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)
original = len(queue['tickets'])
queue['tickets'] = [t for t in queue['tickets'] if t['id'] != '$ticket_id']
if len(queue['tickets']) == original:
    print(f'Ticket $ticket_id not found in queue', file=sys.stderr)
    sys.exit(1)
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
print(f'Removed ticket $ticket_id')
"
    log "Removed ticket $ticket_id"
}

# Clear all queued tickets
cmd_clear() {
    ensure_queue
    python3 -c "
import json
with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)
count = len(queue['tickets'])
queue['tickets'] = []
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
print(f'Cleared {count} tickets from queue')
"
    log "Cleared queue"
}

# Check if daemon is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        # Stale PID file
        rm -f "$PID_FILE"
    fi
    return 1
}

# Show daemon and queue status
cmd_status() {
    ensure_queue

    echo -e "${BLUE}=== Ticket Queue Status ===${NC}"
    echo ""

    # Daemon status
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "Daemon:     ${GREEN}Running${NC} (PID: $pid)"
    else
        echo -e "Daemon:     ${YELLOW}Stopped${NC}"
    fi
    echo -e "Threshold:  ${THRESHOLD}%"
    echo -e "Poll:       ${POLL_INTERVAL}s"
    echo -e "Cooldown:   ${COOLDOWN}s"
    echo ""

    # Queue stats
    local stats
    stats=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    q = json.load(f)
print(len(q.get('tickets', [])))
print(len(q.get('completed', [])))
print(len(q.get('failed', [])))
")
    local queued completed failed
    queued=$(echo "$stats" | sed -n '1p')
    completed=$(echo "$stats" | sed -n '2p')
    failed=$(echo "$stats" | sed -n '3p')

    echo -e "Queued:     ${CYAN}$queued${NC}"
    echo -e "Completed:  ${GREEN}$completed${NC}"
    echo -e "Failed:     ${RED}$failed${NC}"
    echo ""

    # Current usage (if credentials available)
    if [[ -x "$USAGE_SCRIPT" ]]; then
        echo -e "${BLUE}--- Current Usage ---${NC}"
        "$USAGE_SCRIPT" 2>/dev/null || echo -e "${YELLOW}Cannot check usage (not authenticated?)${NC}"
    fi
}

# Dispatch next ticket from queue
dispatch_next() {
    ensure_queue

    # Get next ticket
    local ticket_json
    ticket_json=$(python3 -c "
import json, sys
with open('$QUEUE_FILE') as f:
    queue = json.load(f)
tickets = [t for t in queue.get('tickets', []) if t.get('status') == 'queued']
if not tickets:
    sys.exit(1)
print(json.dumps(tickets[0]))
" 2>/dev/null) || return 1

    local ticket_id issue_key title description repo_path
    ticket_id=$(echo "$ticket_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    issue_key=$(echo "$ticket_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['issue_key'])")
    title=$(echo "$ticket_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
    description=$(echo "$ticket_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['description'])")
    repo_path=$(echo "$ticket_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['repo_path'])")

    # Get extra gwt args and sub profile
    local gwt_extra_args
    gwt_extra_args=$(echo "$ticket_json" | python3 -c "
import json, sys
args = json.load(sys.stdin).get('gwt_args', [])
print(' '.join(args))
")
    local ticket_sub
    ticket_sub=$(echo "$ticket_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('sub', ''))")

    # If dispatch_sub was passed (from daemon loop), use it to override empty ticket sub
    local effective_sub="${ticket_sub:-${DISPATCH_SUB:-}}"

    local display_key="$issue_key"
    [[ "$issue_key" == "TASK" ]] && display_key="(auto)"

    local sub_display=""
    [[ -n "$effective_sub" ]] && sub_display=" (sub: $effective_sub)"
    log "Dispatching ticket $ticket_id: $display_key - $title$sub_display"
    echo -e "${GREEN}Dispatching:${NC} $display_key - $title$sub_display"

    # Mark as dispatching
    python3 -c "
import json
with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)
for t in queue['tickets']:
    if t['id'] == '$ticket_id':
        t['status'] = 'dispatching'
        t['dispatched_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
        break
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"

    # Build gwt-ticket command
    local gwt_cmd="gwt-ticket"
    if [[ "$issue_key" != "TASK" ]]; then
        gwt_cmd="$gwt_cmd $issue_key"
    fi
    gwt_cmd="$gwt_cmd '$title'"
    if [[ -n "$description" && "$description" != "$title" ]]; then
        gwt_cmd="$gwt_cmd '$description'"
    fi
    if [[ -n "$effective_sub" ]]; then
        gwt_cmd="$gwt_cmd --sub $effective_sub"
    fi
    if [[ -n "$gwt_extra_args" ]]; then
        gwt_cmd="$gwt_cmd $gwt_extra_args"
    fi

    # Execute via fish (gwt-ticket is a fish function)
    local dispatch_result=0
    (cd "$repo_path" && fish -c "$gwt_cmd") || dispatch_result=$?

    if [[ $dispatch_result -eq 0 ]]; then
        # Move to completed
        python3 -c "
import json
with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)
ticket = None
queue['tickets'] = [t for t in queue['tickets'] if t['id'] != '$ticket_id' or (ticket := t) is None]
if ticket is None:
    # Find it (walrus didn't fire because of the filter logic)
    import sys
    sys.exit(0)
for t in list(queue['tickets']):
    if t['id'] == '$ticket_id':
        ticket = t
        queue['tickets'].remove(t)
        break
if ticket:
    ticket['status'] = 'dispatched'
    queue['completed'].append(ticket)
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"
        log "Successfully dispatched ticket $ticket_id"
        echo -e "${GREEN}Dispatched successfully${NC}"

        # Send notification
        send_notification "Ticket Dispatched" "$display_key: $title (from queue)"
    else
        # Move to failed
        python3 -c "
import json
with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)
for t in list(queue['tickets']):
    if t['id'] == '$ticket_id':
        queue['tickets'].remove(t)
        t['status'] = 'failed'
        t['error'] = 'gwt-ticket exit code $dispatch_result'
        queue['failed'].append(t)
        break
with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"
        log "Failed to dispatch ticket $ticket_id (exit code: $dispatch_result)"
        echo -e "${RED}Dispatch failed (exit code: $dispatch_result)${NC}"
    fi

    return $dispatch_result
}

# Send notification
send_notification() {
    local title="$1"
    local msg="$2"

    if command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "$title" -message "$msg" -sound default 2>/dev/null
    elif command -v osascript &>/dev/null; then
        osascript -e "display notification \"$msg\" with title \"$title\"" 2>/dev/null
    fi
}

# List all subscription profile directories
# Returns: lines of "name config_dir" pairs
list_sub_profiles() {
    # Default profile (Keychain-based)
    echo "default ${HOME}/.claude"
    # Named profiles
    for dir in "${HOME}"/.claude-*/; do
        if [[ -d "$dir" ]] && [[ -f "$dir/.credentials.json" ]]; then
            local name
            name=$(basename "$dir" | sed 's/^\.claude-//')
            echo "$name $dir"
        fi
    done
}

# Check usage for a specific profile, returns 0 if available
# Sets PROFILE_UTILIZATION to the max of 5h and 7d utilization
check_profile_usage() {
    local profile_name="$1"
    local config_dir="$2"

    local usage_args=(--available --threshold "$THRESHOLD")
    if [[ "$profile_name" != "default" ]]; then
        usage_args+=(--config-dir "$config_dir")
    fi

    # Get JSON to extract utilization for comparison
    local json_args=(--json)
    if [[ "$profile_name" != "default" ]]; then
        json_args+=(--config-dir "$config_dir")
    fi

    local usage_json
    usage_json=$("$USAGE_SCRIPT" "${json_args[@]}" 2>/dev/null) || return 2

    # Extract max utilization for ranking
    PROFILE_UTILIZATION=$(echo "$usage_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
five = (data.get('five_hour') or {}).get('utilization', 0)
seven = (data.get('seven_day') or {}).get('utilization', 0)
print(max(five, seven))
" 2>/dev/null || echo 100)

    # Check against threshold
    "$USAGE_SCRIPT" "${usage_args[@]}" 2>/dev/null
    return $?
}

# Find the best available profile for dispatching
# Returns profile name on stdout, or empty if none available
find_available_profile() {
    local best_name=""
    local best_util=100

    while IFS=' ' read -r name dir; do
        if check_profile_usage "$name" "$dir"; then
            local util="$PROFILE_UTILIZATION"
            local is_lower
            if command -v bc &>/dev/null; then
                is_lower=$(echo "$util < $best_util" | bc -l 2>/dev/null || echo 0)
            else
                is_lower=$(python3 -c "print(1 if $util < $best_util else 0)" 2>/dev/null || echo 0)
            fi
            if [[ "$is_lower" == "1" ]] || [[ -z "$best_name" ]]; then
                best_name="$name"
                best_util="$util"
            fi
        fi
    done < <(list_sub_profiles)

    echo "$best_name"
}

# Get the sub profile for the next queued ticket (empty = auto)
get_next_ticket_sub() {
    python3 -c "
import json, sys
with open('$QUEUE_FILE') as f:
    queue = json.load(f)
tickets = [t for t in queue.get('tickets', []) if t.get('status') == 'queued']
if tickets:
    print(tickets[0].get('sub', ''))
else:
    sys.exit(1)
" 2>/dev/null
}

# Show all subscription profiles with current usage
cmd_profiles() {
    echo -e "${BLUE}=== Subscription Profiles ===${NC}"
    echo ""
    printf "%-12s %-30s %s\n" "PROFILE" "DIRECTORY" "USAGE"
    printf "%-12s %-30s %s\n" "-------" "---------" "-----"

    while IFS=' ' read -r name dir; do
        local usage_display
        local json_args=(--json)
        if [[ "$name" != "default" ]]; then
            json_args+=(--config-dir "$dir")
        fi

        local usage_json
        if usage_json=$("$USAGE_SCRIPT" "${json_args[@]}" 2>/dev/null); then
            usage_display=$(echo "$usage_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
five = (data.get('five_hour') or {}).get('utilization', 0)
seven = (data.get('seven_day') or {}).get('utilization', 0)
print(f'5h: {five}% | 7d: {seven}%')
" 2>/dev/null || echo "parse error")
        else
            usage_display="not authenticated"
        fi

        printf "%-12s %-30s %s\n" "$name" "$dir" "$usage_display"
    done < <(list_sub_profiles)
}

# Main daemon loop
daemon_loop() {
    log "Daemon started (PID: $$, threshold: ${THRESHOLD}%, poll: ${POLL_INTERVAL}s, cooldown: ${COOLDOWN}s)"
    echo $$ > "$PID_FILE"

    trap 'log "Daemon stopping (signal)"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT

    local last_dispatch=0

    while true; do
        # Check if queue has tickets
        local queued_count
        queued_count=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    q = json.load(f)
print(len([t for t in q.get('tickets', []) if t.get('status') == 'queued']))
" 2>/dev/null || echo 0)

        if [[ "$queued_count" -eq 0 ]]; then
            sleep "$POLL_INTERVAL"
            continue
        fi

        # Check cooldown
        local now
        now=$(date +%s)
        local since_last=$((now - last_dispatch))
        if [[ $since_last -lt $COOLDOWN && $last_dispatch -gt 0 ]]; then
            local remaining=$((COOLDOWN - since_last))
            log "Cooldown: ${remaining}s remaining before next dispatch"
            sleep "$remaining"
            continue
        fi

        # Get the next ticket's sub preference
        local ticket_sub
        ticket_sub=$(get_next_ticket_sub 2>/dev/null) || { sleep "$POLL_INTERVAL"; continue; }

        if [[ -n "$ticket_sub" ]]; then
            # Ticket has explicit sub - check only that profile
            local config_dir="${HOME}/.claude-${ticket_sub}"
            if [[ "$ticket_sub" == "default" ]]; then
                config_dir="${HOME}/.claude"
            fi

            local usage_args=(--available --threshold "$THRESHOLD")
            if [[ "$ticket_sub" != "default" ]]; then
                usage_args+=(--config-dir "$config_dir")
            fi

            if "$USAGE_SCRIPT" "${usage_args[@]}" 2>/dev/null; then
                log "Capacity available on '$ticket_sub' (below ${THRESHOLD}%), dispatching..."
                DISPATCH_SUB="" dispatch_next || true
                last_dispatch=$(date +%s)
            else
                log "Profile '$ticket_sub' rate limited, waiting... ($queued_count tickets queued)"
            fi
        else
            # No explicit sub - find any available profile
            local available_profile
            available_profile=$(find_available_profile)

            if [[ -n "$available_profile" ]]; then
                local sub_arg=""
                if [[ "$available_profile" != "default" ]]; then
                    sub_arg="$available_profile"
                fi
                log "Capacity available on '$available_profile' (below ${THRESHOLD}%), dispatching..."
                DISPATCH_SUB="$sub_arg" dispatch_next || true
                last_dispatch=$(date +%s)
            else
                log "All profiles rate limited, waiting... ($queued_count tickets queued)"
            fi
        fi

        sleep "$POLL_INTERVAL"
    done
}

# Start daemon via launchctl
cmd_start() {
    ensure_queue

    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "${YELLOW}Daemon already running (PID: $pid)${NC}"
        return 0
    fi

    local plist="$HOME/Library/LaunchAgents/com.dotfiles.ticket-queue.plist"
    if [[ ! -f "$plist" ]]; then
        echo -e "${RED}LaunchAgent plist not found: $plist${NC}"
        echo -e "Run 'stow' from ~/dotfiles to install it"
        return 1
    fi

    echo -e "${GREEN}Starting ticket queue daemon...${NC}"
    local uid
    uid=$(id -u)
    launchctl bootstrap "gui/$uid" "$plist" 2>/dev/null \
        || launchctl kickstart -k "gui/$uid/com.dotfiles.ticket-queue" 2>/dev/null \
        || true
    sleep 1
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "PID: $pid"
    fi
    echo -e "Log: $LOG_FILE"
    echo -e "Queue: $QUEUE_FILE"
    log "Daemon started via 'start' command (launchctl)"
}

# Stop daemon via launchctl
cmd_stop() {
    local uid
    uid=$(id -u)
    launchctl bootout "gui/$uid/com.dotfiles.ticket-queue" 2>/dev/null || true

    # Also kill directly in case launchctl unload didn't stop it
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo -e "Stopping daemon (PID: $pid)..."
        kill "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    echo -e "${GREEN}Daemon stopped${NC}"
    log "Daemon stopped via 'stop' command (launchctl)"
}

# Dispatch next ticket immediately (bypass usage check)
cmd_next() {
    ensure_queue
    dispatch_next
}

# Main
case "${1:-help}" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    status) cmd_status ;;
    run) daemon_loop ;;
    add) shift; cmd_add "$@" ;;
    list) cmd_list ;;
    remove|rm)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 remove <ticket-id>"; exit 1; }
        cmd_remove "$2"
        ;;
    clear) cmd_clear ;;
    next) cmd_next ;;
    profiles) cmd_profiles ;;
    help|--help|-h) show_help ;;
    *) echo "Unknown command: $1"; show_help; exit 1 ;;
esac
