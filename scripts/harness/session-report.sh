#!/usr/bin/env bash
# Harness Engineering: Session Health Report
# Generates a summary of the current/recent session for agent continuity.
# Designed to run at SessionEnd or on-demand to capture session metrics.
#
# Usage:
#   session-report.sh              # Generate report for today
#   session-report.sh --days N     # Summarize last N days
#   session-report.sh --json       # Output as JSON for agent consumption

set -euo pipefail

LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/hooks/logs}"
REPORT_DIR="$HOME/.claude/harness"
REPORT_FILE="$REPORT_DIR/session-reports.jsonl"

json_output=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --json)
        json_output=true
        shift
        ;;
    *) shift ;;
    esac
done

mkdir -p "$REPORT_DIR"

# Collect metrics
failures_today=0
notifications_today=0
failure_tools=""
top_error=""
date_str=$(date "+%Y-%m-%d")

# Count failures
failure_file="$LOG_DIR/tool-failures-${date_str}.jsonl"
if [ -f "$failure_file" ]; then
    failures_today=$(wc -l <"$failure_file" | tr -d ' ')
    failure_tools=$(jq -r '.tool_name' "$failure_file" 2>/dev/null | sort | uniq -c | sort -rn | head -3 | awk '{print $2 "(" $1 ")"}' | tr '\n' ',' | sed 's/,$//')
    top_error=$(jq -r '.error[:60]' "$failure_file" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | sed 's/^ *//')
fi

# Count notifications
notification_file="$LOG_DIR/notifications-${date_str}.log"
if [ -f "$notification_file" ]; then
    notifications_today=$(wc -l <"$notification_file" | tr -d ' ')
fi

# Check beads status
beads_open=0
beads_closed_today=0
if command -v bd &>/dev/null; then
    beads_open=$(bd list --status=open 2>/dev/null | wc -l | tr -d ' ')
    beads_closed_today=$(bd list --status=closed 2>/dev/null | grep -c "$(date '+%Y-%m-%d')" 2>/dev/null || echo 0)
fi

# Check git activity
commits_today=0
files_changed=0
if git rev-parse --is-inside-work-tree &>/dev/null; then
    commits_today=$(git log --oneline --since="$date_str" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$commits_today" -gt 0 ] 2>/dev/null; then
        files_changed=$(git diff --stat HEAD~"$commits_today" HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || true)
    fi
fi

# Sanitize numeric values for jq
: "${failures_today:=0}"
[[ "$failures_today" =~ ^[0-9]+$ ]] || failures_today=0
: "${notifications_today:=0}"
[[ "$notifications_today" =~ ^[0-9]+$ ]] || notifications_today=0
: "${beads_open:=0}"
[[ "$beads_open" =~ ^[0-9]+$ ]] || beads_open=0
: "${beads_closed_today:=0}"
[[ "$beads_closed_today" =~ ^[0-9]+$ ]] || beads_closed_today=0
: "${commits_today:=0}"
[[ "$commits_today" =~ ^[0-9]+$ ]] || commits_today=0
: "${files_changed:=0}"
[[ "$files_changed" =~ ^[0-9]+$ ]] || files_changed=0

# Build report
report=$(jq -n \
    --arg date "$date_str" \
    --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --argjson failures "$failures_today" \
    --argjson notifications "$notifications_today" \
    --arg failure_tools "${failure_tools:-none}" \
    --arg top_error "${top_error:-none}" \
    --argjson beads_open "$beads_open" \
    --argjson beads_closed "$beads_closed_today" \
    --argjson commits "$commits_today" \
    --argjson files_changed "$files_changed" \
    '{
        date: $date,
        timestamp: $timestamp,
        failures: $failures,
        notifications: $notifications,
        failure_tools: $failure_tools,
        top_error: $top_error,
        beads_open: $beads_open,
        beads_closed_today: $beads_closed,
        commits_today: $commits,
        files_changed: $files_changed
    }')

# Output
if $json_output; then
    echo "$report"
else
    echo "=== Session Health Report ($date_str) ==="
    echo ""
    echo "  Tool failures:       $failures_today"
    echo "  Top failing tools:   ${failure_tools:-none}"
    echo "  Top error pattern:   ${top_error:-none}"
    echo "  Notifications:       $notifications_today"
    echo "  Beads open:          $beads_open"
    echo "  Beads closed today:  $beads_closed_today"
    echo "  Commits today:       $commits_today"
    echo "  Files changed:       ${files_changed:-0}"
    echo ""

    if [ "$failures_today" -gt 10 ]; then
        echo "  WARNING: High failure rate ($failures_today). Review with:"
        echo "    scripts/harness/query-telemetry.sh top-failures --days 1"
    fi
fi

# Append to persistent report log
echo "$report" >>"$REPORT_FILE"
