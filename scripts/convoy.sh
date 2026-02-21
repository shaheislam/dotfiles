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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/json-helpers.sh"

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

    # Add ticket using jq for reliable JSON manipulation
    local updated
    updated=$(echo "$line" | jq -c --arg tk "$ticket_key" --arg ts "$(timestamp_now)" '
      if (.tickets | index($tk)) == null then
        .tickets += [$tk] | .status[$tk] = "pending" | .updated = $ts
      else . end
    ')

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
    updated=$(echo "$line" | jq -c --arg tk "$ticket_key" --arg ts "$(timestamp_now)" '
      .status[$tk] = "completed" | .updated = $ts
    ')

    update_convoy "$convoy_id" "$updated"
    echo -e "${GREEN}Completed${NC} ${ticket_key} in convoy ${convoy_id}"

    # Check if all complete
    local all_done
    all_done=$(echo "$updated" | jq -r '[.status[]] | all(. == "completed") | tostring')

    if [[ "$all_done" == "true" ]]; then
        local name
        name=$(echo "$updated" | jq -r '.name')
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
    updated=$(echo "$line" | jq -c --arg tk "$ticket_key" --arg ts "$(timestamp_now)" --arg reason "$escaped_reason" '
      .status[$tk] = "failed" | .updated = $ts |
      .failures = (.failures // {}) | .failures[$tk] = $reason
    ')

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
        echo "$line" | jq '{
          id, name, tickets, status, created, updated,
          summary: {
            total: (.status | length),
            completed: ([.status[] | select(. == "completed")] | length),
            failed: ([.status[] | select(. == "failed")] | length),
            remaining: ((.status | length) - ([.status[] | select(. == "completed")] | length) - ([.status[] | select(. == "failed")] | length))
          }
        } + (if .failures then {failures} else {} end)'
        return
    fi

    # Extract data with jq, format in bash
    local c_name c_id c_created total completed failed running pending ticket_lines
    c_name=$(echo "$line" | jq -r '.name')
    c_id=$(echo "$line" | jq -r '.id')
    c_created=$(echo "$line" | jq -r '.created')
    total=$(echo "$line" | jq '.status | length')
    completed=$(echo "$line" | jq '[.status[] | select(. == "completed")] | length')
    failed=$(echo "$line" | jq '[.status[] | select(. == "failed")] | length')
    running=$(echo "$line" | jq '[.status[] | select(. == "running")] | length')
    pending=$(echo "$line" | jq '[.status[] | select(. == "pending")] | length')

    echo "Convoy: ${c_name} (${c_id})"
    echo "Progress: ${completed}/${total} complete"
    [[ "$failed" -gt 0 ]] && echo "Failed: ${failed}"
    [[ "$running" -gt 0 ]] && echo "Running: ${running}"
    [[ "$pending" -gt 0 ]] && echo "Pending: ${pending}"
    echo "Created: ${c_created}"
    echo

    ticket_lines=$(echo "$line" | jq -r '.status | to_entries[] | "\(.key)\t\(.value)"')
    while IFS=$'\t' read -r ticket status; do
        [[ -z "$ticket" ]] && continue
        local icon
        case "$status" in
        completed) icon="${GREEN}✓${NC}" ;;
        failed) icon="${RED}✗${NC}" ;;
        running) icon="${BLUE}→${NC}" ;;
        pending) icon="${DIM}·${NC}" ;;
        *) icon="?" ;;
        esac
        echo -e "  ${icon} ${ticket}: ${status}"
    done <<<"$ticket_lines"
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
        local filter_expr
        if $active_only; then
            filter_expr='[.[] | . + {
              summary: {
                total: (.status | length),
                completed: ([.status[] | select(. == "completed")] | length),
                failed: ([.status[] | select(. == "failed")] | length),
                remaining: ((.status | length) - ([.status[] | select(. == "completed")] | length) - ([.status[] | select(. == "failed")] | length))
              }
            } | select((.status | length) == 0 or ((.summary.completed + .summary.failed) < .summary.total))]'
        else
            filter_expr='[.[] | . + {
              summary: {
                total: (.status | length),
                completed: ([.status[] | select(. == "completed")] | length),
                failed: ([.status[] | select(. == "failed")] | length),
                remaining: ((.status | length) - ([.status[] | select(. == "completed")] | length) - ([.status[] | select(. == "failed")] | length))
              }
            }]'
        fi
        jq -s "$filter_expr" "$CONVOY_FILE"
        return
    fi

    echo -e "${BLUE}=== Convoys ===${NC}"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local c_id c_name total completed failed is_complete
        c_id=$(echo "$line" | jq -r '.id')
        c_name=$(echo "$line" | jq -r '.name')
        total=$(echo "$line" | jq '.status | length')
        completed=$(echo "$line" | jq '[.status[] | select(. == "completed")] | length')
        failed=$(echo "$line" | jq '[.status[] | select(. == "failed")] | length')

        is_complete=false
        if [[ "$total" -gt 0 ]] && [[ $((completed + failed)) -eq "$total" ]]; then
            is_complete=true
        fi

        if $active_only && $is_complete; then
            continue
        fi

        # Build progress bar
        local bar_len=20 filled=0
        if [[ "$total" -gt 0 ]]; then
            filled=$((completed * bar_len / total))
        fi
        local bar=""
        local i
        for ((i = 0; i < filled; i++)); do bar+="█"; done
        for ((i = filled; i < bar_len; i++)); do bar+="░"; done

        local status_color
        if $is_complete; then
            status_color="${GREEN}"
        else
            status_color="${BLUE}"
        fi
        echo -e "  ${status_color}${c_id}${NC}  ${c_name}  [${bar}] ${completed}/${total}"
    done <"$CONVOY_FILE"
}

cmd_find_or_create() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Convoy name required${NC}" >&2
        exit 1
    fi

    ensure_file

    # Look for an active convoy with this name
    if [[ -s "$CONVOY_FILE" ]]; then
        local existing_id
        existing_id=$(jq -r --arg name "$name" '
          select(.name == $name) |
          select((.status | length) == 0 or (([.status[] | select(. == "completed" or . == "failed")] | length) < (.status | length))) |
          .id
        ' "$CONVOY_FILE" 2>/dev/null | head -1)
        if [[ -n "$existing_id" ]]; then
            echo "$existing_id"
            return 0
        fi
    fi

    # No active convoy with this name — create one
    local id ts
    id="$(generate_id)"
    ts="$(timestamp_now)"
    local json="{\"id\":\"${id}\",\"name\":\"$(json_escape "$name")\",\"tickets\":[],\"status\":{},\"created\":\"${ts}\",\"updated\":\"${ts}\"}"
    echo "$json" >>"$CONVOY_FILE"
    echo -e "${GREEN}Created convoy${NC} ${BOLD}${id}${NC}: ${name}" >&2
    echo "$id"
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
    all_done=$(echo "$line" | jq -r '
      if (.status | length) > 0 and ([.status[] | select(. == "completed")] | length) == (.status | length)
      then "true" else "false" end
    ')

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
    echo "  find-or-create <name>                   Find active convoy by name or create new"
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
find-or-create) cmd_find_or_create "$@" ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    exit 1
    ;;
esac
