#!/usr/bin/env bash
# OpenClaw sandbox profile switcher for devcontainer sessions.
# Called by gwt-ticket/gwt-claude to relax sandbox when inside a devcontainer,
# and restore defaults on exit.
#
# Uses refcounting so multiple concurrent sessions don't clobber each other:
#   - First 'devcontainer' saves original values, applies relaxed profile
#   - Subsequent 'devcontainer' calls just increment refcount
#   - 'default' decrements refcount; only restores originals when it hits 0
#
# Concurrency: mkdir-based lock serializes all refcount + config mutations.
# Atomic writes: mktemp + fsync + same-FS mv for config replacement.
# Underflow protection: refcount saturates at 0, never goes negative.
#
# Usage:
#   sandbox-profile.sh devcontainer   # Relax sandbox for coding
#   sandbox-profile.sh default        # Restore saved defaults (refcount-aware)
#   sandbox-profile.sh show           # Show current profile + refcount

set -euo pipefail

CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
CONFIG_DIR="$(dirname "$CONFIG")"
REFCOUNT_FILE="${CONFIG_DIR}/.sandbox-refcount"
PREV_FILE="${CONFIG_DIR}/.sandbox-prev.json"
LOG_FILE="${CONFIG_DIR}/notify.log"
LOCK_DIR="${CONFIG_DIR}/.sandbox-lock"

_log() {
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    if [[ -d "$log_dir" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] sandbox-profile: $*" >> "$LOG_FILE" 2>/dev/null
    fi
}

# mkdir-based lock: atomic on all filesystems, no external tools needed
_lock() {
    local attempts=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        attempts=$((attempts + 1))
        if [[ "$attempts" -ge 30 ]]; then
            # Stale lock detection: if lock dir is >60s old, force-remove
            if [[ -d "$LOCK_DIR" ]]; then
                local lock_age
                lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR" 2>/dev/null || stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
                if [[ "$lock_age" -gt 60 ]]; then
                    _log "WARN removing stale lock (age=${lock_age}s)"
                    rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR"
                    continue
                fi
            fi
            _log "FAIL could not acquire lock after 30 attempts"
            echo "Error: could not acquire sandbox lock" >&2
            return 1
        fi
        sleep 0.1
    done
}

_unlock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

# Atomic config write: mktemp + fsync + same-filesystem mv
_atomic_write_config() {
    local tmp
    tmp=$(mktemp "${CONFIG_DIR}/.openclaw-config.XXXXXX") || {
        _log "FAIL mktemp failed"
        return 1
    }
    cat > "$tmp"
    chmod 600 "$tmp"
    # fsync the temp file and parent dir for durability
    python3 -c "
import os
fd = os.open('$tmp', os.O_RDONLY)
os.fsync(fd)
os.close(fd)
dd = os.open('$CONFIG_DIR', os.O_RDONLY)
os.fsync(dd)
os.close(dd)
" 2>/dev/null || true  # best-effort fsync; mv is still atomic without it
    mv "$tmp" "$CONFIG"
}

# Read refcount safely, saturates at 0 on missing/corrupt
_read_refcount() {
    local val=0
    if [[ -f "$REFCOUNT_FILE" ]]; then
        val=$(cat "$REFCOUNT_FILE" 2>/dev/null) || val=0
        if ! [[ "$val" =~ ^[0-9]+$ ]]; then
            _log "WARN corrupt refcount file (value='$val'), saturating at 0"
            val=0
        fi
    fi
    echo "$val"
}

if [[ ! -f "$CONFIG" ]]; then
    # Config doesn't exist yet — nothing to do
    exit 0
fi

if ! command -v jq &>/dev/null; then
    _log "FAIL jq not installed"
    echo "jq required for sandbox profile switching" >&2
    exit 1
fi

profile="${1:-show}"

case "$profile" in
    devcontainer)
        _lock
        trap '_unlock' EXIT

        count=$(_read_refcount)

        # Save original values before first relax (refcount 0→1)
        if [[ "$count" -eq 0 ]]; then
            jq '{workspaceAccess: .agents.defaults.sandbox.workspaceAccess,
                 network: .agents.defaults.sandbox.docker.network}' "$CONFIG" > "$PREV_FILE" 2>/dev/null || {
                _log "FAIL could not save original sandbox values"
                echo "Warning: could not save original sandbox values" >&2
            }
        fi

        # Increment refcount
        echo $((count + 1)) > "$REFCOUNT_FILE"

        # Relax sandbox for devcontainer coding sessions:
        # - workspaceAccess: rw (agent needs to edit code)
        # - docker.network: bridge (agent needs package installs)
        jq '.agents.defaults.sandbox.workspaceAccess = "rw" |
            .agents.defaults.sandbox.docker.network = "bridge"' \
            "$CONFIG" | _atomic_write_config
        _log "OK devcontainer profile applied (refcount=$((count + 1)))"
        echo "Sandbox profile: devcontainer (workspace=rw, network=bridge, refcount=$((count + 1)))"
        ;;
    default)
        _lock
        trap '_unlock' EXIT

        count=$(_read_refcount)

        # No-op if nothing was relaxed (refcount=0 and no saved state)
        if [[ "$count" -eq 0 ]]; then
            if [[ ! -f "$PREV_FILE" ]]; then
                _log "OK default called with no active relaxation — no-op"
                echo "Sandbox profile: already at defaults (no active relaxation)"
                exit 0
            fi
            # PREV_FILE exists but refcount=0: corrupted state.
            # Log loudly but still restore from saved values to be safe.
            _log "WARN refcount=0 but saved state exists — restoring anyway (possible corruption)"
        fi

        if [[ "$count" -le 1 ]]; then
            # Last session (or saturated-to-0) — restore from saved values
            orig_workspace="none"
            orig_network="none"
            if [[ -f "$PREV_FILE" ]]; then
                orig_workspace=$(jq -r '.workspaceAccess // "none"' "$PREV_FILE" 2>/dev/null) || orig_workspace="none"
                orig_network=$(jq -r '.network // "none"' "$PREV_FILE" 2>/dev/null) || orig_network="none"
            fi

            jq --arg ws "$orig_workspace" --arg net "$orig_network" \
                '.agents.defaults.sandbox.workspaceAccess = $ws |
                 .agents.defaults.sandbox.docker.network = $net' \
                "$CONFIG" | _atomic_write_config

            # Clean up sidecar files
            rm -f "$REFCOUNT_FILE" "$PREV_FILE"
            _log "OK default profile restored (workspace=$orig_workspace, network=$orig_network)"
            echo "Sandbox profile: default (workspace=$orig_workspace, network=$orig_network)"
        else
            # Other sessions still active — just decrement (saturate at 0)
            new_count=$((count - 1))
            if [[ "$new_count" -lt 0 ]]; then
                new_count=0
            fi
            echo "$new_count" > "$REFCOUNT_FILE"
            _log "OK refcount decremented ($count -> $new_count)"
            echo "Sandbox profile: still relaxed (refcount=$new_count)"
        fi
        ;;
    show)
        workspace=$(jq -r '.agents.defaults.sandbox.workspaceAccess // "unknown"' "$CONFIG")
        network=$(jq -r '.agents.defaults.sandbox.docker.network // "unknown"' "$CONFIG")
        count=$(_read_refcount)
        echo "Sandbox: workspace=$workspace, network=$network, refcount=$count"
        ;;
    *)
        echo "Usage: sandbox-profile.sh {devcontainer|default|show}" >&2
        exit 1
        ;;
esac
