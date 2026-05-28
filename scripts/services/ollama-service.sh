#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ollama"
mkdir -p "$STATE_DIR"

if ! command -v ollama >/dev/null 2>&1; then
    printf 'ollama service: ollama is not installed\n' >&2
    exit 127
fi

export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:11434}"
exec ollama serve
