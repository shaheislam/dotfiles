#!/usr/bin/env bats
# Integration tests for aimux status

setup() {
  export AIMUX_TEST_DIR="$(mktemp -d)"
  AIMUX_TEST_DIR="$(cd "$AIMUX_TEST_DIR" && pwd -P)"
  export AIMUX_HOME="$AIMUX_TEST_DIR/.aimux"
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"

  mkdir -p "$AIMUX_HOME"

  export TEST_REPO="$AIMUX_TEST_DIR/test-repo"
  mkdir -p "$TEST_REPO"
  (
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@aimux.dev"
    git config user.name "aimux-test"
    git config core.hooksPath /dev/null
    git commit --allow-empty -q -m "Initial commit"
  )

  unset TMUX
}

teardown() {
  rm -rf "$AIMUX_TEST_DIR"
}

@test "status shows table with headers" {
  cd "$TEST_REPO"
  run aimux status
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE"* ]]
  [[ "$output" == *"BRANCH"* ]]
  [[ "$output" == *"CONTAINER"* ]]
  [[ "$output" == *"AGENT"* ]]
}

@test "status lists created worktrees" {
  cd "$TEST_REPO"
  aimux new --no-devcon status-test-branch 2>/dev/null || true

  cd "$TEST_REPO"
  run aimux status
  [ "$status" -eq 0 ]
  [[ "$output" == *"status-test-branch"* ]]

  # Cleanup
  cd "$TEST_REPO"
  aimux kill --force status-test-branch 2>/dev/null || true
}

@test "status handles repo with no extra worktrees" {
  cd "$TEST_REPO"
  run aimux status
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE"* ]]
}

@test "status works outside git repo using state files" {
  cd /tmp
  run aimux status
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE"* ]]
}

@test "status --help shows usage" {
  run aimux status --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
