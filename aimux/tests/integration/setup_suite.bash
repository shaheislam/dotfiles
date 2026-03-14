#!/usr/bin/env bash
# Shared setup for aimux integration tests.
# Creates: temp git repo, temp tmux server, temp AIMUX_HOME.
#
# Requires bats-core and the bats-file helper (optional but recommended).
# Install: brew install bats-core

setup_suite() {
    export AIMUX_TEST_DIR="$(mktemp -d)"
    export AIMUX_HOME="$AIMUX_TEST_DIR/.aimux"
    export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PATH="$AIMUX_DIR/bin:$PATH"

    # Create AIMUX_HOME
    mkdir -p "$AIMUX_HOME"

    # Create a test git repository with an initial commit
    export TEST_REPO="$AIMUX_TEST_DIR/test-repo"
    mkdir -p "$TEST_REPO"
    (
        cd "$TEST_REPO"
        git init -q
        git config user.email "test@aimux.dev"
        git config user.name "aimux-test"
        git commit --allow-empty -q -m "Initial commit"
    )

    # Start an isolated tmux server for tests
    export TMUX_TMPDIR="$AIMUX_TEST_DIR"
    tmux -L aimux-test new-session -d -s test -c "$TEST_REPO" 2>/dev/null || true

    # Set TMUX variable so in_tmux() returns true inside test commands
    local tmux_pid
    tmux_pid="$(tmux -L aimux-test display-message -p '#{pid}' 2>/dev/null || echo '0')"
    export TMUX="$AIMUX_TEST_DIR/aimux-test,${tmux_pid},0"
}

teardown_suite() {
    tmux -L aimux-test kill-server 2>/dev/null || true
    rm -rf "$AIMUX_TEST_DIR"
}
