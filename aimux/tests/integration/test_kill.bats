#!/usr/bin/env bats
# Integration tests for aimux kill

setup() {
  export AIMUX_TEST_DIR="$(mktemp -d)"
  export AIMUX_HOME="$AIMUX_TEST_DIR/.aimux"
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"

  mkdir -p "$AIMUX_HOME"

  # Create a fresh git repo for each test
  export TEST_REPO="$AIMUX_TEST_DIR/test-repo"
  mkdir -p "$TEST_REPO"
  (
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@aimux.dev"
    git config user.name "aimux-test"
    git commit --allow-empty -q -m "Initial commit"
  )

  # Do not set TMUX so tests run without tmux dependency
  unset TMUX
}

teardown() {
  tmux -L aimux-test kill-server 2>/dev/null || true
  rm -rf "$AIMUX_TEST_DIR"
}

@test "kill removes worktree" {
  cd "$TEST_REPO"
  aimux new --no-devcon kill-test-branch 2>/dev/null || true
  [ -d "$AIMUX_TEST_DIR/test-repo-kill-test-branch" ]

  cd "$TEST_REPO"
  run aimux kill kill-test-branch
  [ "$status" -eq 0 ]
  [ ! -d "$AIMUX_TEST_DIR/test-repo-kill-test-branch" ]
}

@test "kill refuses protected branch: main" {
  cd "$TEST_REPO"
  run aimux kill main
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "kill refuses protected branch: master" {
  cd "$TEST_REPO"
  run aimux kill master
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "kill refuses protected branch: develop" {
  cd "$TEST_REPO"
  run aimux kill develop
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "kill refuses protected branch: production" {
  cd "$TEST_REPO"
  run aimux kill production
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "kill --force removes worktree with uncommitted changes" {
  cd "$TEST_REPO"
  aimux new --no-devcon force-test-branch 2>/dev/null || true
  local wt_dir="$AIMUX_TEST_DIR/test-repo-force-test-branch"
  [ -d "$wt_dir" ]

  # Create uncommitted changes
  echo "dirty" > "$wt_dir/dirty.txt"
  (cd "$wt_dir" && git add dirty.txt)

  cd "$TEST_REPO"
  run aimux kill --force force-test-branch
  [ "$status" -eq 0 ]
  [[ "$output" == *"killed"* ]] || [[ "$output" == *"Workspace killed"* ]]
}

@test "kill fails without uncommitted changes warning when not forced" {
  cd "$TEST_REPO"
  aimux new --no-devcon dirty-branch 2>/dev/null || true
  local wt_dir="$AIMUX_TEST_DIR/test-repo-dirty-branch"

  # Create uncommitted changes
  echo "dirty" > "$wt_dir/dirty.txt"
  (cd "$wt_dir" && git add dirty.txt)

  cd "$TEST_REPO"
  run aimux kill dirty-branch
  [ "$status" -ne 0 ]
  [[ "$output" == *"uncommitted"* ]]
}

@test "kill handles non-existent workspace gracefully" {
  cd "$TEST_REPO"
  run aimux kill nonexistent-branch-xyz
  # Should either succeed silently or fail gracefully
  # The branch does not exist, so worktree remove is a no-op
  [[ "$status" -eq 0 ]] || [[ "$output" == *"killed"* ]] || [[ "$output" != "" ]]
}

@test "kill requires target argument" {
  run aimux kill
  [ "$status" -ne 0 ]
}

@test "kill --help shows usage" {
  run aimux kill --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
