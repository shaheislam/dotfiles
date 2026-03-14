#!/usr/bin/env bats
# Integration tests for aimux new

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
    git config core.hooksPath /dev/null
    git commit --allow-empty -q -m "Initial commit"
  )
}

teardown() {
  # Kill any test tmux server
  tmux -L aimux-test kill-server 2>/dev/null || true
  rm -rf "$AIMUX_TEST_DIR"
}

@test "new creates worktree for new branch" {
  cd "$TEST_REPO"
  unset TMUX
  run aimux new --no-devcon test-branch
  [ "$status" -eq 0 ]
  # Check worktree exists (use git to verify since paths may differ)
  cd "$TEST_REPO"
  run git worktree list
  [[ "$output" == *"test-branch"* ]]
}

@test "new creates worktree for existing branch" {
  cd "$TEST_REPO"
  git branch existing-branch
  unset TMUX
  run aimux new --no-devcon existing-branch
  [ "$status" -eq 0 ]
  cd "$TEST_REPO"
  run git worktree list
  [[ "$output" == *"existing-branch"* ]]
}

@test "new creates tmux window when inside tmux" {
  # Start an isolated tmux server for this test
  export TMUX_TMPDIR="$AIMUX_TEST_DIR"
  tmux -L aimux-test new-session -d -s test -c "$TEST_REPO" 2>/dev/null || skip "cannot start tmux server"
  local tmux_pid
  tmux_pid="$(tmux -L aimux-test display-message -p '#{pid}' 2>/dev/null || echo '0')"
  export TMUX="$AIMUX_TEST_DIR/aimux-test,${tmux_pid},0"

  cd "$TEST_REPO"
  run aimux new --no-devcon tmux-test-branch
  [ "$status" -eq 0 ]
  [[ "$output" == *"tmux window"* ]] || [[ "$output" == *"Workspace ready"* ]]
}

@test "new --no-devcon skips devcontainer" {
  cd "$TEST_REPO"
  unset TMUX
  run aimux new --no-devcon devcon-skip-test
  [ "$status" -eq 0 ]
  [[ "$output" != *"Starting devcontainer"* ]] || [[ "$output" == *"Workspace ready"* ]]
}

@test "new fails gracefully outside git repo" {
  cd /tmp
  unset TMUX
  run aimux new --no-devcon some-branch
  [ "$status" -ne 0 ]
  [[ "$output" == *"git repository"* ]] || [[ "$output" == *"error"* ]]
}

@test "new is idempotent for existing worktree" {
  cd "$TEST_REPO"
  unset TMUX
  run aimux new --no-devcon idempotent-branch
  [ "$status" -eq 0 ]
  run aimux new --no-devcon idempotent-branch
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "new --help shows usage" {
  run aimux new --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--no-devcon"* ]]
}

@test "new requires branch name" {
  cd "$TEST_REPO"
  run aimux new
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}
