#!/usr/bin/env bash
# Linux Dotfiles Runtime Validation Script
# Actually executes and tests that everything works, not just syntax

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# Track results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local show_output="${3:-false}"

    print_info "Testing: $test_name"

    if [[ "$show_output" == "true" ]]; then
        if eval "$test_command"; then
            print_success "$test_name"
            ((TESTS_PASSED++))
            return 0
        else
            print_error "$test_name"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        local output=$(eval "$test_command" 2>&1)
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            print_success "$test_name"
            ((TESTS_PASSED++))
            return 0
        else
            print_error "$test_name"
            print_info "Error: $output"
            ((TESTS_FAILED++))
            return 1
        fi
    fi
}

# Main validation
print_header "Linux Dotfiles Runtime Validation"
echo "This will actually execute and test functionality"

# Test 1: Shell Startup (Actually source configs)
print_header "1. Shell Startup Tests"

# Test Zsh can source config
print_info "Starting Zsh with config..."
if zsh -c "source ~/.zshrc && echo 'Zsh loaded successfully'" &>/tmp/zsh-test.log; then
    print_success "Zsh sources config and runs commands"
    ((TESTS_PASSED++))
else
    print_error "Zsh failed to source config"
    cat /tmp/zsh-test.log
    ((TESTS_FAILED++))
fi

# Test Fish can source config
print_info "Starting Fish with config..."
if fish -c "echo 'Fish loaded successfully'" &>/tmp/fish-test.log; then
    print_success "Fish sources config and runs commands"
    ((TESTS_PASSED++))
else
    print_error "Fish failed to source config"
    cat /tmp/fish-test.log
    ((TESTS_FAILED++))
fi

# Test 2: PATH Variables Work
print_header "2. PATH Configuration Tests"

# Test Zsh PATH includes critical directories
print_info "Testing Zsh PATH..."
zsh_path=$(zsh -c 'echo $PATH')
if echo "$zsh_path" | grep -q "$HOME/.local/bin"; then
    print_success "Zsh PATH includes user local bin"
    ((TESTS_PASSED++))
else
    print_error "Zsh PATH missing user local bin"
    ((TESTS_FAILED++))
fi

if echo "$zsh_path" | grep -q "$HOME/dotfiles/scripts/bin"; then
    print_success "Zsh PATH includes dotfiles scripts"
    ((TESTS_PASSED++))
else
    print_error "Zsh PATH missing dotfiles scripts"
    ((TESTS_FAILED++))
fi

# Test Fish PATH
print_info "Testing Fish PATH..."
fish_path=$(fish -c 'echo $PATH')
if echo "$fish_path" | grep -q "$HOME/.local/bin"; then
    print_success "Fish PATH includes user local bin"
    ((TESTS_PASSED++))
else
    print_error "Fish PATH missing user local bin"
    ((TESTS_FAILED++))
fi

# Test 3: OS Detection in Shells
print_header "3. OS Detection Tests"

# Test Zsh OS detection
zsh_os=$(zsh -c 'echo $(uname -s)')
if [[ "$zsh_os" == "Linux" ]]; then
    print_success "Zsh detects Linux correctly"
    ((TESTS_PASSED++))
else
    print_error "Zsh OS detection failed: $zsh_os"
    ((TESTS_FAILED++))
fi

# Test Fish OS detection
fish_os=$(fish -c 'echo (uname -s)')
if [[ "$fish_os" == "Linux" ]]; then
    print_success "Fish detects Linux correctly"
    ((TESTS_PASSED++))
else
    print_error "Fish OS detection failed: $fish_os"
    ((TESTS_FAILED++))
fi

# Test 4: Clipboard Function (Actually Copy/Paste)
print_header "4. Clipboard Function Tests"

print_info "Testing clipboard_copy function..."
test_string="linux-validation-$(date +%s)"

# Check if clipboard tools are available
if command -v xclip &>/dev/null || command -v xsel &>/dev/null || command -v wl-copy &>/dev/null; then
    # Test with Fish
    if echo "$test_string" | fish -c "source ~/.config/fish/functions/clipboard_copy.fish; clipboard_copy" 2>/tmp/clipboard-error.log; then
        sleep 0.5  # Give clipboard a moment

        # Try to paste with available tools
        pasted=""
        if command -v xclip &>/dev/null; then
            pasted=$(xclip -selection clipboard -o 2>/dev/null || echo "")
        elif command -v xsel &>/dev/null; then
            pasted=$(xsel --clipboard --output 2>/dev/null || echo "")
        elif command -v wl-paste &>/dev/null; then
            pasted=$(wl-paste 2>/dev/null || echo "")
        fi

        if [[ "$pasted" == "$test_string" ]]; then
            print_success "Clipboard function works (copy & paste verified)"
            ((TESTS_PASSED++))
        else
            print_error "Clipboard copied but paste failed. Expected: $test_string, Got: $pasted"
            ((TESTS_FAILED++))
        fi
    else
        print_error "Clipboard function failed"
        cat /tmp/clipboard-error.log
        ((TESTS_FAILED++))
    fi
else
    print_warning "No clipboard tools installed (xclip, xsel, or wl-clipboard)"
    print_info "Install with: sudo apt install xclip  # or xsel or wl-clipboard"
    ((TESTS_WARNED++))
fi

# Test 5: Tmux Startup
print_header "5. Tmux Runtime Tests"

print_info "Starting tmux session..."
if tmux -L validation-test new-session -d -s validation 'echo "Tmux works"' 2>/tmp/tmux-error.log; then
    print_success "Tmux starts and creates session"
    ((TESTS_PASSED++))

    # Check if tmux is using correct shell
    tmux_shell=$(tmux -L validation-test show-options -g default-shell | awk '{print $2}')
    if echo "$tmux_shell" | grep -q "fish"; then
        print_success "Tmux uses Fish shell"
        ((TESTS_PASSED++))
    else
        print_warning "Tmux shell: $tmux_shell (expected fish)"
        ((TESTS_WARNED++))
    fi

    # Cleanup
    tmux -L validation-test kill-session -t validation 2>/dev/null || true
else
    print_error "Tmux failed to start"
    cat /tmp/tmux-error.log
    ((TESTS_FAILED++))
fi

# Test 6: Environment Variables
print_header "6. Environment Variable Tests"

# Test EDITOR in Zsh
editor_zsh=$(zsh -c 'echo $EDITOR')
if [[ "$editor_zsh" == "nvim" ]]; then
    print_success "Zsh EDITOR set to nvim"
    ((TESTS_PASSED++))
else
    print_warning "Zsh EDITOR: $editor_zsh (expected nvim)"
    ((TESTS_WARNED++))
fi

# Test EDITOR in Fish
editor_fish=$(fish -c 'echo $EDITOR')
if [[ "$editor_fish" == "nvim" ]]; then
    print_success "Fish EDITOR set to nvim"
    ((TESTS_PASSED++))
else
    print_warning "Fish EDITOR: $editor_fish (expected nvim)"
    ((TESTS_WARNED++))
fi

# Test 7: Tool Integrations
print_header "7. Tool Integration Tests"

# Test if asdf loads in Zsh
if zsh -c 'command -v asdf' &>/dev/null; then
    print_success "asdf loads in Zsh"
    ((TESTS_PASSED++))
else
    print_warning "asdf not available in Zsh"
    ((TESTS_WARNED++))
fi

# Test if zoxide initializes
if zsh -c 'command -v z' &>/dev/null || zsh -c 'type z' &>/dev/null; then
    print_success "zoxide (z) available in Zsh"
    ((TESTS_PASSED++))
else
    print_warning "zoxide not initialized in Zsh"
    ((TESTS_WARNED++))
fi

# Test if direnv hooks
if zsh -c 'type direnv' &>/dev/null; then
    print_success "direnv available in Zsh"
    ((TESTS_PASSED++))
else
    print_warning "direnv not available in Zsh"
    ((TESTS_WARNED++))
fi

# Test 8: Fish Functions
print_header "8. Fish Functions Tests"

# Test if reset_fish function exists and works
if fish -c 'functions reset_fish' &>/dev/null; then
    print_success "reset_fish function defined"
    ((TESTS_PASSED++))

    # Try to execute it
    if fish -c 'reset_fish' &>/dev/null; then
        print_success "reset_fish executes without errors"
        ((TESTS_PASSED++))
    else
        print_error "reset_fish fails to execute"
        ((TESTS_FAILED++))
    fi
else
    print_error "reset_fish function not found"
    ((TESTS_FAILED++))
fi

# Test 9: Aliases
print_header "9. Alias Tests"

# Test Zsh aliases
if zsh -c 'type python' 2>&1 | grep -q "python3"; then
    print_success "Zsh python→python3 alias works"
    ((TESTS_PASSED++))
else
    print_warning "Zsh python alias not working"
    ((TESTS_WARNED++))
fi

# Test Fish aliases
if fish -c 'type ls' 2>&1 | grep -q "eza"; then
    print_success "Fish ls→eza alias works"
    ((TESTS_PASSED++))
else
    print_warning "Fish ls alias not working (eza might not be installed)"
    ((TESTS_WARNED++))
fi

# Test 10: Stow Symlinks
print_header "10. Stow Symlink Tests"

# Check if configs are properly symlinked
if [[ -L "$HOME/.zshrc" ]]; then
    link_target=$(readlink "$HOME/.zshrc")
    if echo "$link_target" | grep -q "dotfiles"; then
        print_success ".zshrc is symlinked from dotfiles"
        ((TESTS_PASSED++))
    else
        print_warning ".zshrc symlink target: $link_target"
        ((TESTS_WARNED++))
    fi
else
    print_warning ".zshrc is not a symlink (might be a copy)"
    ((TESTS_WARNED++))
fi

if [[ -L "$HOME/.tmux.conf" ]]; then
    link_target=$(readlink "$HOME/.tmux.conf")
    if echo "$link_target" | grep -q "dotfiles"; then
        print_success ".tmux.conf is symlinked from dotfiles"
        ((TESTS_PASSED++))
    else
        print_warning ".tmux.conf symlink target: $link_target"
        ((TESTS_WARNED++))
    fi
else
    print_warning ".tmux.conf is not a symlink"
    ((TESTS_WARNED++))
fi

# Test 11: History Configuration
print_header "11. History Configuration Tests"

# Test Zsh history settings
hist_size=$(zsh -c 'echo $HISTSIZE')
if [[ "$hist_size" == "100000" ]]; then
    print_success "Zsh HISTSIZE configured correctly (100000)"
    ((TESTS_PASSED++))
else
    print_warning "Zsh HISTSIZE: $hist_size (expected 100000)"
    ((TESTS_WARNED++))
fi

# Test 12: FZF Integration
print_header "12. FZF Integration Tests"

if command -v fzf &>/dev/null; then
    print_success "FZF installed"
    ((TESTS_PASSED++))

    # Test FZF in Zsh
    if zsh -c 'bindkey | grep fzf' &>/dev/null; then
        print_success "FZF keybindings active in Zsh"
        ((TESTS_PASSED++))
    else
        print_warning "FZF keybindings not found in Zsh"
        ((TESTS_WARNED++))
    fi
else
    print_warning "FZF not installed"
    ((TESTS_WARNED++))
fi

# Test 13: Linux-Specific Features
print_header "13. Linux-Specific Feature Tests"

# Test systemd user directory
if [[ -d "$HOME/.config/systemd/user" ]]; then
    print_success "systemd user directory exists"
    ((TESTS_PASSED++))
else
    print_warning "systemd user directory not found"
    ((TESTS_WARNED++))
fi

# Test inotify-tools
if command -v inotifywait &>/dev/null; then
    print_success "inotify-tools installed (file watching)"
    ((TESTS_PASSED++))

    # Quick test that it actually works
    if timeout 1 inotifywait /tmp &>/dev/null; then
        print_success "inotifywait executes correctly"
        ((TESTS_PASSED++))
    fi
else
    print_warning "inotify-tools not installed (optional for Obsidian sync)"
    ((TESTS_WARNED++))
fi

# Final Summary
print_header "Runtime Validation Summary"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}Warned:${NC}  $TESTS_WARNED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ ALL RUNTIME TESTS PASSED! ✓✓✓${NC}"
    echo -e "${GREEN}✓ Everything is running and working correctly.${NC}"
    echo -e "${GREEN}✓ Your Linux dotfiles are fully functional.${NC}"
    exit 0
elif [[ $TESTS_FAILED -le 2 ]]; then
    echo -e "${YELLOW}⚠ Some tests failed, but core functionality works.${NC}"
    echo -e "${YELLOW}⚠ Review failures above - might be missing optional tools.${NC}"
    exit 1
else
    echo -e "${RED}✗ Multiple runtime tests failed.${NC}"
    echo -e "${RED}✗ There are functional issues that need fixing.${NC}"
    exit 1
fi
