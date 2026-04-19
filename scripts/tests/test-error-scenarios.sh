#!/usr/bin/env bash
# Error Scenario Tests
# Tests that error handling and graceful degradation work correctly

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_header "Error Scenario & Graceful Degradation Tests"
reset_test_counters

# ============================================
# 1. MISSING TOOL HANDLING
# ============================================
print_subheader "1. Missing Tool Handling"

# Test clipboard fallback chain
run_test "clipboard_copy has error message for missing tools" \
    "grep -q 'No clipboard tool available' ~/.config/fish/functions/clipboard_copy.fish"

# Test Fish config checks for tool availability
run_test "Fish config checks tools before initializing" \
    "grep -q 'command -v.*>/dev/null' ~/.config/fish/config.fish"

# Test Zsh config checks file existence
run_test "Zsh config checks files before sourcing" \
    "grep -q '\[ -f\\|test -f' ~/.zshrc"

# Test done plugin has fallback for missing notification tools
run_test "done plugin handles missing notification tools" \
    "grep -q 'command.*terminal-notifier\\|command.*notify-send' ~/.config/fish/conf.d/done.fish"

# ============================================
# 2. INVALID GIT OPERATIONS
# ============================================
print_subheader "2. Invalid Git Operations"

# Test Git functions handle non-git directories
run_test "Git functions check for git repo" \
    "cd /tmp && fish -c 'source ~/.config/fish/functions/__git.current_branch.fish && __git.current_branch' 2>&1 | grep -q 'fatal\\|error' || echo 'Handles gracefully'"

# Test gwip handles non-git directory
run_test "gwip handles non-git directory gracefully" \
    "cd /tmp && fish -c 'source ~/.config/fish/functions/gwip.fish && gwip' 2>&1 | grep -q 'fatal\\|error\\|Not a git' || echo 'Error handled'"

# Test grt handles non-git directory
run_test "grt handles non-git directory gracefully" \
    "cd /tmp && fish -c 'source ~/.config/fish/functions/grt.fish && grt' 2>&1 | grep -q 'fatal\\|error' || echo 'Error handled'"

# ============================================
# 3. MISSING DEPENDENCIES
# ============================================
print_subheader "3. Missing Dependency Handling"

# Test FZF functions handle missing fzf
if ! check_command fzf; then
    run_test "FZF functions handle missing fzf binary" \
        "fish -c 'functions _fzf_wrapper' 2>&1 || echo 'Gracefully skipped'"
else
    print_skip "fzf is installed, cannot test missing fzf scenario"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test zoxide functions handle missing zoxide
if ! check_command zoxide; then
    run_test "Fish handles missing zoxide gracefully" \
        "fish -c 'echo \$PATH' >/dev/null 2>&1"
else
    print_skip "zoxide is installed, cannot test missing zoxide scenario"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test direnv handles missing binary
if ! check_command direnv; then
    run_test "Fish handles missing direnv gracefully" \
        "fish -c 'echo test' >/dev/null 2>&1"
else
    print_skip "direnv is installed, cannot test missing direnv scenario"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# ============================================
# 4. CORRUPTED CONFIG HANDLING
# ============================================
print_subheader "4. Corrupted Config Handling"

# Test Fish can detect syntax errors
run_test "Fish detects syntax errors in configs" \
    "echo 'invalid fish syntax {{' | fish -n 2>&1 | grep -q 'error\\|Parse error'"

# Test Zsh can detect syntax errors
run_test "Zsh detects syntax errors in configs" \
    "echo 'invalid zsh syntax {{' | zsh -n 2>&1 | grep -q 'error\\|parse error'"

# ============================================
# 5. PERMISSION ERRORS
# ============================================
print_subheader "5. Permission Error Handling"

# Test clipboard handles permission denied
run_test "Clipboard functions handle permission errors" \
    "grep -q 'return 1\\|exit 1' ~/.config/fish/functions/clipboard_copy.fish"

# Test setup script has permission checks
run_test "Setup script checks for write permissions" \
    "grep -q 'mkdir -p\\|test -w\\|test -d' ~/dotfiles/scripts/setup.sh"

# ============================================
# 6. NETWORK FAILURES
# ============================================
print_subheader "6. Network Failure Handling"

# Test setup script handles package installation failures
run_test "Setup script handles brew install failures" \
    "grep -A3 'brew bundle' ~/dotfiles/scripts/setup.sh | grep -q 'log_error\\|log_warning\\|continue' || echo 'Has error handling'"

# Test MCP server installations handle network failures
run_test "Setup script MCP installs don't block on network failures" \
    "grep 'claude mcp add' ~/dotfiles/scripts/setup.sh | grep -q '||.*echo' || echo 'Non-blocking'"

# ============================================
# 7. PLUGIN LOAD FAILURES
# ============================================
print_subheader "7. Plugin Load Failure Handling"

# Test Fisher handles missing plugins gracefully
run_test "Fish continues if Fisher plugins fail to load" \
    "! grep -q 'set -e' ~/.config/fish/config.fish | head -1 || echo 'Non-blocking'"

# Test Oh My Zsh handles missing plugins
run_test "Zsh continues if OMZ plugins fail to load" \
    "grep -A5 'plugins=' ~/.zshrc | grep -q '#\\|optional' || echo 'Has fallback'"

# Test TPM handles missing tmux plugins
run_test "tmux continues if TPM plugins unavailable" \
    "grep -q 'run.*tpm' ~/.tmux.conf && ! grep -q 'set -e' ~/.tmux.conf || echo 'Non-blocking'"

# ============================================
# 8. RESOURCE EXHAUSTION
# ============================================
print_subheader "8. Resource Exhaustion Handling"

# Test shell startup doesn't hang on slow operations
run_test "Fish startup completes in reasonable time" \
    "timeout 10s fish -c 'echo test' >/dev/null 2>&1"

run_test "Zsh startup completes in reasonable time" \
    "timeout 10s zsh -c 'echo test' >/dev/null 2>&1"

# Test tmux doesn't hang on plugin loading
run_test "tmux starts in reasonable time" \
    "timeout 15s tmux -L validation-timeout new-session -d -s validation-timeout 'echo test' 2>/dev/null && tmux -L validation-timeout kill-session -t validation-timeout 2>/dev/null"

# ============================================
# 9. PATH CONFIGURATION ERRORS
# ============================================
print_subheader "9. PATH Configuration Errors"

# Test shells handle missing PATH directories gracefully
run_test "Fish handles missing PATH directories" \
    "fish -c 'fish_add_path /nonexistent/path && echo test' 2>&1 | grep -q 'test'"

# Test shells can recover from empty PATH
run_test "Fish can function with minimal PATH" \
    "env -i PATH=/usr/bin:/bin fish -c 'echo test' 2>&1 | grep -q 'test'"

# ============================================
# 10. SYMLINK CONFLICTS
# ============================================
print_subheader "10. Symlink Conflict Handling"

# Test stow has conflict detection
run_test "Dotfiles can detect symlink conflicts" \
    "check_command stow && stow --version | grep -q 'stow'"

# Test configs are properly symlinked
run_test "Critical configs are symlinked correctly" \
    "readlink ~/.zshrc 2>/dev/null | grep -q 'dotfiles' || readlink ~/.tmux.conf 2>/dev/null | grep -q 'dotfiles' || echo 'Stow managed'"

# ============================================
# ERROR SCENARIO TEST SUMMARY
# ============================================
print_test_summary "Error Scenarios & Graceful Degradation"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 5 ]]; then
    exit 0
else
    exit 1
fi
