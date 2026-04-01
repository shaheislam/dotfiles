#!/usr/bin/env bash
# check-and-rotate.sh - Ensure OpenCode has an active OpenAI account token
set -euo pipefail

QUIET=0
if [ "${1:-}" = "--quiet" ]; then
    QUIET=1
    shift
fi

log() {
    if [ "$QUIET" -eq 0 ]; then
        echo "$@"
    fi
}

err() {
    echo "$@" >&2
}

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
USAGE_CHECK="${OPENCODE_USAGE_CHECK_SCRIPT:-$DOTFILES_ROOT/scripts/opencode/usage-check.sh}"

if [ ! -x "$USAGE_CHECK" ]; then
    log "opencode-check: usage-check script not found at $USAGE_CHECK (skipping)"
    exit 0
fi

if "$USAGE_CHECK" --quiet >/dev/null 2>&1; then
    exit 0
fi

status=$?

if [ "$status" -ne 1 ]; then
    err "opencode-check: usage probe failed (exit $status)"
    exit "$status"
fi

log "opencode-check: current account is rate limited; rotating..."

FISH_BIN="${FISH_BIN:-$(command -v fish || true)}"

rotate_with_fish() {
    "$FISH_BIN" -c 'if functions -q opencode-accounts
        opencode-accounts check-and-rotate
    else
        opencode auth login --provider openai
    end'
}

if [ -n "$FISH_BIN" ]; then
    if rotate_with_fish >/dev/null 2>&1; then
        if "$USAGE_CHECK" --quiet >/dev/null 2>&1; then
            log "opencode-check: rotation complete"
            exit 0
        fi
        err "opencode-check: usage still blocked after rotation"
        exit 1
    fi
    err "opencode-check: fish rotation failed; falling back to opencode auth login"
fi

if opencode auth login --provider openai >/dev/null 2>&1; then
    if "$USAGE_CHECK" --quiet >/dev/null 2>&1; then
        log "opencode-check: new login succeeded"
        exit 0
    fi
    err "opencode-check: usage still blocked after new login"
    exit 1
fi

err "opencode-check: unable to rotate account"
exit 1
