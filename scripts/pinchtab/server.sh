#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pinchtab"
mkdir -p "$STATE_DIR"

if ! command -v pinchtab >/dev/null 2>&1; then
    printf 'pinchtab server: pinchtab is not installed\n' >&2
    exit 127
fi

exec pinchtab server
