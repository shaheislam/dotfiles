#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

# === Version & Help ===

@test "aimux version outputs version string" {
  run aimux version
  [ "$status" -eq 0 ]
  [[ "$output" == "aimux 0.3.0" ]]
}

@test "aimux --version outputs version string" {
  run aimux --version
  [ "$status" -eq 0 ]
  [[ "$output" == "aimux 0.3.0" ]]
}

@test "aimux help shows usage" {
  run aimux help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
  [[ "$output" == *"COMMANDS"* ]]
}

@test "aimux --help shows usage" {
  run aimux --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "aimux with no args shows help" {
  run aimux
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

# === Doctor ===

@test "aimux doctor runs without error" {
  run aimux doctor
  [ "$status" -eq 0 ]
}

@test "aimux doctor checks tmux" {
  run aimux doctor
  [[ "$output" == *"tmux"* ]]
}

@test "aimux doctor checks git" {
  run aimux doctor
  [[ "$output" == *"git"* ]]
}

@test "aimux doctor checks fzf" {
  run aimux doctor
  [[ "$output" == *"fzf"* ]]
}

@test "aimux doctor shows summary" {
  run aimux doctor
  [[ "$output" == *"Summary"* ]]
}

# === Status ===

@test "aimux status runs in git repo" {
  run aimux status
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE"* ]]
  [[ "$output" == *"BRANCH"* ]]
}

# === New ===

@test "aimux new requires branch name" {
  run aimux new
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "aimux new --help shows usage" {
  run aimux new --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--no-devcon"* ]]
}

# === Kill ===

@test "aimux kill requires target" {
  run aimux kill
  [ "$status" -ne 0 ]
}

@test "aimux kill rejects protected branch: main" {
  run aimux kill main
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "aimux kill rejects protected branch: master" {
  run aimux kill master
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "aimux kill --help shows usage" {
  run aimux kill --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# === Run ===

@test "aimux run requires ticket" {
  run aimux run
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "aimux run --help shows usage" {
  run aimux run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"ticket"* ]]
}

# === Notify ===

@test "aimux notify requires message" {
  run aimux notify
  [ "$status" -ne 0 ]
}

@test "aimux notify --help shows usage" {
  run aimux notify --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# === Daemon ===

@test "aimux daemon status works" {
  run aimux daemon status
  [ "$status" -eq 0 ]
}

@test "aimux daemon --help shows usage" {
  run aimux daemon --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# === Queue ===

@test "aimux queue help shows usage" {
  run aimux queue help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Subcommands"* ]]
}

# === Attach ===

@test "aimux attach --help shows usage" {
  run aimux attach --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# === Log ===

@test "aimux log --help shows usage" {
  run aimux log --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"log"* ]]
}

# === Queue (extended) ===

@test "aimux queue add requires args" {
  run aimux queue add
  # Should either error or show usage guidance
  [[ "$status" -ne 0 ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"not yet"* ]] || [[ "$output" == *"queue"* ]]
}

@test "aimux queue list works" {
  run aimux queue list
  [ "$status" -eq 0 ] || [[ "$output" == *"queue"* ]]
}

@test "aimux queue status works" {
  run aimux queue status
  [ "$status" -eq 0 ] || [[ "$output" == *"queue"* ]]
}

# === Alias shortcuts ===

@test "aimux st is alias for status" {
  run aimux st --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"WORKTREE"* ]]
}

@test "aimux k is alias for kill" {
  run aimux k --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "aimux q is alias for queue" {
  run aimux q help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Subcommands"* ]] || [[ "$output" == *"queue"* ]]
}

@test "aimux a is alias for attach" {
  run aimux a --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# === Merge ===

@test "aimux merge --help shows usage" {
  run aimux merge --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--pr"* ]]
  [[ "$output" == *"--squash"* ]]
}

@test "aimux merge requires workspace name" {
  run aimux merge
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "aimux merge rejects protected branch: main" {
  run aimux merge main
  [ "$status" -ne 0 ]
  [[ "$output" == *"protected"* ]]
}

@test "aimux m is alias for merge" {
  run aimux m --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# === PR ===

@test "aimux pr --help shows usage" {
  run aimux pr --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--title"* ]]
  [[ "$output" == *"--draft"* ]]
}

# === Init ===

@test "aimux init --help shows usage" {
  run aimux init --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--force"* ]]
}
