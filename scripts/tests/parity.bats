#!/usr/bin/env bats

setup() {
    DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
}

@test "parity manifest is valid" {
    run bash "$DOTFILES_ROOT/scripts/parity/validate.sh"
    [ "$status" -eq 0 ]
}

@test "setup.sh accepts explicit WSL override" {
    run bash -c "grep -q 'macos | linux | wsl' '$DOTFILES_ROOT/scripts/setup.sh'"
    [ "$status" -eq 0 ]
}

@test "agentic harness portable files exist" {
    [ -d "$DOTFILES_ROOT/.claude/hooks" ]
    [ -d "$DOTFILES_ROOT/.config/opencode/plugin" ]
    [ -d "$DOTFILES_ROOT/skills" ]
    [ -d "$DOTFILES_ROOT/.claude/agents" ]
    [ -f "$DOTFILES_ROOT/.mcp.json" ]
}

@test "Linux package mapper documents binary-install gap" {
    run bash -c "grep -q 'BINARY_INSTALL' '$DOTFILES_ROOT/scripts/os/linux/package-manager.sh'"
    [ "$status" -eq 0 ]
}
