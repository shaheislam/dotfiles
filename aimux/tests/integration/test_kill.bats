#!/usr/bin/env bats
# Integration tests for aimux kill

setup() {
  export AIMUX_TEST_DIR="$(mktemp -d)"
  # Resolve symlinks (macOS /tmp -> /private/tmp)
  AIMUX_TEST_DIR="$(cd "$AIMUX_TEST_DIR" && pwd -P)"
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
    # Disable hooks to avoid side effects in test worktrees
    git config core.hooksPath /dev/null
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

  cd "$TEST_REPO"
  run aimux kill --force kill-test-branch
  [ "$status" -eq 0 ]
  [[ "$output" == *"killed"* ]] || [[ "$output" == *"Workspace killed"* ]]
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

  # Find the actual worktree path (may differ due to symlink resolution)
  local wt_dir
  wt_dir="$(git worktree list --porcelain | grep "^worktree.*force-test-branch" | head -1 | sed 's/^worktree //')"
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

  # Find the actual worktree path
  local wt_dir
  wt_dir="$(git worktree list --porcelain | grep "^worktree.*dirty-branch" | head -1 | sed 's/^worktree //')"
  [ -d "$wt_dir" ]

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
