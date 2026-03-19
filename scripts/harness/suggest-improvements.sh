#!/usr/bin/env bash
# Harness Engineering: Self-Improvement Loop
# Analyzes failure telemetry and feature status to suggest concrete harness improvements.
# Closes the feedback loop: telemetry → analysis → actionable suggestions.
#
# Usage:
#   suggest-improvements.sh              # Analyze and suggest
#   suggest-improvements.sh --json       # Output suggestions as JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/hooks/logs}"
REPORT_FILE="$HOME/.claude/harness/session-reports.jsonl"
FEATURES_FILE="$SCRIPT_DIR/harness-features.json"

json_output=false
[[ "${1:-}" == "--json" ]] && json_output=true

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

suggestions=()

add_suggestion() {
    local priority="$1" category="$2" suggestion="$3" action="$4"
    suggestions+=("$(jq -nc \
        --arg p "$priority" \
        --arg c "$category" \
        --arg s "$suggestion" \
        --arg a "$action" \
        '{priority: $p, category: $c, suggestion: $s, action: $a}')")
}

# ─────────────────────────────────────────────────────
# 1. Analyze failing harness features
# ─────────────────────────────────────────────────────
if [ -f "$FEATURES_FILE" ]; then
    failing=$(jq -r '.[] | select(.passes == false) | .id' "$FEATURES_FILE" 2>/dev/null)
    for feature in $failing; do
        case "$feature" in
        pre-commit-hooks)
            add_suggestion "HIGH" "constraints" \
                "Pre-commit hooks not activated — commits bypass structural validation" \
                "Run: scripts/harness/init.sh (activates git core.hooksPath)"
            ;;
        session-report)
            add_suggestion "HIGH" "feedback-loop" \
                "Session reports not wired into SessionEnd — health data not captured automatically" \
                "Add session-report.sh to SessionEnd hook in .claude/settings.json"
            ;;
        self-improvement)
            add_suggestion "MEDIUM" "feedback-loop" \
                "Self-improvement script missing — no automated feedback-to-harness path" \
                "Create scripts/harness/suggest-improvements.sh"
            ;;
        harness-init)
            add_suggestion "MEDIUM" "initializer" \
                "Harness init script missing — no bootstrap for new environments" \
                "Create scripts/harness/init.sh"
            ;;
        *)
            add_suggestion "LOW" "general" \
                "Feature '$feature' is failing" \
                "Run verify-harness.sh for details"
            ;;
        esac
    done
fi

# ─────────────────────────────────────────────────────
# 2. Analyze failure telemetry patterns
# ─────────────────────────────────────────────────────
recent_failures=""
for i in $(seq 0 6); do
    date_str=$(date -v-"${i}d" "+%Y-%m-%d" 2>/dev/null || date -d "$i days ago" "+%Y-%m-%d" 2>/dev/null)
    f="$LOG_DIR/tool-failures-${date_str}.jsonl"
    [ -f "$f" ] && recent_failures="$recent_failures $f"
done

if [ -n "$recent_failures" ]; then
    # shellcheck disable=SC2086
    total_failures=$(cat $recent_failures 2>/dev/null | wc -l | tr -d ' ')

    if [ "$total_failures" -gt 50 ]; then
        add_suggestion "HIGH" "reliability" \
            "$total_failures tool failures in last 7 days — investigate recurring patterns" \
            "Run: scripts/harness/query-telemetry.sh top-failures --days 7"
    fi

    # Check for repeated tool failures
    # shellcheck disable=SC2086
    top_tool=$(cat $recent_failures 2>/dev/null | jq -r '.tool_name' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    # shellcheck disable=SC2086
    top_count=$(cat $recent_failures 2>/dev/null | jq -r '.tool_name' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')

    if [ -n "$top_tool" ] && [ "${top_count:-0}" -gt 10 ]; then
        add_suggestion "HIGH" "reliability" \
            "Tool '$top_tool' failed $top_count times in 7 days — consider adding a PreToolUse guard" \
            "Add validation hook for $top_tool in .claude/settings.json PreToolUse"
    fi
fi

# ─────────────────────────────────────────────────────
# 3. Analyze session report trends
# ─────────────────────────────────────────────────────
if [ -f "$REPORT_FILE" ]; then
    report_count=$(wc -l <"$REPORT_FILE" | tr -d ' ')

    if [ "$report_count" -lt 3 ]; then
        add_suggestion "MEDIUM" "feedback-loop" \
            "Only $report_count session reports captured — insufficient data for trend analysis" \
            "Ensure session-report.sh runs at SessionEnd"
    fi

    # Check for sessions with high failure rates
    high_failure_sessions=$(jq -r 'select(.failures > 10) | .date' "$REPORT_FILE" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${high_failure_sessions:-0}" -gt 0 ]; then
        add_suggestion "MEDIUM" "reliability" \
            "$high_failure_sessions session(s) had >10 failures — review with query-telemetry.sh" \
            "Run: scripts/harness/query-telemetry.sh summary --days 7"
    fi
fi

# ─────────────────────────────────────────────────────
# 4. Check for missing harness integration points
# ─────────────────────────────────────────────────────
settings="$ROOT/.claude/settings.json"
if [ -f "$settings" ]; then
    # Check if architecture tests run anywhere in lifecycle
    if ! grep -q "test-architecture" "$settings" 2>/dev/null; then
        add_suggestion "LOW" "constraints" \
            "Architecture tests not wired into any lifecycle hook — only run manually" \
            "Consider adding to SessionStart or pre-commit for continuous validation"
    fi

    # Check if drift detection runs anywhere
    if ! grep -q "detect-drift" "$settings" 2>/dev/null; then
        add_suggestion "LOW" "entropy" \
            "Drift detection not wired into any lifecycle hook — drift accumulates silently" \
            "Consider periodic cron or SessionStart integration"
    fi
fi

# ─────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────
if $json_output; then
    printf '['
    first=true
    for s in "${suggestions[@]}"; do
        $first || printf ','
        printf '%s' "$s"
        first=false
    done
    printf ']\n'
    exit 0
fi

echo -e "${BLUE}=== Harness Improvement Suggestions ===${NC}"
echo ""

if [ ${#suggestions[@]} -eq 0 ]; then
    echo -e "${GREEN}No improvements suggested — harness is healthy.${NC}"
    exit 0
fi

# Sort by priority
for priority in HIGH MEDIUM LOW; do
    printed_header=false
    for s in "${suggestions[@]}"; do
        p=$(echo "$s" | jq -r '.priority')
        [ "$p" = "$priority" ] || continue

        if ! $printed_header; then
            case "$priority" in
            HIGH) echo -e "${RED}--- Priority: HIGH ---${NC}" ;;
            MEDIUM) echo -e "${YELLOW}--- Priority: MEDIUM ---${NC}" ;;
            LOW) echo -e "${BLUE}--- Priority: LOW ---${NC}" ;;
            esac
            printed_header=true
        fi

        cat=$(echo "$s" | jq -r '.category')
        sug=$(echo "$s" | jq -r '.suggestion')
        act=$(echo "$s" | jq -r '.action')
        echo "  [$cat] $sug"
        echo "    Action: $act"
        echo ""
    done
done

echo -e "${BLUE}Total: ${#suggestions[@]} suggestion(s)${NC}"
