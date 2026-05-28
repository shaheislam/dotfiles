#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/steampipe"
mkdir -p "$STATE_DIR"

if ! command -v steampipe >/dev/null 2>&1; then
    printf 'steampipe service: steampipe is not installed\n' >&2
    exit 127
fi

exec steampipe service start --foreground --database-listen local --database-port 9193
