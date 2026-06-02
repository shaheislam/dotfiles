#!/usr/bin/env bash
set -euo pipefail

if [ "${OPENCODE_JFDI_AUTO_SYNC:-1}" = "0" ]; then
    exit 0
fi

JFDI_DIR="${OPENCODE_JFDI_PROJECT_DIR:-/mounts/second-brain/jfdi}"
# Memory extraction is intentionally deferred to the daily Obsidian distillation
# job to avoid spawning expensive AI work from every OpenCode shutdown.
EXTRACT_ENABLED="${OPENCODE_JFDI_AUTO_EXTRACT:-0}"
EXTRACT_LIMIT="${OPENCODE_JFDI_EXTRACT_LIMIT:-3}"
SYNTHESIS_ENABLED="${OPENCODE_JFDI_AUTO_SYNTHESIS:-1}"
STATE_DIR="${OPENCODE_JFDI_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/opencode}"
SYNTHESIS_STAMP="$STATE_DIR/jfdi-last-synthesis-week.txt"

if [ ! -d "$JFDI_DIR" ]; then
    exit 0
fi

if ! command -v bunx >/dev/null 2>&1; then
    exit 0
fi

cd "$JFDI_DIR"

run_if_present() {
    local script="$1"
    shift

    if [ ! -f "$script" ]; then
        return 0
    fi

    bunx tsx "$script" "$@"
}

run_if_present scripts/sync-sessions.ts
run_if_present scripts/sync-obsidian.ts

if [ "$EXTRACT_ENABLED" = "1" ]; then
    run_if_present scripts/extract-memories.ts --limit "$EXTRACT_LIMIT"
    run_if_present scripts/sync-obsidian.ts
fi

if [ "$SYNTHESIS_ENABLED" = "1" ]; then
    current_week="$(date +%G-W%V)"
    last_week=""
    if [ -f "$SYNTHESIS_STAMP" ]; then
        last_week="$(cat "$SYNTHESIS_STAMP" 2>/dev/null || true)"
    fi

    if [ "$current_week" != "$last_week" ]; then
        mkdir -p "$STATE_DIR"
        if run_if_present scripts/weekly-synthesis.ts --week "$current_week"; then
            printf '%s\n' "$current_week" >"$SYNTHESIS_STAMP"
        fi
    fi
fi
