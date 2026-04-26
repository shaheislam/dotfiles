#!/usr/bin/env bash
set -euo pipefail

FIFO_PATH="$(mktemp -u)"
OPENED_MARKER="$(mktemp)"

cleanup() {
    rm -f "$FIFO_PATH" "$OPENED_MARKER"
}
trap cleanup EXIT

mkfifo "$FIFO_PATH"

stream_and_open() {
    local line
    local url

    while IFS= read -r line; do
        printf '%s\n' "$line"

        if [[ -s "$OPENED_MARKER" ]]; then
            continue
        fi

        url="$(printf '%s\n' "$line" | grep -Eo 'https://auth\.openai\.com[^[:space:]]+' | head -n 1 || true)"
        if [[ -n "$url" ]]; then
            /usr/bin/open "$url" >/dev/null 2>&1 || true
            printf 'opened\n' >"$OPENED_MARKER"
        fi
    done <"$FIFO_PATH"
}

stream_and_open &
reader_pid=$!

set +e
env BROWSER="$HOME/dotfiles/scripts/bin/open-url" PATH="$HOME/dotfiles/scripts/bin:$PATH" \
    opencode auth login --provider openai --method "ChatGPT Pro/Plus (browser)" >"$FIFO_PATH" 2>&1
cmd_status=$?
set -e

wait "$reader_pid"
exit "$cmd_status"
