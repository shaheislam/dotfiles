#!/usr/bin/env bash
set -euo pipefail

PORT="${OPENCODE_PORT:-4096}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
PASSWORD_FILE="$STATE_DIR/server.password"

mkdir -p "$STATE_DIR"

if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
    if [ ! -s "$PASSWORD_FILE" ]; then
        umask 077
        if command -v openssl >/dev/null 2>&1; then
            openssl rand -base64 32 >"$PASSWORD_FILE"
        else
            uuidgen >"$PASSWORD_FILE"
        fi
    fi
    OPENCODE_SERVER_PASSWORD="$(tr -d '\n' <"$PASSWORD_FILE")"
    export OPENCODE_SERVER_PASSWORD
fi

# Remove stale lock dirs whose recorded PID is no longer alive.
LOCKS_DIR="$STATE_DIR/locks"
if [ -d "$LOCKS_DIR" ]; then
    for lock_dir in "$LOCKS_DIR"/*.lock; do
        [ -d "$lock_dir" ] || continue
        meta="$lock_dir/meta.json"
        [ -f "$meta" ] || continue
        lock_pid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('pid',''))" "$meta" 2>/dev/null || true)
        if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -rf "$lock_dir"
        fi
    done
fi

# OpenTUI graphics probing is noisy under launchd and unnecessary for the server.
export OPENTUI_GRAPHICS="${OPENTUI_GRAPHICS:-0}"
export OPENCODE_DISABLE_LSP_DOWNLOAD="${OPENCODE_DISABLE_LSP_DOWNLOAD:-true}"
export OPENCODE_SERVER_USERNAME="${OPENCODE_SERVER_USERNAME:-opencode}"

exec "$HOME/dotfiles/scripts/bin/opencode" serve --port "$PORT"
