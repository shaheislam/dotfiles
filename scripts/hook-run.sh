#!/usr/bin/env bash
# Wrap a Claude Code hook command with timeout fallback and failure logging.
#
# macOS lacks GNU `timeout` by default. Without coreutils installed (which
# provides `gtimeout`), every hook command prefixed `timeout 60 ...` failed
# silently because hooks also use `2>/dev/null || true`. This wrapper:
#   1. Picks `timeout`, then `gtimeout`, else runs the command bare.
#   2. Logs non-zero exits to ~/.claude/logs/hooks/<date>.log so future
#      regressions are visible instead of buried.
#   3. Always exits 0 so Claude Code's hook lifecycle is never blocked.
#
# Usage: hook-run.sh <secs> <command> [args...]
set -u

secs="${1:-60}"
shift || true

log_dir="${HOME}/.claude/logs/hooks"
mkdir -p "$log_dir" 2>/dev/null || true
log_file="${log_dir}/$(date +%Y-%m-%d).log"

if command -v timeout >/dev/null 2>&1; then
    runner=(timeout "$secs")
elif command -v gtimeout >/dev/null 2>&1; then
    runner=(gtimeout "$secs")
else
    runner=()
fi

output=$("${runner[@]}" "$@" 2>&1)
rc=$?

if [[ $rc -ne 0 ]]; then
    {
        printf '[%s] rc=%d cmd=' "$(date -u +%FT%TZ)" "$rc"
        printf '%q ' "$@"
        printf '\n'
        printf '%s\n---\n' "$output" | head -25
    } >> "$log_file" 2>/dev/null || true
fi

exit 0
