#!/usr/bin/env bats
# Unit tests for lib/aimux/_common.sh

setup() {
  export AIMUX_TEST_DIR="$(mktemp -d)"
  export AIMUX_HOME="$AIMUX_TEST_DIR/.aimux"
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export AIMUX_LIB="$AIMUX_DIR/lib/aimux"

  # Source _common.sh in a subshell-friendly way
  source "$AIMUX_LIB/_common.sh"
}

teardown() {
  rm -rf "$AIMUX_TEST_DIR"
}

# === sanitize_name ===

@test "sanitize_name removes special characters" {
  result="$(sanitize_name "feat/my@branch#1")"
  [[ "$result" == "feat-my-branch-1" ]]
}

@test "sanitize_name collapses consecutive dashes" {
  result="$(sanitize_name "foo---bar")"
  [[ "$result" == "foo-bar" ]]
}

@test "sanitize_name strips leading and trailing dashes" {
  result="$(sanitize_name "-leading-trailing-")"
  [[ "$result" == "leading-trailing" ]]
}

@test "sanitize_name preserves alphanumerics, underscores, and hyphens" {
  result="$(sanitize_name "my_branch-123")"
  [[ "$result" == "my_branch-123" ]]
}

@test "sanitize_name handles empty string" {
  result="$(sanitize_name "")"
  [[ "$result" == "" ]]
}

@test "sanitize_name handles all-special input" {
  result="$(sanitize_name "@#\$%^")"
  [[ "$result" == "" ]]
}

# === has ===

@test "has returns 0 for existing commands" {
  run has bash
  [ "$status" -eq 0 ]
}

@test "has returns 1 for missing commands" {
  run has this_command_does_not_exist_aimux_test
  [ "$status" -eq 1 ]
}

# === require ===

@test "require succeeds for installed command" {
  run require bash
  [ "$status" -eq 0 ]
}

@test "require dies for missing command" {
  run require this_command_does_not_exist_aimux_test
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

# === git_root ===

@test "git_root returns root in a git repo" {
  local repo="$AIMUX_TEST_DIR/repo"
  mkdir -p "$repo"
  (cd "$repo" && git init -q && git commit --allow-empty -q -m "init")
  result="$(cd "$repo" && git_root)"
  # Use realpath to handle /tmp -> /private/tmp symlink on macOS
  local expected
  expected="$(cd "$repo" && pwd -P)"
  local actual
  actual="$(cd "$result" && pwd -P)"
  [[ "$actual" == "$expected" ]]
}

@test "git_root returns empty string outside git repo" {
  result="$(cd /tmp && git_root)"
  [[ -z "$result" ]]
}

# === in_tmux ===

@test "in_tmux returns 1 when TMUX is unset" {
  unset TMUX
  run in_tmux
  [ "$status" -eq 1 ]
}

@test "in_tmux returns 0 when TMUX is set" {
  export TMUX="/tmp/tmux-test,12345,0"
  run in_tmux
  [ "$status" -eq 0 ]
}

# === ensure_home ===

@test "ensure_home creates AIMUX_HOME directory" {
  rm -rf "$AIMUX_HOME"
  ensure_home
  [ -d "$AIMUX_HOME" ]
}

@test "ensure_home creates state subdirectory" {
  rm -rf "$AIMUX_HOME"
  ensure_home
  [ -d "$AIMUX_HOME/state" ]
}

@test "ensure_home is idempotent" {
  ensure_home
  ensure_home
  [ -d "$AIMUX_HOME" ]
}

# === log ===

@test "log appends to log file" {
  ensure_home
  log "test message alpha"
  [ -f "$AIMUX_LOG" ]
  grep -q "test message alpha" "$AIMUX_LOG"
}

@test "log includes timestamp" {
  ensure_home
  log "timestamped entry"
  grep -qE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$AIMUX_LOG"
}

@test "log appends multiple entries" {
  ensure_home
  log "first entry"
  log "second entry"
  local count
  count="$(wc -l < "$AIMUX_LOG" | tr -d ' ')"
  [ "$count" -eq 2 ]
}

# === info/warn/error/die ===

@test "info prints with info prefix" {
  run info "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"info"* ]]
  [[ "$output" == *"hello"* ]]
}

@test "warn prints to stderr" {
  run warn "caution"
  [[ "$output" == *"warn"* ]]
  [[ "$output" == *"caution"* ]]
}

@test "die exits with status 1" {
  run die "fatal"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"fatal"* ]]
}

# === Color constants ===

@test "color constants are defined" {
  [[ -n "$RED" ]]
  [[ -n "$GREEN" ]]
  [[ -n "$BLUE" ]]
  [[ -n "$RESET" ]]
}

@test "agent state colors are defined" {
  [[ "$COLOR_WORKING" == "#f7768e" ]]
  [[ "$COLOR_WAITING" == "#e0af68" ]]
  [[ "$COLOR_DONE" == "#9ece6a" ]]
  [[ "$COLOR_STUCK" == "#bb9af7" ]]
}

# === state_write / state_read / state_remove ===

@test "state_write creates JSON file atomically" {
  ensure_home
  state_write "test-ws" "status=active" "branch=main"
  local sf
  sf="$(state_file "test-ws")"
  [ -f "$sf" ]
  # No temp files left behind
  local tmp_count
  tmp_count="$(ls "$AIMUX_HOME/state/"*.tmp 2>/dev/null | wc -l | tr -d ' ')"
  [ "$tmp_count" -eq 0 ]
}

@test "state_read returns value from JSON" {
  ensure_home
  state_write "read-ws" "status=running" "branch=feat"
  local val
  val="$(state_read "read-ws" "status" "")"
  [[ "$val" == "running" ]]
}

@test "state_read returns default when key missing" {
  ensure_home
  state_write "default-ws" "status=active"
  local val
  val="$(state_read "default-ws" "nonexistent" "fallback")"
  [[ "$val" == "fallback" ]]
}

@test "state_remove deletes state file" {
  ensure_home
  state_write "remove-ws" "status=done"
  local sf
  sf="$(state_file "remove-ws")"
  [ -f "$sf" ]
  state_remove "remove-ws"
  [ ! -f "$sf" ]
}
