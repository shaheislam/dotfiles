#!/usr/bin/env bash
# Integration tests for tmux session-close behavior
# Tests that closing sessions falls back correctly instead of detaching.
#
# Usage:
#   test-session-close.sh kill-nonmain      # Killing non-main session preserves main
#   test-session-close.sh recreate-main     # session-closed hook recreates main if destroyed
#   test-session-close.sh client-switches   # Client moves to main when its session is killed
#   test-session-close.sh sole-main-graceful # Killing sole main session is handled gracefully

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Track resources for cleanup
_CLEANUP_SOCKET=""
_CLEANUP_CONF=""
_CLEANUP_PID=""

cleanup() {
    [[ -n "$_CLEANUP_PID" ]] && kill "$_CLEANUP_PID" 2>/dev/null || true
    [[ -n "$_CLEANUP_SOCKET" ]] && tmux -L "$_CLEANUP_SOCKET" kill-server 2>/dev/null || true
    [[ -n "$_CLEANUP_CONF" ]] && rm -f "$_CLEANUP_CONF"
}
trap cleanup EXIT

# Build minimal config with only session-close-relevant settings
build_test_conf() {
    _CLEANUP_CONF=$(mktemp "/tmp/tmux-test-sc-$$.XXXXXX")
    grep -E 'detach-on-destroy|exit-empty|session-closed' "$DOTFILES_ROOT/.tmux.conf" > "$_CLEANUP_CONF"
}

test_kill_nonmain() {
    _CLEANUP_SOCKET="_test_sc_nm_$$"
    build_test_conf

    tmux -L "$_CLEANUP_SOCKET" -f "$_CLEANUP_CONF" new-session -d -s main
    tmux -L "$_CLEANUP_SOCKET" new-session -d -s temp
    tmux -L "$_CLEANUP_SOCKET" kill-session -t temp
    tmux -L "$_CLEANUP_SOCKET" has-session -t main 2>/dev/null
}

test_recreate_main() {
    _CLEANUP_SOCKET="_test_sc_rm_$$"
    build_test_conf

    tmux -L "$_CLEANUP_SOCKET" -f "$_CLEANUP_CONF" new-session -d -s main
    tmux -L "$_CLEANUP_SOCKET" new-session -d -s other
    tmux -L "$_CLEANUP_SOCKET" kill-session -t main
    # session-closed hook fires asynchronously via if-shell — wait for it
    local i
    for i in 1 2 3 4 5; do
        if tmux -L "$_CLEANUP_SOCKET" has-session -t main 2>/dev/null; then
            return 0
        fi
        sleep 0.3
    done
    return 1
}

# Verify the client actually switches to main when its session is killed
# Uses control mode (-C) with a FIFO to keep stdin open (needed when run
# under output redirection, e.g. run_test's eval > /dev/null 2>&1)
test_client_switches() {
    _CLEANUP_SOCKET="_test_sc_cs_$$"
    build_test_conf

    local fifo="/tmp/tmux-test-fifo-$$"
    mkfifo "$fifo"

    tmux -L "$_CLEANUP_SOCKET" -f "$_CLEANUP_CONF" new-session -d -s main
    tmux -L "$_CLEANUP_SOCKET" new-session -d -s temp

    # Attach a control-mode client to temp; FIFO keeps stdin open
    tmux -L "$_CLEANUP_SOCKET" -C attach-session -t temp < "$fifo" >/dev/null 2>&1 &
    _CLEANUP_PID=$!
    # Open write end to prevent EOF, hold in background fd
    exec 7>"$fifo"
    sleep 0.3

    # Verify client is on temp
    local before
    before=$(tmux -L "$_CLEANUP_SOCKET" list-clients -F '#{client_session}' 2>/dev/null | head -1)
    if [[ "$before" != "temp" ]]; then
        exec 7>&-; rm -f "$fifo"
        return 1
    fi

    # Kill temp — client should switch to main
    tmux -L "$_CLEANUP_SOCKET" kill-session -t temp
    sleep 0.5

    # Verify client moved to main
    local after
    after=$(tmux -L "$_CLEANUP_SOCKET" list-clients -F '#{client_session}' 2>/dev/null | head -1)

    # Close FIFO
    exec 7>&-
    rm -f "$fifo"
    [[ "$after" == "main" ]]
}

# Edge case: main is the sole session. With exit-empty off, the server stays
# alive after all sessions are destroyed, giving the session-closed hook time
# to recreate main. Verify main is deterministically recreated.
test_sole_main_graceful() {
    _CLEANUP_SOCKET="_test_sc_sole_$$"
    build_test_conf

    tmux -L "$_CLEANUP_SOCKET" -f "$_CLEANUP_CONF" new-session -d -s main
    tmux -L "$_CLEANUP_SOCKET" kill-session -t main
    # session-closed hook fires asynchronously — wait for recreation
    local i
    for i in 1 2 3 4 5; do
        if tmux -L "$_CLEANUP_SOCKET" has-session -t main 2>/dev/null; then
            return 0
        fi
        sleep 0.3
    done
    return 1
}

case "${1:-}" in
    kill-nonmain)       test_kill_nonmain ;;
    recreate-main)      test_recreate_main ;;
    client-switches)    test_client_switches ;;
    sole-main-graceful) test_sole_main_graceful ;;
    *)
        echo "Usage: $0 {kill-nonmain|recreate-main|client-switches|sole-main-graceful}"
        exit 1
        ;;
esac
