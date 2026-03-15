#!/usr/bin/env bash
# Harness Engineering: Telemetry Query Interface
# Allows agents (and humans) to query JSONL failure/notification logs.
# Closes the verification loop by making telemetry readable, not just writable.
#
# Usage:
#   query-telemetry.sh failures [--days N] [--tool TOOL] [--pattern REGEX]
#   query-telemetry.sh notifications [--days N] [--type TYPE]
#   query-telemetry.sh summary [--days N]
#   query-telemetry.sh top-failures [--days N] [--limit N]
#   query-telemetry.sh error-rate [--days N]

set -euo pipefail

LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/hooks/logs}"
DEFAULT_DAYS=7
DEFAULT_LIMIT=10

# --- Helpers ---

usage() {
    cat <<'EOF'
Usage: query-telemetry.sh <command> [options]

Commands:
  failures        Show tool failure entries
  notifications   Show notification entries
  summary         Aggregate summary (counts by tool, by day)
  top-failures    Most frequent failure tools/patterns
  error-rate      Daily error rate trend

Options:
  --days N        Look back N days (default: 7)
  --tool TOOL     Filter failures by tool name
  --pattern REGEX Filter by error message regex
  --type TYPE     Filter notifications by type
  --limit N       Max results for top-failures (default: 10)
  --json          Output as JSON (default: human-readable)
EOF
    exit 1
}

collect_failure_files() {
    local days="$1"
    local files=()
    for i in $(seq 0 "$days"); do
        local date_str
        date_str=$(date -v-"${i}d" "+%Y-%m-%d" 2>/dev/null || date -d "$i days ago" "+%Y-%m-%d" 2>/dev/null)
        local f="$LOG_DIR/tool-failures-${date_str}.jsonl"
        if [ -f "$f" ]; then
            files+=("$f")
        fi
    done
    printf '%s\n' "${files[@]}"
}

collect_notification_files() {
    local days="$1"
    local files=()
    for i in $(seq 0 "$days"); do
        local date_str
        date_str=$(date -v-"${i}d" "+%Y-%m-%d" 2>/dev/null || date -d "$i days ago" "+%Y-%m-%d" 2>/dev/null)
        local f="$LOG_DIR/notifications-${date_str}.log"
        if [ -f "$f" ]; then
            files+=("$f")
        fi
    done
    printf '%s\n' "${files[@]}"
}

# --- Commands ---

cmd_failures() {
    local days="$DEFAULT_DAYS" tool="" pattern="" json=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --days)
            days="$2"
            shift 2
            ;;
        --tool)
            tool="$2"
            shift 2
            ;;
        --pattern)
            pattern="$2"
            shift 2
            ;;
        --json)
            json=true
            shift
            ;;
        *) shift ;;
        esac
    done

    local files
    files=$(collect_failure_files "$days")
    if [ -z "$files" ]; then
        echo "No failure logs found in the last $days days."
        return 0
    fi

    local filter="."
    if [ -n "$tool" ]; then
        filter="select(.tool_name == \"$tool\")"
    fi
    if [ -n "$pattern" ]; then
        filter="$filter | select(.error | test(\"$pattern\"; \"i\"))"
    fi

    if $json; then
        echo "$files" | xargs cat 2>/dev/null | jq -c "$filter" 2>/dev/null
    else
        echo "=== Tool Failures (last $days days) ==="
        echo "$files" | xargs cat 2>/dev/null | jq -r "$filter | \"\(.timestamp) | \(.tool_name) | \(.error[:80])\"" 2>/dev/null | tail -50
    fi
}

cmd_notifications() {
    local days="$DEFAULT_DAYS" type=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --days)
            days="$2"
            shift 2
            ;;
        --type)
            type="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    local files
    files=$(collect_notification_files "$days")
    if [ -z "$files" ]; then
        echo "No notification logs found in the last $days days."
        return 0
    fi

    echo "=== Notifications (last $days days) ==="
    if [ -n "$type" ]; then
        echo "$files" | xargs grep -i "Type: $type" 2>/dev/null | tail -50
    else
        echo "$files" | xargs cat 2>/dev/null | tail -50
    fi
}

cmd_summary() {
    local days="$DEFAULT_DAYS"
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --days)
            days="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    local files
    files=$(collect_failure_files "$days")

    echo "=== Telemetry Summary (last $days days) ==="
    echo ""

    if [ -z "$files" ]; then
        echo "No failure logs found."
    else
        local total
        total=$(echo "$files" | xargs cat 2>/dev/null | wc -l | tr -d ' ')
        echo "Total failures: $total"
        echo ""

        echo "Failures by tool:"
        echo "$files" | xargs cat 2>/dev/null | jq -r '.tool_name' 2>/dev/null | sort | uniq -c | sort -rn | head -10
        echo ""

        echo "Failures by day:"
        echo "$files" | xargs cat 2>/dev/null | jq -r '.timestamp[:10]' 2>/dev/null | sort | uniq -c | sort -k2
    fi

    echo ""
    local nfiles
    nfiles=$(collect_notification_files "$days")
    if [ -z "$nfiles" ]; then
        echo "No notification logs found."
    else
        local ntotal
        ntotal=$(echo "$nfiles" | xargs cat 2>/dev/null | wc -l | tr -d ' ')
        echo "Total notifications: $ntotal"
    fi
}

cmd_top_failures() {
    local days="$DEFAULT_DAYS" limit="$DEFAULT_LIMIT" json=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --days)
            days="$2"
            shift 2
            ;;
        --limit)
            limit="$2"
            shift 2
            ;;
        --json)
            json=true
            shift
            ;;
        *) shift ;;
        esac
    done

    local files
    files=$(collect_failure_files "$days")
    if [ -z "$files" ]; then
        echo "No failure logs found in the last $days days."
        return 0
    fi

    if $json; then
        echo "$files" | xargs cat 2>/dev/null |
            jq -r '.tool_name + " | " + (.error[:60])' 2>/dev/null |
            sort | uniq -c | sort -rn | head -"$limit" |
            jq -R -s 'split("\n") | map(select(length > 0)) | map(capture("^\\s*(?<count>[0-9]+)\\s+(?<pattern>.+)$")) | map({count: (.count | tonumber), pattern: .pattern})'
    else
        echo "=== Top Failure Patterns (last $days days, limit $limit) ==="
        echo "$files" | xargs cat 2>/dev/null |
            jq -r '.tool_name + " | " + (.error[:60])' 2>/dev/null |
            sort | uniq -c | sort -rn | head -"$limit"
    fi
}

cmd_error_rate() {
    local days="$DEFAULT_DAYS"
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --days)
            days="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    echo "=== Daily Error Rate (last $days days) ==="
    echo ""
    printf "%-12s %8s\n" "Date" "Failures"
    printf "%-12s %8s\n" "----" "--------"

    for i in $(seq "$days" -1 0); do
        local date_str
        date_str=$(date -v-"${i}d" "+%Y-%m-%d" 2>/dev/null || date -d "$i days ago" "+%Y-%m-%d" 2>/dev/null)
        local f="$LOG_DIR/tool-failures-${date_str}.jsonl"
        local count=0
        if [ -f "$f" ]; then
            count=$(wc -l <"$f" | tr -d ' ')
        fi
        printf "%-12s %8d\n" "$date_str" "$count"
    done
}

# --- Main ---

if [ $# -lt 1 ]; then
    usage
fi

command="$1"
shift

case "$command" in
failures) cmd_failures "$@" ;;
notifications) cmd_notifications "$@" ;;
summary) cmd_summary "$@" ;;
top-failures) cmd_top_failures "$@" ;;
error-rate) cmd_error_rate "$@" ;;
-h | --help) usage ;;
*)
    echo "Unknown command: $command"
    usage
    ;;
esac
