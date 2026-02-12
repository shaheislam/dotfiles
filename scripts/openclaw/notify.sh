#!/usr/bin/env bash
# OpenClaw notification helper for bash scripts
# Source this file to get oc_notify and oc_notify_ticket functions.
#
# Usage:
#   source scripts/openclaw/notify.sh
#   oc_notify "Build complete"
#   oc_notify "Deploy failed" "slack" "high"
#   oc_notify_ticket "ENG-123" "completed" "PR #456 merged"

oc_notify() {
    local message="$1"
    local channel="${2:-${OPENCLAW_NOTIFY_CHANNEL:-default}}"
    local urgency="${3:-normal}"

    # Skip if openclaw not installed
    if ! command -v openclaw &>/dev/null; then
        return 0
    fi

    # Skip if gateway not running (fast check)
    if ! openclaw gateway status &>/dev/null; then
        return 0
    fi

    # Format urgency prefix
    case "$urgency" in
        high) message="[URGENT] $message" ;;
        low)  message="[info] $message" ;;
    esac

    openclaw message send --channel "$channel" --message "$message" 2>/dev/null || true
}

oc_notify_ticket() {
    local ticket_key="$1"
    local status="$2"
    local details="${3:-}"

    oc_notify "Ticket $ticket_key: $status${details:+ - $details}"
}
