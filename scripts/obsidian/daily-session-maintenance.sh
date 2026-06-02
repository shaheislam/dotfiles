#!/usr/bin/env bash
# Reconcile closed Claude sessions and distill memories in one scheduled batch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$HOME/obsidian}"
DISTILL_LIMIT="${CLAUDE_DAILY_DISTILL_LIMIT:-10}"
LOG_DIR="$HOME/.claude/hooks/logs"
LOCK_DIR="${TMPDIR:-/tmp}/claude-daily-session-maintenance"
LOCK_FILE="$LOCK_DIR/lock"
LOCK_TTL_SECONDS="${CLAUDE_DAILY_SESSION_MAINTENANCE_LOCK_TTL:-21600}"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"
}

acquire_lock() {
    mkdir -p "$LOCK_DIR"
    if mkdir "$LOCK_FILE" 2>/dev/null; then
        printf '%s\n' "$$" >"$LOCK_FILE/pid"
        return 0
    fi

    local lock_age
    lock_age=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [[ "$lock_age" -gt "$LOCK_TTL_SECONDS" ]]; then
        rm -rf "$LOCK_FILE"
        mkdir "$LOCK_FILE"
        printf '%s\n' "$$" >"$LOCK_FILE/pid"
        return 0
    fi

    return 1
}

release_lock() {
    rm -rf "$LOCK_FILE"
}

main() {
    mkdir -p "$LOG_DIR"

    if [[ ! -d "$OBSIDIAN_VAULT" ]]; then
        log "Obsidian vault not found: $OBSIDIAN_VAULT"
        exit 0
    fi

    if ! acquire_lock; then
        log "Daily session maintenance already running; skipping"
        exit 0
    fi
    trap release_lock EXIT

    log "Reconciling recent Claude session notes"
    bash "$SCRIPT_DIR/session-synthesize.sh" --reconcile

    log "Distilling unprocessed session memories (limit=$DISTILL_LIMIT)"
    bash "$SCRIPT_DIR/session-distill-batch.sh" --limit "$DISTILL_LIMIT" --priority

    log "Daily session maintenance complete"
}

main "$@"
