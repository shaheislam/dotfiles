#!/usr/bin/env bash
# Integration tests for tmux session-close behavior
# Tests that closing sessions falls back correctly instead of detaching.
#
# Usage:
#   test-session-close.sh kill-nonmain    # Killing non-main session preserves main
#   test-session-close.sh recreate-main   # session-closed hook recreates main if destroyed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Build minimal config with only session-close-relevant settings
build_test_conf() {
    local conf
    conf=$(mktemp "/tmp/tmux-test-sc-$$.XXXXXX")
    grep -E 'detach-on-destroy|session-closed' "$DOTFILES_ROOT/.tmux.conf" > "$conf"
    echo "$conf"
}

test_kill_nonmain() {
    local socket="_test_sc_nm_$$"
    local conf
    conf=$(build_test_conf)
    trap "tmux -L '$socket' kill-server 2>/dev/null || true; rm -f '$conf'" EXIT

    tmux -L "$socket" -f "$conf" new-session -d -s main
    tmux -L "$socket" new-session -d -s temp
    tmux -L "$socket" kill-session -t temp
    tmux -L "$socket" has-session -t main 2>/dev/null
}

test_recreate_main() {
    local socket="_test_sc_rm_$$"
    local conf
    conf=$(build_test_conf)
    trap "tmux -L '$socket' kill-server 2>/dev/null || true; rm -f '$conf'" EXIT

    tmux -L "$socket" -f "$conf" new-session -d -s main
    tmux -L "$socket" new-session -d -s other
    tmux -L "$socket" kill-session -t main
    # session-closed hook fires asynchronously via if-shell — wait for it
    local i
    for i in 1 2 3 4 5; do
        if tmux -L "$socket" has-session -t main 2>/dev/null; then
            return 0
        fi
        sleep 0.3
    done
    return 1
}

case "${1:-}" in
    kill-nonmain)  test_kill_nonmain ;;
    recreate-main) test_recreate_main ;;
    *)
        echo "Usage: $0 {kill-nonmain|recreate-main}"
        exit 1
        ;;
esac
