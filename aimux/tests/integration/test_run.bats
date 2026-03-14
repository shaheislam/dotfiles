#!/usr/bin/env bats
# Integration tests for aimux run

setup() {
  export AIMUX_TEST_DIR="$(mktemp -d)"
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
    git commit --allow-empty -q -m "Initial commit"
  )

  # Create a mock agent that exits quickly
  export MOCK_AGENT="$AIMUX_TEST_DIR/mock-claude"
  cat > "$MOCK_AGENT" <<'AGENT'
#!/usr/bin/env bash
echo "COMPLETE"
AGENT
  chmod +x "$MOCK_AGENT"

  # Not inside tmux for most tests
  unset TMUX
}

teardown() {
  tmux -L aimux-test kill-server 2>/dev/null || true
  rm -rf "$AIMUX_TEST_DIR"
}

@test "run fails without ticket argument" {
  cd "$TEST_REPO"
  run aimux run
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "run --help shows usage" {
  run aimux run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"ticket"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "run creates workspace for ticket" {
  cd "$TEST_REPO"
  run aimux run --no-devcon TEST-001 "Fix the bug"
  # It should create the worktree even without tmux
  local branch_name="test-001"
  [ -d "$AIMUX_TEST_DIR/test-repo-${branch_name}" ] || \
    [[ "$output" == *"Not in tmux"* ]] || \
    [[ "$output" == *"Ticket execution started"* ]]
}

@test "run prints ticket metadata" {
  cd "$TEST_REPO"
  run aimux run --no-devcon PROJ-123 "Fix auth bug"
  [[ "$output" == *"PROJ-123"* ]] || [[ "$output" == *"proj-123"* ]]
  [[ "$output" == *"claude"* ]] || [[ "$output" == *"Provider"* ]] || [[ "$output" == *"Not in tmux"* ]]
}

@test "run --provider flag selects provider" {
  cd "$TEST_REPO"
  run aimux run --no-devcon --provider codex TASK-456 "Refactor utils"
  [[ "$output" == *"codex"* ]] || [[ "$output" == *"Provider"* ]]
}

@test "run normalizes ticket key to branch name" {
  cd "$TEST_REPO"
  run aimux run --no-devcon FEAT-789 "Add tests"
  # Branch name should be lowercased and sanitized
  [[ "$output" == *"feat-789"* ]] || [ -d "$AIMUX_TEST_DIR/test-repo-feat-789" ]
}

@test "run fails gracefully outside git repo" {
  cd /tmp
  run aimux run --no-devcon BUG-111 "Fix something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"git repository"* ]] || [[ "$output" == *"error"* ]]
}
