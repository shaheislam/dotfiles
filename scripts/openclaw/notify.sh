#!/usr/bin/env bash
# OpenClaw notification helper for bash scripts
# Source this file to get oc_notify and oc_notify_ticket functions.
#
# Usage:
#   source scripts/openclaw/notify.sh
#   oc_notify "Build complete"
#   oc_notify "Deploy failed" "slack" "high"
#   oc_notify_ticket "ENG-123" "completed" "PR #456 merged"
#
# Environment:
#   OPENCLAW_NOTIFY_CHANNEL  Default channel (default: "default")
#   OPENCLAW_NOTIFY_STRICT   Set to "1" to fail on notification errors
#   OPENCLAW_NOTIFY_LOG      Log file path (default: ~/.openclaw/notify.log)
#
# Note: This bash helper exists for non-Fish contexts (worktree-witness.sh,
# merge-queue.sh, cross-provider-bridge.sh). Fish-native callers should use
# openclaw-notify.fish directly.

_oc_log() {
    local log_file="${OPENCLAW_NOTIFY_LOG:-$HOME/.openclaw/notify.log}"
    local log_dir
    log_dir="$(dirname "$log_file")"
    if [[ -d "$log_dir" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$log_file" 2>/dev/null
    fi
}

oc_notify() {
    local message="$1"
    local channel="${2:-${OPENCLAW_NOTIFY_CHANNEL:-default}}"
    local urgency="${3:-normal}"
    local strict="${OPENCLAW_NOTIFY_STRICT:-0}"

    # Skip if openclaw not installed
    if ! command -v openclaw &>/dev/null; then
        _oc_log "SKIP openclaw not installed: $message"
        return 0
    fi

    # Skip if gateway not running (fast check)
    if ! openclaw gateway status &>/dev/null; then
        _oc_log "SKIP gateway not running: $message"
        return 0
    fi

    # Format urgency prefix
    case "$urgency" in
        high) message="[URGENT] $message" ;;
        low)  message="[info] $message" ;;
    esac

    if openclaw message send --channel "$channel" --message "$message" 2>/dev/null; then
        _oc_log "OK [$channel] $message"
    else
        _oc_log "FAIL [$channel] $message"
        if [[ "$strict" == "1" ]]; then
            return 1
        fi
    fi
}

oc_notify_ticket() {
    local ticket_key="$1"
    local status="$2"
    local details="${3:-}"

    oc_notify "Ticket $ticket_key: $status${details:+ - $details}"
}
