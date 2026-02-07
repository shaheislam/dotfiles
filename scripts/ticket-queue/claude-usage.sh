#!/usr/bin/env bash
#
# claude-usage.sh - Check Claude Code usage via OAuth API
#
# Queries the undocumented OAuth usage endpoint to get current utilization
# and reset times for 5-hour and 7-day windows.
#
# Usage:
#   claude-usage.sh                  # Human-readable output
#   claude-usage.sh --json           # JSON output for scripting
#   claude-usage.sh --available      # Exit 0 if capacity available, 1 if not
#   claude-usage.sh --wait           # Block until capacity is available
#   claude-usage.sh --threshold 80   # Custom threshold (default: 90%)
#
# Exit codes:
#   0 = Success (or capacity available in --available mode)
#   1 = Rate limited / no capacity (in --available mode)
#   2 = Cannot get credentials
#   3 = API error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
OUTPUT_MODE="human"
THRESHOLD=90
WAIT_MODE=false
POLL_INTERVAL=300  # 5 minutes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    cat << 'EOF'
claude-usage.sh - Check Claude Code usage limits

USAGE:
  claude-usage.sh                  # Human-readable output
  claude-usage.sh --json           # JSON output for scripting
  claude-usage.sh --available      # Exit 0 if capacity available, 1 if not
  claude-usage.sh --wait           # Block until capacity is available
  claude-usage.sh --threshold 80   # Custom utilization threshold (default: 90%)
  claude-usage.sh --poll N         # Poll interval in seconds (default: 300)

OPTIONS:
  --json         Output raw JSON from API
  --available    Check if utilization is below threshold
  --wait         Block until utilization drops below threshold
  --threshold N  Utilization percentage threshold (default: 90)
  --poll N       Poll interval in seconds for --wait mode (default: 300)
  --help         Show this help

EXIT CODES:
  0 = Success / capacity available
  1 = Rate limited / no capacity
  2 = Cannot get credentials
  3 = API error

NOTES:
  Uses the undocumented OAuth usage API endpoint.
  Requires Claude Code OAuth credentials in macOS Keychain.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) OUTPUT_MODE="json"; shift ;;
        --available) OUTPUT_MODE="available"; shift ;;
        --wait) WAIT_MODE=true; OUTPUT_MODE="available"; shift ;;
        --threshold)
            THRESHOLD="${2:?Error: --threshold requires a number}"
            shift 2
            ;;
        --poll)
            POLL_INTERVAL="${2:?Error: --poll requires seconds}"
            shift 2
            ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Get OAuth token from macOS Keychain
get_oauth_token() {
    local keychain_data
    keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || {
        echo "Error: Cannot read Claude Code credentials from Keychain" >&2
        echo "Make sure you're logged in to Claude Code (run 'claude' and authenticate)" >&2
        return 2
    }

    # Extract access token - try python3 first, fall back to jq
    local token
    if command -v python3 &>/dev/null; then
        token=$(echo "$keychain_data" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    token = data.get('claudeAiOauth', {}).get('accessToken', '')
    if token:
        print(token)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null) || {
            echo "Error: Cannot extract OAuth token from Keychain data" >&2
            return 2
        }
    elif command -v jq &>/dev/null; then
        token=$(echo "$keychain_data" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || {
            echo "Error: Cannot extract OAuth token" >&2
            return 2
        }
    else
        echo "Error: Need python3 or jq to parse credentials" >&2
        return 2
    fi

    if [[ -z "$token" ]]; then
        echo "Error: OAuth token is empty (may need to re-authenticate)" >&2
        return 2
    fi

    echo "$token"
}

# Query the usage API
query_usage() {
    local token="$1"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Accept: application/json" 2>/dev/null)

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        # Token might be expired - try refreshing
        if [[ "$http_code" == "401" ]]; then
            echo "Error: OAuth token expired (HTTP 401). Re-authenticate Claude Code." >&2
        else
            echo "Error: API returned HTTP $http_code" >&2
            echo "$body" >&2
        fi
        return 3
    fi

    echo "$body"
}

# Parse utilization from JSON response
# Returns: five_hour_pct seven_day_pct opus_pct five_hour_reset seven_day_reset opus_reset
parse_usage() {
    local json="$1"

    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
data = json.loads(sys.stdin.read())

five_hour = data.get('five_hour') or {}
seven_day = data.get('seven_day') or {}
opus = data.get('seven_day_opus') or {}

print(f\"{five_hour.get('utilization', 0)}\")
print(f\"{seven_day.get('utilization', 0)}\")
print(f\"{opus.get('utilization', 0)}\")
print(f\"{five_hour.get('resets_at', 'null')}\")
print(f\"{seven_day.get('resets_at', 'null')}\")
print(f\"{opus.get('resets_at', 'null')}\")
" <<< "$json"
    elif command -v jq &>/dev/null; then
        echo "$json" | jq -r '
            (.five_hour.utilization // 0),
            (.seven_day.utilization // 0),
            (.seven_day_opus.utilization // 0),
            (.five_hour.resets_at // "null"),
            (.seven_day.resets_at // "null"),
            (.seven_day_opus.resets_at // "null")
        '
    fi
}

# Format reset time for display
format_reset_time() {
    local reset_at="$1"
    if [[ "$reset_at" == "null" || -z "$reset_at" ]]; then
        echo "N/A"
        return
    fi

    # Calculate time until reset
    local reset_epoch
    if [[ "$(uname)" == "Darwin" ]]; then
        reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$reset_at" | cut -d. -f1 | sed 's/+.*//')" "+%s" 2>/dev/null || echo 0)
    else
        reset_epoch=$(date -d "$reset_at" "+%s" 2>/dev/null || echo 0)
    fi

    local now_epoch
    now_epoch=$(date "+%s")
    local diff=$((reset_epoch - now_epoch))

    if [[ $diff -le 0 ]]; then
        echo "Now"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60))m"
    elif [[ $diff -lt 86400 ]]; then
        echo "$((diff / 3600))h $((diff % 3600 / 60))m"
    else
        echo "$((diff / 86400))d $((diff % 86400 / 3600))h"
    fi
}

# Check if capacity is available (all windows below threshold)
check_available() {
    local five_hour_pct="$1"
    local seven_day_pct="$2"

    # Use bc for float comparison, fall back to python3
    local five_over seven_over
    if command -v bc &>/dev/null; then
        five_over=$(echo "$five_hour_pct >= $THRESHOLD" | bc -l 2>/dev/null || echo 0)
        seven_over=$(echo "$seven_day_pct >= $THRESHOLD" | bc -l 2>/dev/null || echo 0)
    else
        python3 -c "print(1 if $five_hour_pct >= $THRESHOLD else 0)" 2>/dev/null && \
        five_over=$(python3 -c "print(1 if $five_hour_pct >= $THRESHOLD else 0)")
        seven_over=$(python3 -c "print(1 if $seven_day_pct >= $THRESHOLD else 0)")
    fi

    if [[ "$five_over" == "1" || "$seven_over" == "1" ]]; then
        return 1
    fi
    return 0
}

# Main execution
main() {
    local token
    token=$(get_oauth_token) || exit $?

    if $WAIT_MODE; then
        echo -e "${BLUE}Waiting for Claude usage to drop below ${THRESHOLD}%...${NC}" >&2
        echo -e "Polling every ${POLL_INTERVAL}s${NC}" >&2
        echo "" >&2

        while true; do
            local usage_json
            usage_json=$(query_usage "$token") || {
                echo -e "${YELLOW}API error, retrying in ${POLL_INTERVAL}s...${NC}" >&2
                sleep "$POLL_INTERVAL"
                # Re-fetch token in case it was refreshed
                token=$(get_oauth_token 2>/dev/null) || true
                continue
            }

            local parsed
            parsed=$(parse_usage "$usage_json")
            local five_hour_pct seven_day_pct
            five_hour_pct=$(echo "$parsed" | sed -n '1p')
            seven_day_pct=$(echo "$parsed" | sed -n '2p')
            local five_hour_reset seven_day_reset
            five_hour_reset=$(echo "$parsed" | sed -n '4p')
            seven_day_reset=$(echo "$parsed" | sed -n '5p')

            if check_available "$five_hour_pct" "$seven_day_pct"; then
                echo -e "${GREEN}Capacity available! (5h: ${five_hour_pct}%, 7d: ${seven_day_pct}%)${NC}" >&2
                echo "$usage_json"
                exit 0
            fi

            local reset_display=""
            if command -v bc &>/dev/null && [[ $(echo "$five_hour_pct >= $THRESHOLD" | bc -l) == "1" ]]; then
                reset_display="5h resets in $(format_reset_time "$five_hour_reset")"
            fi
            if command -v bc &>/dev/null && [[ $(echo "$seven_day_pct >= $THRESHOLD" | bc -l) == "1" ]]; then
                [[ -n "$reset_display" ]] && reset_display="$reset_display, "
                reset_display="${reset_display}7d resets in $(format_reset_time "$seven_day_reset")"
            fi

            echo -e "${YELLOW}[$(date '+%H:%M')] Still limited (5h: ${five_hour_pct}%, 7d: ${seven_day_pct}%) - ${reset_display}${NC}" >&2
            sleep "$POLL_INTERVAL"

            # Re-fetch token periodically (it may get refreshed by other Claude instances)
            token=$(get_oauth_token 2>/dev/null) || {
                echo -e "${RED}Lost credentials, waiting...${NC}" >&2
                sleep "$POLL_INTERVAL"
                continue
            }
        done
    fi

    local usage_json
    usage_json=$(query_usage "$token") || exit $?

    case "$OUTPUT_MODE" in
        json)
            echo "$usage_json"
            ;;
        available)
            local parsed
            parsed=$(parse_usage "$usage_json")
            local five_hour_pct seven_day_pct
            five_hour_pct=$(echo "$parsed" | sed -n '1p')
            seven_day_pct=$(echo "$parsed" | sed -n '2p')

            if check_available "$five_hour_pct" "$seven_day_pct"; then
                exit 0
            else
                exit 1
            fi
            ;;
        human)
            local parsed
            parsed=$(parse_usage "$usage_json")
            local five_hour_pct seven_day_pct opus_pct
            five_hour_pct=$(echo "$parsed" | sed -n '1p')
            seven_day_pct=$(echo "$parsed" | sed -n '2p')
            opus_pct=$(echo "$parsed" | sed -n '3p')
            local five_hour_reset seven_day_reset opus_reset
            five_hour_reset=$(echo "$parsed" | sed -n '4p')
            seven_day_reset=$(echo "$parsed" | sed -n '5p')
            opus_reset=$(echo "$parsed" | sed -n '6p')

            echo -e "${BLUE}=== Claude Code Usage ===${NC}"
            echo ""

            # 5-hour window
            local five_color="$GREEN"
            if command -v bc &>/dev/null; then
                [[ $(echo "$five_hour_pct >= 75" | bc -l) == "1" ]] && five_color="$YELLOW"
                [[ $(echo "$five_hour_pct >= 90" | bc -l) == "1" ]] && five_color="$RED"
            fi
            echo -e "5-Hour Window:  ${five_color}${five_hour_pct}%${NC}  (resets in $(format_reset_time "$five_hour_reset"))"

            # 7-day window
            local seven_color="$GREEN"
            if command -v bc &>/dev/null; then
                [[ $(echo "$seven_day_pct >= 75" | bc -l) == "1" ]] && seven_color="$YELLOW"
                [[ $(echo "$seven_day_pct >= 90" | bc -l) == "1" ]] && seven_color="$RED"
            fi
            echo -e "7-Day Sonnet:   ${seven_color}${seven_day_pct}%${NC}  (resets in $(format_reset_time "$seven_day_reset"))"

            # Opus (if available)
            if [[ "$opus_reset" != "null" ]] || command -v bc &>/dev/null && [[ $(echo "$opus_pct > 0" | bc -l 2>/dev/null) == "1" ]]; then
                local opus_color="$GREEN"
                if command -v bc &>/dev/null; then
                    [[ $(echo "$opus_pct >= 75" | bc -l) == "1" ]] && opus_color="$YELLOW"
                    [[ $(echo "$opus_pct >= 90" | bc -l) == "1" ]] && opus_color="$RED"
                fi
                echo -e "7-Day Opus:     ${opus_color}${opus_pct}%${NC}  (resets in $(format_reset_time "$opus_reset"))"
            fi

            echo ""

            # Overall status
            if check_available "$five_hour_pct" "$seven_day_pct"; then
                echo -e "${GREEN}Status: Capacity available${NC}"
            else
                echo -e "${RED}Status: Rate limited (threshold: ${THRESHOLD}%)${NC}"
            fi
            ;;
    esac
}

main
