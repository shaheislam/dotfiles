#!/usr/bin/env bash
#
# agent-mail.sh - Lightweight persistent mail for agent worktrees
#
# JSONL-based persistent mail at ~/.claude/agent-mail.jsonl.
# Enables inter-agent messaging and completion notifications.
#
# Usage:
#   agent-mail.sh send <recipient> -s "subject" -m "message" [--from <sender>]
#   agent-mail.sh inbox [--for <agent>] [--unread]
#   agent-mail.sh read <id>
#   agent-mail.sh count [--for <agent>]
#
# Recipients are worktree basenames or "all" for broadcast.
#
# Exit codes:
#   0 - Success
#   1 - Error (bad args, missing deps)

set -euo pipefail

MAIL_FILE="${HOME}/.claude/agent-mail.jsonl"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Helpers ---

ensure_mail_file() {
    mkdir -p "$(dirname "$MAIL_FILE")"
    touch "$MAIL_FILE"
}

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

generate_id() {
    # Short unique ID: timestamp hex + random
    printf '%x%04x' "$(date +%s)" "$((RANDOM % 65536))"
}

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# --- Commands ---

cmd_send() {
    local recipient=""
    local subject=""
    local message=""
    local from="${USER:-agent}"

    while [[ $# -gt 0 ]]; do
        case $1 in
        -s | --subject)
            subject="$2"
            shift 2
            ;;
        -m | --message)
            message="$2"
            shift 2
            ;;
        --from)
            from="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            if [[ -z "$recipient" ]]; then
                recipient="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$recipient" || -z "$subject" || -z "$message" ]]; then
        echo -e "${RED}Error: Missing required arguments${NC}" >&2
        echo "Usage: agent-mail.sh send <recipient> -s \"subject\" -m \"message\" [--from <sender>]" >&2
        exit 1
    fi

    ensure_mail_file

    local id ts json
    id="$(generate_id)"
    ts="$(timestamp_now)"

    json=$(printf '{"id":"%s","from":"%s","to":"%s","subject":"%s","body":"%s","timestamp":"%s","read":false}' \
        "$id" \
        "$(json_escape "$from")" \
        "$(json_escape "$recipient")" \
        "$(json_escape "$subject")" \
        "$(json_escape "$message")" \
        "$ts")

    echo "$json" >>"$MAIL_FILE"

    echo -e "${GREEN}Sent${NC} to ${BOLD}${recipient}${NC}: ${subject}"
}

cmd_inbox() {
    local for_agent=""
    local unread_only=false
    local json_output=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --for)
            for_agent="$2"
            shift 2
            ;;
        --unread)
            unread_only=true
            shift
            ;;
        --json)
            json_output=true
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            shift
            ;;
        esac
    done

    ensure_mail_file

    if [[ ! -s "$MAIL_FILE" ]]; then
        if $json_output; then
            echo "[]"
        else
            echo "No messages."
        fi
        return 0
    fi

    # JSON output mode: collect matching lines into a JSON array
    if $json_output; then
        local first=true
        echo -n "["
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local to read_status
            to=$(echo "$line" | grep -o '"to":"[^"]*"' | cut -d'"' -f4 || true)
            read_status=$(echo "$line" | grep -o '"read":\(true\|false\)' | cut -d: -f2 || echo "false")
            if [[ -n "$for_agent" && "$to" != "$for_agent" && "$to" != "all" ]]; then
                continue
            fi
            if $unread_only && [[ "$read_status" == "true" ]]; then
                continue
            fi
            if $first; then
                first=false
            else
                echo -n ","
            fi
            echo -n "$line"
        done <"$MAIL_FILE"
        echo "]"
        return 0
    fi

    local found=false
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local to read_status id subject from ts
        to=$(echo "$line" | grep -o '"to":"[^"]*"' | cut -d'"' -f4 || true)
        read_status=$(echo "$line" | grep -o '"read":\(true\|false\)' | cut -d: -f2 || echo "false")
        id=$(echo "$line" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || true)
        subject=$(echo "$line" | grep -o '"subject":"[^"]*"' | cut -d'"' -f4 || true)
        from=$(echo "$line" | grep -o '"from":"[^"]*"' | cut -d'"' -f4 || true)
        ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4 || true)

        # Filter by recipient
        if [[ -n "$for_agent" && "$to" != "$for_agent" && "$to" != "all" ]]; then
            continue
        fi

        # Filter by read status
        if $unread_only && [[ "$read_status" == "true" ]]; then
            continue
        fi

        found=true

        local status_icon
        if [[ "$read_status" == "true" ]]; then
            status_icon="${DIM} ${NC}"
        else
            status_icon="${YELLOW}*${NC}"
        fi

        local short_ts="${ts:0:10} ${ts:11:5}"
        echo -e "  ${status_icon} ${DIM}${id}${NC}  ${short_ts}  ${BLUE}${from}${NC} -> ${BOLD}${to}${NC}  ${subject}"
    done <"$MAIL_FILE"

    if ! $found; then
        if $unread_only; then
            echo "No unread messages."
        else
            echo "No messages."
        fi
    fi
}

cmd_read_msg() {
    local msg_id="$1"

    if [[ -z "$msg_id" ]]; then
        echo -e "${RED}Error: Missing message ID${NC}" >&2
        echo "Usage: agent-mail.sh read <id>" >&2
        exit 1
    fi

    ensure_mail_file

    local line
    line=$(grep "\"id\":\"${msg_id}\"" "$MAIL_FILE" 2>/dev/null | head -1 || true)

    if [[ -z "$line" ]]; then
        echo -e "${RED}Error: Message not found: ${msg_id}${NC}" >&2
        exit 1
    fi

    # Mark as read
    local tmp="${MAIL_FILE}.tmp"
    sed "s/\"id\":\"${msg_id}\",\(.*\)\"read\":false/\"id\":\"${msg_id}\",\1\"read\":true/" \
        "$MAIL_FILE" >"$tmp" && mv "$tmp" "$MAIL_FILE"

    # Display
    local from to subject body ts
    from=$(echo "$line" | grep -o '"from":"[^"]*"' | cut -d'"' -f4 || true)
    to=$(echo "$line" | grep -o '"to":"[^"]*"' | cut -d'"' -f4 || true)
    subject=$(echo "$line" | grep -o '"subject":"[^"]*"' | cut -d'"' -f4 || true)
    body=$(echo "$line" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 || true)
    ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4 || true)

    echo ""
    echo -e "${BOLD}From:${NC}    ${from}"
    echo -e "${BOLD}To:${NC}      ${to}"
    echo -e "${BOLD}Subject:${NC} ${subject}"
    echo -e "${BOLD}Date:${NC}    ${ts}"
    echo -e "${DIM}$(printf '%.0s─' {1..50})${NC}"
    echo -e "${body}"
    echo ""
}

cmd_count() {
    local for_agent=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --for)
            for_agent="$2"
            shift 2
            ;;
        -*)
            shift
            ;;
        *)
            shift
            ;;
        esac
    done

    ensure_mail_file

    if [[ ! -s "$MAIL_FILE" ]]; then
        echo "0"
        return 0
    fi

    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local to read_status
        to=$(echo "$line" | grep -o '"to":"[^"]*"' | cut -d'"' -f4 || true)
        read_status=$(echo "$line" | grep -o '"read":\(true\|false\)' | cut -d: -f2 || echo "false")

        # Filter by recipient
        if [[ -n "$for_agent" && "$to" != "$for_agent" && "$to" != "all" ]]; then
            continue
        fi

        # Count unread only
        if [[ "$read_status" == "false" ]]; then
            count=$((count + 1))
        fi
    done <"$MAIL_FILE"

    echo "$count"
}

# --- Main ---

show_help() {
    echo "agent-mail.sh - Lightweight persistent mail for agent worktrees"
    echo ""
    echo "USAGE:"
    echo "  agent-mail.sh <command> [args...]"
    echo ""
    echo "COMMANDS:"
    echo "  send <recipient> -s \"subject\" -m \"message\" [--from <sender>]"
    echo "                              Send a message"
    echo "  inbox [--for <agent>] [--unread]"
    echo "                              List messages"
    echo "  read <id>                   Mark as read and display"
    echo "  count [--for <agent>]       Count unread messages"
    echo ""
    echo "RECIPIENTS:"
    echo "  Worktree basenames or \"all\" for broadcast."
    echo ""
    echo "STORAGE:"
    echo "  ${MAIL_FILE}"
    echo ""
    echo "EXAMPLES:"
    echo "  agent-mail.sh send fix-auth -s 'Completed' -m 'All tests passing'"
    echo "  agent-mail.sh send all -s 'Alert' -m 'Main branch updated' --from merge-queue"
    echo "  agent-mail.sh inbox --for fix-auth --unread"
    echo "  agent-mail.sh count --for fix-auth"
    echo "  agent-mail.sh read abc123"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
send)
    cmd_send "$@"
    ;;
inbox)
    cmd_inbox "$@"
    ;;
read)
    cmd_read_msg "$@"
    ;;
count)
    cmd_count "$@"
    ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    echo "Run 'agent-mail.sh help' for usage" >&2
    exit 1
    ;;
esac
