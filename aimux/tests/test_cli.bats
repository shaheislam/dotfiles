#!/usr/bin/env bats

setup() {
  export AIMUX_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PATH="$AIMUX_DIR/bin:$PATH"
}

# === Version & Help ===

@test "aimux version outputs version string" {
  run aimux version
  [ "$status" -eq 0 ]
  [[ "$output" == "aimux 0.1.0" ]]
}

@test "aimux --version outputs version string" {
  run aimux --version
  [ "$status" -eq 0 ]
  [[ "$output" == "aimux 0.1.0" ]]
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
