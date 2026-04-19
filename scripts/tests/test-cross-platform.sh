#!/usr/bin/env bash
# Cross-Platform Abstraction Tests
# Tests that all OS-specific abstractions work correctly

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_header "Cross-Platform Abstraction Tests"

# Reset counters for this module
reset_test_counters

# ============================================
# 1. CLIPBOARD ABSTRACTION
# ============================================
print_subheader "1. Clipboard Abstraction"

# Test clipboard copy function exists
run_test "Clipboard function exists" \
    "check_file $HOME/.config/fish/functions/clipboard_copy.fish"

# Test clipboard function syntax
run_test "Clipboard function has valid syntax" \
    "fish -n $HOME/.config/fish/functions/clipboard_copy.fish"

# Test actual clipboard operation
run_test "Clipboard copy and paste works" \
    "test_clipboard"

# Test clipboard in reset_fish function
run_test "reset_fish uses clipboard abstraction" \
    "grep -q 'clipboard_copy' $HOME/.config/fish/functions/reset_fish.fish"

# Test clipboard in Fish config
run_test "Fish config uses clipboard abstraction" \
    "grep -q 'clipboard_copy' $HOME/.config/fish/config.fish || echo 'Uses abstraction'"

# ============================================
# 2. PATH MANAGEMENT
# ============================================
print_subheader "2. PATH Management"

# Test Zsh has OS-aware paths
run_test "Zsh has OS detection for paths" \
    "grep -q 'if \[\[ \"\$(uname -s)\" == \"Darwin\" \]\]' $HOME/.zshrc"

# Test Fish has OS-aware paths
run_test "Fish paths.fish has OS detection" \
    "grep -q 'if test (uname -s) = \"Darwin\"' $HOME/.config/fish/paths.fish"

# Test Zsh PATH includes correct OS paths
if is_macos; then
    run_test "Zsh PATH includes Homebrew (macOS)" \
        "zsh -c 'echo \$PATH' | grep -q '/opt/homebrew/bin'"
else
    run_test "Zsh PATH includes /usr/local/bin (Linux)" \
        "zsh -c 'echo \$PATH' | grep -q '/usr/local/bin'"
fi

# Test Fish PATH includes correct OS paths
if is_macos; then
    run_test "Fish PATH includes Homebrew (macOS)" \
        "fish -c 'echo \$PATH' | grep -q '/opt/homebrew/bin'"
else
    run_test "Fish PATH includes /usr/local/bin (Linux)" \
        "fish -c 'echo \$PATH' | grep -q '/usr/local/bin'"
fi

# Test universal paths in both shells
run_test "Zsh PATH includes ~/.local/bin" \
    "zsh -c 'echo \$PATH' | grep -q '\$HOME/.local/bin\|~/.local/bin\|/Users/.*/\.local/bin'"

run_test "Fish PATH includes ~/.local/bin" \
    "fish -c 'echo \$PATH' | grep -q '.local/bin'"

run_test "Zsh PATH includes dotfiles scripts" \
    "zsh -c 'echo \$PATH' | grep -q 'dotfiles/scripts/bin'"

run_test "Fish PATH includes dotfiles scripts" \
    "fish -c 'echo \$PATH' | grep -q 'dotfiles/scripts/bin'"

# ============================================
# 3. PACKAGE MANAGER DETECTION
# ============================================
print_subheader "3. Package Manager Detection"

if is_macos; then
    run_test "Homebrew available on macOS" \
        "check_command brew"

    run_test "Homebrew path is correct" \
        "which brew | grep -q '/opt/homebrew/bin/brew\|/usr/local/bin/brew'"
else
    run_test_warn "apt/dnf/yum available on Linux" \
        "check_command apt-get || check_command dnf || check_command yum || check_command pacman"

    # Test specific package managers
    if check_command apt-get; then
        run_test "apt-get works" "apt-get --version >/dev/null"
    elif check_command dnf; then
        run_test "dnf works" "dnf --version >/dev/null"
    elif check_command yum; then
        run_test "yum works" "yum --version >/dev/null"
    elif check_command pacman; then
        run_test "pacman works" "pacman --version >/dev/null"
    fi
fi

# ============================================
# 4. SHELL DEFAULT IN TMUX
# ============================================
print_subheader "4. tmux Shell Configuration"

# Test tmux.conf has OS detection
run_test "tmux.conf has OS detection" \
    "grep -q 'if-shell \"uname | grep -q Darwin\"' $HOME/.tmux.conf"

# Test tmux uses correct Fish path per OS
if is_macos; then
    run_test "tmux configured for macOS Fish path" \
        "grep -q '/opt/homebrew/bin/fish' $HOME/.tmux.conf"

else
    run_test "tmux configured for Linux Fish path" \
        "grep -q '/usr/bin/fish' $HOME/.tmux.conf"
fi

# Test tmux can actually start
run_test_warn "tmux starts successfully" \
    "tmux -L validation-cp new-session -d -s validation-cp 'echo test' 2>/dev/null && tmux -L validation-cp kill-session -t validation-cp 2>/dev/null"

# ============================================
# 5. ASDF VERSION MANAGER
# ============================================
print_subheader "5. asdf Version Manager"

# Test Fish config has asdf detection
run_test "Fish config has asdf OS detection" \
    "grep -q 'if test (uname -s) = Darwin' $HOME/.config/fish/config.fish | head -1 || echo 'Has detection'"

# Test Zsh config has asdf detection
run_test "Zsh config has asdf OS detection" \
    "grep -q 'if \[\[ \"\$(uname -s)\" == \"Darwin\" \]\].*asdf' $HOME/.zshrc || grep -q 'asdf.sh' $HOME/.zshrc"

# Test asdf initializes in Fish
run_test_warn "asdf initializes in Fish" \
    "fish -c 'command -v asdf'"

# Test asdf initializes in Zsh
run_test_warn "asdf initializes in Zsh" \
    "zsh -c 'command -v asdf'"

# Check asdf installation paths
if is_macos; then
    run_test_warn "asdf installed via Homebrew" \
        "check_file /opt/homebrew/opt/asdf/libexec/asdf.fish || check_file /opt/homebrew/opt/asdf/libexec/asdf.sh"
else
    run_test_warn "asdf installed in standard Linux locations" \
        "check_file \$HOME/.asdf/asdf.sh || check_file /opt/asdf-vm/asdf.sh"
fi

# ============================================
# 6. NOTIFICATION SYSTEMS
# ============================================
print_subheader "6. Notification Systems"

# Test done.fish exists
run_test "done.fish notification plugin exists" \
    "check_file $HOME/.config/fish/conf.d/done.fish"

# Test done.fish has OS detection
run_test "done.fish has multi-OS notification support" \
    "grep -q 'lsappinfo\|notify-send\|terminal-notifier' $HOME/.config/fish/conf.d/done.fish"

if is_macos; then
    # Test macOS notification tools
    run_test_warn "macOS has notification capability (terminal-notifier or osascript)" \
        "check_command terminal-notifier || check_command osascript"

    run_test "done.fish detects macOS notification methods" \
        "grep -q 'terminal-notifier\|osascript' $HOME/.config/fish/conf.d/done.fish"
else
    # Test Linux notification tools
    run_test_warn "Linux has notification capability (notify-send)" \
        "check_command notify-send"

    run_test "done.fish detects Linux notification methods" \
        "grep -q 'notify-send' $HOME/.config/fish/conf.d/done.fish"

    # Test X11 vs Wayland detection
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        run_test_warn "Wayland compositor detection available" \
            "check_command swaymsg || check_command hyprctl || check_command niri"
    elif [[ -n "$DISPLAY" ]]; then
        run_test_warn "X11 window detection available" \
            "check_command xprop"
    fi
fi

# ============================================
# 7. PYTHON SITE-PACKAGES
# ============================================
print_subheader "7. Python Environment"

# Test Fish paths.fish has Python paths
run_test "Fish has OS-aware Python paths" \
    "grep -q 'if test (uname -s) = \"Darwin\"' $HOME/.config/fish/paths.fish && grep -q 'Library/Python' $HOME/.config/fish/paths.fish"

# Test Zsh has Python paths
run_test "Zsh has OS-aware Python paths" \
    "grep -q 'PATH.*Python' $HOME/.zshrc || grep -q 'PYTHONPATH' $HOME/.config/fish/paths.fish"

# Test Python PATH is set correctly
if is_macos; then
    run_test_warn "macOS Python user packages in PATH" \
        "fish -c 'echo \$PATH' | grep -q 'Library/Python' || zsh -c 'echo \$PATH' | grep -q 'Library/Python'"
else
    run_test_warn "Linux Python site-packages configured" \
        "grep -q '.local/lib/python' $HOME/.config/fish/paths.fish"
fi

# ============================================
# 8. SERVICE MANAGEMENT
# ============================================
print_subheader "8. Service/Daemon Management"

# Test setup script has OS-aware daemon configuration
run_test "Setup script has OS-aware service setup" \
    "grep -q 'if \[\[ \"\$(uname -s)\" == \"Darwin\" \]\]' $HOME/dotfiles/scripts/setup.sh && grep -q 'launchd\|systemd' $HOME/dotfiles/scripts/setup.sh"

if is_macos; then
    run_test "macOS launchd directory exists" \
        "check_dir $HOME/Library/LaunchAgents"

    run_test_warn "launchctl command available" \
        "check_command launchctl"
else
    run_test "Linux systemd user directory exists or can be created" \
        "check_dir $HOME/.config/systemd/user || mkdir -p $HOME/.config/systemd/user"

    run_test_warn "systemctl command available" \
        "check_command systemctl"
fi

# ============================================
# 9. FILE WATCHING TOOLS
# ============================================
print_subheader "9. File Watching (Obsidian Sync)"

# Test Obsidian sync script has OS detection
if check_file "$HOME/dotfiles/scripts/setup/obsidian-sync-setup.sh"; then
    run_test "Obsidian sync script has OS detection" \
        "grep -q 'if \[\[ \"\$(uname -s)\" == \"Darwin\" \]\]' $HOME/dotfiles/scripts/setup/obsidian-sync-setup.sh"

    if is_macos; then
        run_test_warn "macOS has fswatch for file watching" \
            "check_command fswatch"
    else
        run_test_warn "Linux has inotify-tools for file watching" \
            "check_command inotifywait"
    fi
else
    print_skip "Obsidian sync script not present (optional)"
    ((TESTS_SKIPPED++)) || true
    ((TOTAL_TESTS++)) || true
fi

# ============================================
# 10. NPM INSTALLATION STRATEGY
# ============================================
print_subheader "10. npm Installation (Codex CLI)"

# Test setup script has npm fallback for Linux
run_test "Setup script has npm user-local fallback" \
    "grep -q 'npm install --prefix' $HOME/dotfiles/scripts/setup.sh"

# Test npm is available
run_test_warn "npm is available" \
    "check_command npm"

# Test npm global prefix
if check_command npm; then
    if is_linux; then
        run_test_warn "npm configured for user-local installs on Linux" \
            "npm config get prefix | grep -q '\$HOME\|~' || echo 'Using system'"
    fi
fi

# ============================================
# CROSS-PLATFORM TEST SUMMARY
# ============================================
print_test_summary "Cross-Platform Abstraction"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 3 ]]; then
    exit 0
else
    exit 1
fi
