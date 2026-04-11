#!/usr/bin/env bash
# refresh-token.sh - Refresh an OpenAI OAuth token using a refresh_token
set -euo pipefail

CLIENT_ID="app_EMoamEEZ73f0CkXaXp7hrann"
TOKEN_ENDPOINT="https://auth.openai.com/oauth/token"

REFRESH_TOKEN=""
QUIET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --token)
        REFRESH_TOKEN="$2"
        shift 2
        ;;
    --quiet | -q)
        QUIET=true
        shift
        ;;
    *)
        shift
        ;;
    esac
done

if [[ -z "$REFRESH_TOKEN" ]]; then
    echo "Usage: refresh-token.sh --token <refresh_token>" >&2
    exit 1
fi

log() {
    if ! $QUIET; then
        echo "$@" >&2
    fi
}

log "Refreshing OpenAI token..."

response=$(curl -s -X POST "$TOKEN_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{
        \"grant_type\": \"refresh_token\",
        \"client_id\": \"$CLIENT_ID\",
        \"refresh_token\": \"$REFRESH_TOKEN\"
    }")

if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
    # Success: Output JSON containing access, refresh (might be new), and expiry
    access_token=$(echo "$response" | jq -r '.access_token')
    new_refresh_token=$(echo "$response" | jq -r '.refresh_token // empty')
    expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
    
    # Use the new refresh token if provided, otherwise keep the old one
    final_refresh="${new_refresh_token:-$REFRESH_TOKEN}"
    
    # Calculate absolute expiry MS
    expires_ms=$(($(date +%s) * 1000 + expires_in * 1000))
    
    jq -n \
        --arg access "$access_token" \
        --arg refresh "$final_refresh" \
        --argjson expires "$expires_ms" \
        '{access: $access, refresh: $refresh, expires: $expires, type: "oauth"}'
    
    log "Token refreshed successfully."
    exit 0
else
    error_msg=$(echo "$response" | jq -r '.error_description // .error // "Unknown error"')
    log "Failed to refresh token: $error_msg"
    if ! $QUIET; then
        echo "$response" >&2
    fi
    exit 1
fi
