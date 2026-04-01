#!/usr/bin/env bash
# run-with-rotation.sh - Execute codex via the codex-rotate fish helper
set -euo pipefail

FISH_BIN="${FISH_BIN:-$(command -v fish 2>/dev/null || true)}"

usage() {
    echo "Usage: run-with-rotation.sh -- <codex args>" >&2
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

if [ -z "$FISH_BIN" ]; then
    echo "codex autorotate: fish shell not installed; running plain codex" >&2
    exec codex "$@"
fi

if "$FISH_BIN" -c 'functions -q codex-rotate' >/dev/null 2>&1; then
    exec "$FISH_BIN" -c 'codex-rotate $argv' -- "$@"
fi

echo "codex autorotate: codex-rotate function missing; running plain codex" >&2
exec codex "$@"
