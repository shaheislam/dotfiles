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

# OpenTUI graphics probing is noisy under launchd and unnecessary for the server.
export OPENTUI_GRAPHICS="${OPENTUI_GRAPHICS:-0}"
export OPENCODE_DISABLE_LSP_DOWNLOAD="${OPENCODE_DISABLE_LSP_DOWNLOAD:-true}"
export OPENCODE_SERVER_USERNAME="${OPENCODE_SERVER_USERNAME:-opencode}"

exec "$HOME/dotfiles/scripts/bin/opencode" serve --port "$PORT"
