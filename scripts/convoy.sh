#!/usr/bin/env bash
#
# convoy.sh - Batch work tracking (Convoy pattern)
#
# Groups related tickets into a convoy batch, tracks collective progress,
# and reports when all members complete.
#
# Storage: ~/.claude/convoys.jsonl (one JSON object per line)
#
# Usage:
#   convoy.sh create <name> [--tickets T1,T2,T3]
#   convoy.sh add <convoy-id> <ticket-key>
#   convoy.sh complete <convoy-id> <ticket-key>
#   convoy.sh fail <convoy-id> <ticket-key> --reason "msg"
#   convoy.sh status <convoy-id> [--json]
#   convoy.sh list [--active] [--json]
#   convoy.sh check <convoy-id>
#
# Exit codes:
#   0 - Success (check: all tickets complete)
#   1 - Error
#   2 - Check: not all tickets complete

set -euo pipefail

CONVOY_FILE="${HOME}/.claude/convoys.jsonl"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ensure_file() {
    mkdir -p "$(dirname "$CONVOY_FILE")"
    touch "$CONVOY_FILE"
}

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

generate_id() {
    printf 'c%x%04x' "$(date +%s)" "$((RANDOM % 65536))"
}

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# Read a convoy by ID, outputs the full JSON line
read_convoy() {
    local id="$1"
    grep "\"id\":\"${id}\"" "$CONVOY_FILE" 2>/dev/null | tail -1
}

# Update a convoy: replace the last line matching the ID
update_convoy() {
    local id="$1" new_json="$2"
    local tmp="${CONVOY_FILE}.tmp.$$"
    # Remove old entry, append new
    grep -v "\"id\":\"${id}\"" "$CONVOY_FILE" >"$tmp" 2>/dev/null || true
    echo "$new_json" >>"$tmp"
    mv "$tmp" "$CONVOY_FILE"
}

# --- Commands ---

cmd_create() {
    local name="" tickets=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --tickets)
            tickets="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            if [[ -z "$name" ]]; then
                name="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Convoy name required${NC}" >&2
        exit 1
    fi

    ensure_file

    local id ts
    id="$(generate_id)"
    ts="$(timestamp_now)"

    # Build ticket list and status object
    local ticket_arr="[]"
    local status_obj="{}"
    if [[ -n "$tickets" ]]; then
        local IFS=','
        local t_list=()
        local s_parts=()
        for t in $tickets; do
            t=$(echo "$t" | tr -d ' ')
            t_list+=("\"$t\"")
            s_parts+=("\"$t\":\"pending\"")
        done
        ticket_arr="[$(
            IFS=,
            echo "${t_list[*]}"
        )]"
        status_obj="{$(
            IFS=,
            echo "${s_parts[*]}"
        )}"
    fi

    local json="{\"id\":\"${id}\",\"name\":\"$(json_escape "$name")\",\"tickets\":${ticket_arr},\"status\":${status_obj},\"created\":\"${ts}\",\"updated\":\"${ts}\"}"
    echo "$json" >>"$CONVOY_FILE"

    echo -e "${GREEN}Created convoy${NC} ${BOLD}${id}${NC}: ${name}"
    if [[ -n "$tickets" ]]; then
        echo "  Tickets: $tickets"
    fi
    echo "$id"
}

cmd_add() {
    local convoy_id="$1" ticket_key="$2"

    if [[ -z "$convoy_id" || -z "$ticket_key" ]]; then
        echo -e "${RED}Error: convoy-id and ticket-key required${NC}" >&2
        exit 1
    fi

    ensure_file

    local line
    line=$(read_convoy "$convoy_id")
    if [[ -z "$line" ]]; then
        echo -e "${RED}Error: Convoy not found: ${convoy_id}${NC}" >&2
        exit 1
    fi

    # Add ticket using python3 for reliable JSON manipulation
    local updated
    updated=$(echo "$line" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
tk = '$ticket_key'
if tk not in c['tickets']:
    c['tickets'].append(tk)
    c['status'][tk] = 'pending'
    c['updated'] = '$(timestamp_now)'
print(json.dumps(c, separators=(',',':')))" 2>/dev/null)

    if [[ -n "$updated" ]]; then
        update_convoy "$convoy_id" "$updated"
        echo -e "${GREEN}Added${NC} ${ticket_key} to convoy ${convoy_id}"
    fi
}

cmd_complete() {
    local convoy_id="$1" ticket_key="$2"

    if [[ -z "$convoy_id" || -z "$ticket_key" ]]; then
        echo -e "${RED}Error: convoy-id and ticket-key required${NC}" >&2
        exit 1
    fi

    ensure_file

    local line
    line=$(read_convoy "$convoy_id")
    if [[ -z "$line" ]]; then
        echo -e "${RED}Error: Convoy not found: ${convoy_id}${NC}" >&2
        exit 1
    fi

    local updated
    updated=$(echo "$line" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
c['status']['$ticket_key'] = 'completed'
c['updated'] = '$(timestamp_now)'
print(json.dumps(c, separators=(',',':')))" 2>/dev/null)

    update_convoy "$convoy_id" "$updated"
    echo -e "${GREEN}Completed${NC} ${ticket_key} in convoy ${convoy_id}"

    # Check if all complete
    local all_done
    all_done=$(echo "$updated" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
all_done = all(v == 'completed' for v in c['status'].values())
print('true' if all_done else 'false')" 2>/dev/null)

    if [[ "$all_done" == "true" ]]; then
        local name
        name=$(echo "$updated" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['name'])" 2>/dev/null)
        echo -e "${GREEN}${BOLD}Convoy '${name}' is complete!${NC}"

        # Send notification via agent-mail if available
        local mail_script
        mail_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agent-mail.sh"
        if [[ -x "$mail_script" ]]; then
            "$mail_script" send all -s "Convoy Complete: ${name}" -m "All tickets in convoy ${convoy_id} (${name}) have completed." --from "convoy" 2>/dev/null || true
        fi
    fi
}

cmd_fail() {
    local convoy_id="" ticket_key="" reason=""

    # Parse positional + flags
    local positional=0
    while [[ $# -gt 0 ]]; do
        case $1 in
        --reason)
            reason="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            positional=$((positional + 1))
            case $positional in
            1) convoy_id="$1" ;;
            2) ticket_key="$1" ;;
            esac
            shift
            ;;
        esac
    done

    if [[ -z "$convoy_id" || -z "$ticket_key" ]]; then
        echo -e "${RED}Error: convoy-id and ticket-key required${NC}" >&2
        exit 1
    fi

    ensure_file

    local line
    line=$(read_convoy "$convoy_id")
    if [[ -z "$line" ]]; then
        echo -e "${RED}Error: Convoy not found: ${convoy_id}${NC}" >&2
        exit 1
    fi

    local escaped_reason
    escaped_reason=$(json_escape "${reason:-unknown}")

    local updated
    updated=$(echo "$line" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
c['status']['$ticket_key'] = 'failed'
c['updated'] = '$(timestamp_now)'
if 'failures' not in c:
    c['failures'] = {}
c['failures']['$ticket_key'] = '$escaped_reason'
print(json.dumps(c, separators=(',',':')))" 2>/dev/null)

    update_convoy "$convoy_id" "$updated"
    echo -e "${RED}Failed${NC} ${ticket_key} in convoy ${convoy_id}: ${reason:-unknown}"
}

cmd_status() {
    local convoy_id="" json_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --json)
            json_mode=true
            shift
            ;;
        -*) shift ;;
        *)
            if [[ -z "$convoy_id" ]]; then
                convoy_id="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$convoy_id" ]]; then
        echo -e "${RED}Error: convoy-id required${NC}" >&2
        exit 1
    fi

    ensure_file

    local line
    line=$(read_convoy "$convoy_id")
    if [[ -z "$line" ]]; then
        echo -e "${RED}Error: Convoy not found: ${convoy_id}${NC}" >&2
        exit 1
    fi

    if $json_mode; then
        echo "$line" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
total = len(c['status'])
completed = sum(1 for v in c['status'].values() if v == 'completed')
failed = sum(1 for v in c['status'].values() if v == 'failed')
c['summary'] = {'total': total, 'completed': completed, 'failed': failed, 'remaining': total - completed - failed}
print(json.dumps(c, indent=2))" 2>/dev/null
        return
    fi

    echo "$line" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
total = len(c['status'])
completed = sum(1 for v in c['status'].values() if v == 'completed')
failed = sum(1 for v in c['status'].values() if v == 'failed')
running = sum(1 for v in c['status'].values() if v == 'running')
pending = sum(1 for v in c['status'].values() if v == 'pending')

print(f\"Convoy: {c['name']} ({c['id']})\")
print(f\"Progress: {completed}/{total} complete\")
if failed: print(f\"Failed: {failed}\")
if running: print(f\"Running: {running}\")
if pending: print(f\"Pending: {pending}\")
print(f\"Created: {c['created']}\")
print()
for ticket, status in c['status'].items():
    icon = {'completed': '\033[0;32m✓\033[0m', 'failed': '\033[0;31m✗\033[0m', 'running': '\033[0;34m→\033[0m', 'pending': '\033[2m·\033[0m'}.get(status, '?')
    print(f'  {icon} {ticket}: {status}')
" 2>/dev/null
}

cmd_list() {
    local active_only=false json_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --active)
            active_only=true
            shift
            ;;
        --json)
            json_mode=true
            shift
            ;;
        *) shift ;;
        esac
    done

    ensure_file

    if [[ ! -s "$CONVOY_FILE" ]]; then
        if $json_mode; then
            echo "[]"
        else
            echo "No convoys."
        fi
        return 0
    fi

    if $json_mode; then
        python3 -c "
import sys, json
convoys = []
for line in open('$CONVOY_FILE'):
    line = line.strip()
    if not line: continue
    c = json.loads(line)
    total = len(c['status'])
    completed = sum(1 for v in c['status'].values() if v == 'completed')
    failed = sum(1 for v in c['status'].values() if v == 'failed')
    active_only = $([[ "$active_only" == "true" ]] && echo "True" || echo "False")
    is_complete = (completed + failed) == total and total > 0
    if active_only and is_complete:
        continue
    c['summary'] = {'total': total, 'completed': completed, 'failed': failed, 'remaining': total - completed - failed}
    convoys.append(c)
print(json.dumps(convoys, indent=2))" 2>/dev/null
        return
    fi

    echo -e "${BLUE}=== Convoys ===${NC}"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        python3 -c "
import sys, json
c = json.loads('$(echo "$line" | sed "s/'/\\\\'/g")')
total = len(c['status'])
completed = sum(1 for v in c['status'].values() if v == 'completed')
failed = sum(1 for v in c['status'].values() if v == 'failed')
active_only = $([[ "$active_only" == "true" ]] && echo "True" || echo "False")
is_complete = (completed + failed) == total and total > 0
if active_only and is_complete:
    sys.exit(0)
bar_len = 20
filled = int(completed / total * bar_len) if total > 0 else 0
bar = '█' * filled + '░' * (bar_len - filled)
status_color = '\033[0;32m' if is_complete else '\033[0;34m'
print(f\"  {status_color}{c['id']}\033[0m  {c['name']}  [{bar}] {completed}/{total}\")
" 2>/dev/null || true
    done <"$CONVOY_FILE"
}

cmd_check() {
    local convoy_id="$1"

    if [[ -z "$convoy_id" ]]; then
        echo -e "${RED}Error: convoy-id required${NC}" >&2
        exit 1
    fi

    ensure_file

    local line
    line=$(read_convoy "$convoy_id")
    if [[ -z "$line" ]]; then
        echo -e "${RED}Error: Convoy not found: ${convoy_id}${NC}" >&2
        exit 1
    fi

    local all_done
    all_done=$(echo "$line" | python3 -c "
import sys, json
c = json.loads(sys.stdin.read())
total = len(c['status'])
completed = sum(1 for v in c['status'].values() if v == 'completed')
print('true' if completed == total and total > 0 else 'false')" 2>/dev/null)

    if [[ "$all_done" == "true" ]]; then
        exit 0
    else
        exit 2
    fi
}

# --- Main ---

show_help() {
    echo "convoy.sh - Batch work tracking (Convoy pattern)"
    echo ""
    echo "USAGE:"
    echo "  convoy.sh <command> [args...]"
    echo ""
    echo "COMMANDS:"
    echo "  create <name> [--tickets T1,T2,T3]     Create a convoy"
    echo "  add <convoy-id> <ticket-key>            Add ticket to convoy"
    echo "  complete <convoy-id> <ticket-key>       Mark ticket complete"
    echo "  fail <convoy-id> <ticket-key> [--reason] Mark ticket failed"
    echo "  status <convoy-id> [--json]             Show convoy progress"
    echo "  list [--active] [--json]                List convoys"
    echo "  check <convoy-id>                       Exit 0 if all complete"
    echo ""
    echo "STORAGE:"
    echo "  ${CONVOY_FILE}"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
create) cmd_create "$@" ;;
add) cmd_add "$@" ;;
complete) cmd_complete "$@" ;;
fail) cmd_fail "$@" ;;
status) cmd_status "$@" ;;
list) cmd_list "$@" ;;
check) cmd_check "$@" ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    exit 1
    ;;
esac
