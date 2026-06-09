#!/usr/bin/env bash
# Claude Code SessionStart helper for opt-in DB sandboxes.

set -euo pipefail

SCRIPT="${HOME}/dotfiles/scripts/db-sandbox.sh"
[ -x "$SCRIPT" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
MARKER="${PROJECT_DIR}/.db-sandbox.toml"
ENGINES="${DB_SANDBOX:-}"

if [ -z "$ENGINES" ] && [ -f "$MARKER" ]; then
    ENGINES=$(awk -F= '/^[[:space:]]*engines[[:space:]]*=/ { gsub(/[\"\[\] ]/, "", $2); print $2; exit }' "$MARKER")
fi

if [ -n "$ENGINES" ]; then
    DB_SANDBOX_CWD="$PROJECT_DIR" "$SCRIPT" up "$ENGINES" >/dev/null 2>&1 || true
fi

DB_SANDBOX_CWD="$PROJECT_DIR" "$SCRIPT" env 2>/dev/null || true
