#!/usr/bin/env bash
set -euo pipefail

# Probe the OpenAI API to detect whether the current account is rate-limited.
# Reads the OAuth access token from OpenCode's auth.json and makes a minimal
# chat completion request (gpt-4o-mini, max_tokens=1).
#
# Exit codes:
#   0 = available (API responded normally)
#   1 = rate-limited (usage limit reached)
#   2 = auth invalid or expired
#   3 = no auth file or no OpenAI entry
#
# Usage:
#   usage-check.sh              # human-readable output
#   usage-check.sh --quiet      # exit code only
#   usage-check.sh --json       # raw API response
#   usage-check.sh --token TOKEN # use a specific token instead of auth.json

AUTH_FILE="${OPENCODE_AUTH_FILE:-$HOME/.local/share/opencode/auth.json}"
QUIET=false
JSON_MODE=false
TOKEN_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --quiet | -q)
        QUIET=true
        shift
        ;;
    --json | -j)
        JSON_MODE=true
        shift
        ;;
    --token)
        TOKEN_OVERRIDE="$2"
        shift 2
        ;;
    --auth-file)
        AUTH_FILE="$2"
        shift 2
        ;;
    *)
        shift
        ;;
    esac
done

log() {
    if ! $QUIET; then
        echo "$@"
    fi
}

log_err() {
    if ! $QUIET; then
        echo "$@" >&2
    fi
}

# Resolve token
if [[ -n "$TOKEN_OVERRIDE" ]]; then
    access_token="$TOKEN_OVERRIDE"
elif [[ -f "$AUTH_FILE" ]]; then
    access_token="$(jq -r '.openai.access // empty' "$AUTH_FILE" 2>/dev/null || true)"
    if [[ -z "$access_token" ]]; then
        log_err "No OpenAI entry in $AUTH_FILE"
        exit 3
    fi
else
    log_err "Auth file not found: $AUTH_FILE"
    exit 3
fi

# Check token expiry from auth.json (if not using override)
if [[ -z "$TOKEN_OVERRIDE" ]] && [[ -f "$AUTH_FILE" ]]; then
    expires="$(jq -r '.openai.expires // 0' "$AUTH_FILE" 2>/dev/null || echo 0)"
    now_ms="$(date +%s)000"
    if [[ "$expires" -gt 0 ]] && [[ "$now_ms" -gt "$expires" ]]; then
        log_err "OpenAI token expired (expired at $(date -r "$((expires / 1000))" 2>/dev/null || echo "$expires"))"
        exit 2
    fi
fi

# Minimal probe: gpt-4o-mini, max_tokens=1
# This costs virtually nothing and tests whether the account can make requests.
response="$(curl -s -w "\n%{http_code}" \
    -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"hi"}],"max_tokens":1}' \
    --max-time 10 2>/dev/null || echo -e "\n000")"

http_code="$(echo "$response" | tail -1)"
body="$(echo "$response" | sed '$d')"

if $JSON_MODE; then
    echo "$body"
fi

case "$http_code" in
200)
    log "OpenAI API: available"
    exit 0
    ;;
429)
    # Could be rate limit or usage limit
    if echo "$body" | grep -qi "usage.limit\|rate_limit_exceeded\|limit.*reached\|exceeded.*quota"; then
        log "OpenAI API: usage limit reached"
        exit 1
    fi
    log "OpenAI API: rate limited (transient)"
    exit 1
    ;;
401 | 403)
    log_err "OpenAI API: auth invalid (HTTP $http_code)"
    exit 2
    ;;
000)
    log_err "OpenAI API: connection failed (timeout or network error)"
    exit 2
    ;;
*)
    # Check body for usage limit indicators even on other status codes
    if echo "$body" | grep -qi "usage.limit\|limit.*reached\|exceeded.*quota"; then
        log "OpenAI API: usage limit reached (HTTP $http_code)"
        exit 1
    fi
    log_err "OpenAI API: unexpected response (HTTP $http_code)"
    if ! $QUIET && ! $JSON_MODE; then
        echo "$body" | head -5 >&2
    fi
    exit 2
    ;;
esac
