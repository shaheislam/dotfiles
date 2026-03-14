#!/usr/bin/env bash
# aimux shared utilities

# Colors (Tokyo Night palette)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Agent state colors (Tokyo Night hex for tmux)
COLOR_WORKING="#f7768e"
COLOR_WAITING="#e0af68"
COLOR_DONE="#9ece6a"
COLOR_STUCK="#bb9af7"

# Config
AIMUX_HOME="${AIMUX_HOME:-$HOME/.aimux}"
AIMUX_STATE_DIR="$AIMUX_HOME/workspaces"
AIMUX_LOG="$AIMUX_HOME/aimux.log"

ensure_home() {
    mkdir -p "$AIMUX_HOME" "$AIMUX_STATE_DIR" 2>/dev/null || true
}

info() { printf "${BLUE}info${RESET}: %s\n" "$*"; }
warn() { printf "${YELLOW}warn${RESET}: %s\n" "$*" >&2; }
error() { printf "${RED}error${RESET}: %s\n" "$*" >&2; }
die() {
    error "$@"
    exit 1
}

has() { command -v "$1" &>/dev/null; }

require() {
    has "$1" || die "Required command not found: $1"
}

git_root() {
    git rev-parse --show-toplevel 2>/dev/null || echo ""
}

git_common_dir() {
    git rev-parse --git-common-dir 2>/dev/null || echo ""
}

git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

in_tmux() {
    [[ -n "${TMUX:-}" ]]
}

tmux_session() {
    tmux display-message -p '#S' 2>/dev/null || echo ""
}

tmux_window() {
    tmux display-message -p '#I' 2>/dev/null || echo ""
}

sanitize_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

log() {
    ensure_home
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$AIMUX_LOG"
}
