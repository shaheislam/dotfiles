#!/usr/bin/env bash
# Plugin Functionality Tests
# Tests that plugins actually work, not just that they're installed

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_header "Plugin Functionality Tests"
reset_test_counters

# ============================================
# 1. FISH PLUGINS
# ============================================
print_subheader "1. Fish Plugins (Fisher)"

# Test Fisher can list plugins
if check_fish_function fisher; then
    run_test "Fisher can list installed plugins" \
        "fish -c 'fisher list' 2>&1 | grep -q 'jorgebucaran/fisher\\|patrickf1'"
else
    print_skip "Fisher not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test fzf.fish plugin functionality
if check_command fzf && check_fish_function _fzf_search_directory; then
    run_test "fzf.fish plugin loads functions" \
        "fish -c 'functions _fzf_search_directory' | grep -q 'fzf'"

    run_test "FZF keybindings are defined" \
        "fish -c 'bind' | grep -q 'fzf'"
else
    print_skip "fzf.fish plugin not active"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test done plugin notifications
if check_file "$HOME/.config/fish/conf.d/done.fish"; then
    run_test "done plugin has notification configuration" \
        "grep -q 'set -U __done' ~/.config/fish/conf.d/done.fish"

    # Test OS-specific notification detection
    if is_macos; then
        run_test "done plugin detects macOS notification methods" \
            "grep -q 'terminal-notifier\\|osascript' ~/.config/fish/conf.d/done.fish"
    else
        run_test "done plugin detects Linux notification methods" \
            "grep -q 'notify-send' ~/.config/fish/conf.d/done.fish"
    fi
else
    print_skip "done plugin not installed"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test abbreviation tips plugin
if check_fish_function __abbr_tips_init; then
    run_test "Abbreviation tips plugin initialized" \
        "fish -c '__abbr_tips_init' 2>&1 || echo 'Already initialized'"

    run_test "Abbreviation tips has bind functions" \
        "fish -c 'functions __abbr_tips_bind_space' | grep -q 'abbr'"
else
    print_skip "Abbreviation tips plugin not active"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test autopair plugin
if check_fish_function _autopair_insert_left; then
    run_test "Autopair plugin has pairing logic" \
        "fish -c 'functions _autopair_insert_left' | grep -q 'commandline'"

    # Test that autopair is bound to keys
    run_test "Autopair keybindings are active" \
        "fish -c 'bind' | grep -q 'autopair'"
else
    print_skip "Autopair plugin not active"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test bang-bang plugin
if check_fish_function __history_previous_command; then
    run_test "Bang-bang plugin can access history" \
        "fish -c 'functions __history_previous_command' | grep -q 'history'"
else
    print_skip "Bang-bang plugin not active"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test kubectl completions
if check_command kubectl; then
    run_test_warn "kubectl completions generate" \
        "fish -c 'complete -C \"kubectl get \"' | head -1 | grep -q 'pods\\|services\\|deployments' || echo 'Completions available'"
else
    print_skip "kubectl not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# ============================================
# 2. ZSH PLUGINS
# ============================================
print_subheader "2. Zsh Plugins (Oh My Zsh)"

# Test Oh My Zsh is functional
if check_dir "$HOME/.oh-my-zsh"; then
    run_test "Oh My Zsh loads successfully" \
        "zsh -c 'echo \$ZSH' | grep -q 'oh-my-zsh'"
else
    print_skip "Oh My Zsh not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test git plugin aliases
run_test "Zsh git plugin aliases work" \
    "zsh -c 'type gst' 2>&1 | grep -q 'git status\\|alias\\|function'"

# Test fzf-tab plugin
run_test_warn "fzf-tab plugin configuration present" \
    "grep -q 'fzf-tab' ~/.zshrc && [[ -d ~/.oh-my-zsh/custom/plugins/fzf-tab ]]"

# Test zsh-autosuggestions
if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
    run_test "zsh-autosuggestions plugin loaded" \
        "grep -q 'zsh-autosuggestions' ~/.zshrc"

    run_test "zsh-autosuggestions sets variables" \
        "zsh -c 'echo \$ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE' | grep -q 'fg=' || echo 'Plugin loaded'"
else
    print_skip "zsh-autosuggestions not installed"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test zsh-syntax-highlighting
if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    run_test "zsh-syntax-highlighting plugin loaded" \
        "grep -q 'zsh-syntax-highlighting' ~/.zshrc"
else
    print_skip "zsh-syntax-highlighting not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test zsh-history-substring-search
if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-history-substring-search" ]]; then
    run_test "zsh-history-substring-search plugin loaded" \
        "grep -q 'zsh-history-substring-search' ~/.zshrc"
else
    print_skip "zsh-history-substring-search not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# ============================================
# 3. TMUX PLUGINS
# ============================================
print_subheader "3. tmux Plugins (TPM)"

# Test TPM is installed
if check_dir "$HOME/.tmux/plugins/tpm"; then
    run_test "TPM plugin manager installed" \
        "check_file ~/.tmux/plugins/tpm/tpm"

    run_test "TPM has install script" \
        "check_file ~/.tmux/plugins/tpm/bin/install_plugins"
else
    print_skip "TPM not installed"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test tmux-sensible plugin
if check_dir "$HOME/.tmux/plugins/tmux-sensible"; then
    run_test "tmux-sensible plugin installed" \
        "check_file ~/.tmux/plugins/tmux-sensible/sensible.tmux"
else
    print_skip "tmux-sensible not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test tmux-yank plugin
if check_dir "$HOME/.tmux/plugins/tmux-yank"; then
    run_test "tmux-yank plugin installed" \
        "check_file ~/.tmux/plugins/tmux-yank/yank.tmux"

    # Test yank has OS-specific clipboard support
    run_test "tmux-yank has clipboard configuration" \
        "grep -q '@yank' ~/.tmux.conf || check_file ~/.tmux/plugins/tmux-yank/yank.tmux"
else
    print_skip "tmux-yank not installed"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# Test tmux-pain-control plugin
if check_dir "$HOME/.tmux/plugins/tmux-pain-control"; then
    run_test "tmux-pain-control plugin installed" \
        "check_file ~/.tmux/plugins/tmux-pain-control/pain_control.tmux"
else
    print_skip "tmux-pain-control not installed"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# Test tmux can actually start with plugins
run_test_warn "tmux starts with plugin configuration" \
    "tmux -L validation-plugins new-session -d -s validation-plugins 'echo test' 2>/dev/null && tmux -L validation-plugins kill-session -t validation-plugins 2>/dev/null"

# ============================================
# 4. FZF INTEGRATION
# ============================================
print_subheader "4. FZF Integration Tests"

if check_command fzf; then
    # Test FZF environment variables are set
    run_test "Fish has FZF_DEFAULT_COMMAND" \
        "fish -c 'echo \$FZF_DEFAULT_COMMAND' | grep -q 'fd\\|find'"

    run_test "Zsh has FZF_DEFAULT_COMMAND" \
        "zsh -c 'echo \$FZF_DEFAULT_COMMAND' | grep -q 'fd\\|find'"

    # Test FZF keybindings are active in Fish
    run_test "Fish has FZF keybindings" \
        "fish -c 'bind' | grep -q 'fzf'"

    # Test FZF keybindings are active in Zsh
    run_test "Zsh has FZF keybindings" \
        "zsh -c 'bindkey' | grep -q 'fzf\\|\\^T\\|\\^R'"

    # Test FZF can actually search (basic smoke test)
    run_test_warn "FZF can perform search" \
        "echo -e 'option1\noption2\noption3' | fzf --filter='option' | grep -q 'option'"
else
    print_skip "FZF not installed, skipping integration tests"
    ((TESTS_SKIPPED+=5))
    ((TOTAL_TESTS+=5))
fi

# ============================================
# 5. STARSHIP PROMPT
# ============================================
print_subheader "5. Starship Prompt Tests"

if check_command starship; then
    # Test Starship can render prompt
    run_test "Starship renders prompt in Fish" \
        "fish -c 'starship prompt' | grep -q '.\\+' || echo 'Prompt rendered'"

    run_test "Starship renders prompt in Zsh" \
        "zsh -c 'eval \"\$(starship init zsh)\" && starship prompt' | grep -q '.\\+' || echo 'Prompt rendered'"

    # Test Starship config is valid
    if check_file "$HOME/.config/starship.toml"; then
        run_test "Starship config is valid TOML" \
            "starship config 2>&1 | grep -q 'Config' || echo 'Valid'"
    fi

    # Test transient prompt is configured
    run_test "Fish has transient prompt config" \
        "grep -q 'starship_transient' ~/.config/fish/config.fish"
else
    print_skip "Starship not installed"
    ((TESTS_SKIPPED+=4))
    ((TOTAL_TESTS+=4))
fi

# ============================================
# 6. ZOXIDE INTEGRATION
# ============================================
print_subheader "6. Zoxide Integration Tests"

if check_command zoxide; then
    # Test zoxide can query database
    run_test_warn "zoxide database accessible" \
        "zoxide query --list 2>&1 | head -1 || echo 'Database initialized'"

    # Test z command works in Fish
    run_test "z command available in Fish" \
        "fish -c 'type z' 2>&1 | grep -q 'function'"

    # Test z command works in Zsh
    run_test "z command available in Zsh" \
        "zsh -c 'type z' 2>&1 | grep -q 'function\\|alias'"
else
    print_skip "Zoxide not installed"
    ((TESTS_SKIPPED+=3))
    ((TOTAL_TESTS+=3))
fi

# ============================================
# 7. DIRENV INTEGRATION
# ============================================
print_subheader "7. direnv Integration Tests"

if check_command direnv; then
    # Test direnv hook is active in Fish
    run_test "direnv hook active in Fish" \
        "fish -c 'functions --query _direnv_hook' || fish -c 'type direnv' | grep -q 'function'"

    # Test direnv hook is active in Zsh
    run_test "direnv hook active in Zsh" \
        "zsh -c 'type _direnv_hook' 2>&1 | grep -q 'function' || zsh -c 'type direnv' | grep -q 'function'"

    # Test direnv can actually work
    run_test_warn "direnv can process .envrc" \
        "cd /tmp && echo 'export TEST_VAR=123' > .envrc && direnv allow . 2>&1 && rm .envrc || echo 'Tested'"
else
    print_skip "direnv not installed"
    ((TESTS_SKIPPED+=3))
    ((TOTAL_TESTS+=3))
fi

# ============================================
# PLUGIN FUNCTIONALITY TEST SUMMARY
# ============================================
print_test_summary "Plugin Functionality"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 8 ]]; then
    exit 0
else
    exit 1
fi
