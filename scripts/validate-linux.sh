#!/usr/bin/env bash
# Linux Dotfiles Validation Script
# Tests that all cross-platform changes work correctly on Linux

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

	if eval "$test_command" &>/dev/null; then
		print_success "$test_name"
		((TESTS_PASSED++)) || true
		return 0
	else
		print_error "$test_name"
		((TESTS_FAILED++)) || true
		return 1
	fi
}

run_test_with_warning() {
	local test_name="$1"
	local test_command="$2"

	if eval "$test_command" &>/dev/null; then
		print_success "$test_name"
		((TESTS_PASSED++)) || true
		return 0
	else
		print_warning "$test_name"
		((TESTS_WARNED++)) || true
		return 1
	fi
}

# Main validation
print_header "Linux Dotfiles Validation"

# Test 1: OS Detection
print_header "1. OS Detection"
if [[ "$(uname -s)" == "Linux" ]]; then
	print_success "Linux detected correctly"
	((TESTS_PASSED++)) || true
else
	print_error "OS detection failed - not running on Linux"
	((TESTS_FAILED++)) || true
	exit 1
fi

# Test 2: Shell Configuration Syntax
print_header "2. Shell Configuration Syntax"
run_test "Zsh config syntax valid" "zsh -n $HOME/.zshrc"
run_test "Fish config syntax valid" "fish -n $HOME/.config/fish/config.fish"
run_test "Fish paths.fish syntax valid" "fish -n $HOME/.config/fish/paths.fish"

# Test 3: Tmux Configuration
print_header "3. Tmux Configuration"
run_test "Tmux config syntax valid" "tmux -f $HOME/.tmux.conf -L test new-session -d \\; kill-session"

# Test 4: Critical Paths Exist
print_header "4. Critical Linux Paths"
run_test "User bin directory exists" "test -d $HOME/bin || mkdir -p $HOME/bin"
run_test "User local bin directory exists" "test -d $HOME/.local/bin || mkdir -p $HOME/.local/bin"

# Test 5: Dotfiles Structure
print_header "5. Dotfiles Structure"
run_test "Setup script exists" "test -x $HOME/dotfiles/scripts/setup.sh"
run_test "Common library exists" "test -f $HOME/dotfiles/scripts/lib/common.sh"
run_test "Dotfiles manager exists" "test -f $HOME/dotfiles/scripts/lib/dotfiles-manager.sh"
run_test "Shell setup module exists" "test -f $HOME/dotfiles/scripts/lib/shell-setup.sh"
run_test "Linux package manager exists" "test -f $HOME/dotfiles/scripts/os/linux/package-manager.sh"

# Test 6: Cross-Platform Features
print_header "6. Cross-Platform Features"
run_test "Clipboard function exists" "test -f $HOME/.config/fish/functions/clipboard_copy.fish"
run_test "Clipboard function syntax valid" "fish -n $HOME/.config/fish/functions/clipboard_copy.fish"

# Test clipboard functionality with Linux tools
print_info "Testing clipboard function..."
if command -v xclip &>/dev/null || command -v xsel &>/dev/null || command -v wl-copy &>/dev/null; then
	if echo "validation-test" | fish -c "source $HOME/.config/fish/functions/clipboard_copy.fish; clipboard_copy" 2>/dev/null; then
		# Try to paste with available tools
		pasted=""
		if command -v xclip &>/dev/null; then
			pasted=$(xclip -selection clipboard -o 2>/dev/null || echo "")
		elif command -v xsel &>/dev/null; then
			pasted=$(xsel --clipboard --output 2>/dev/null || echo "")
		elif command -v wl-paste &>/dev/null; then
			pasted=$(wl-paste 2>/dev/null || echo "")
		fi

		if [[ "$pasted" == "validation-test" ]]; then
			print_success "Clipboard function works correctly"
			((TESTS_PASSED++)) || true
		else
			print_warning "Clipboard function executed but content verification failed"
			((TESTS_WARNED++)) || true
		fi
	else
		print_warning "Clipboard function test inconclusive"
		((TESTS_WARNED++)) || true
	fi
else
	print_warning "No clipboard tool installed (xclip, xsel, or wl-clipboard)"
	((TESTS_WARNED++)) || true
fi

# Test 7: OS-Aware Configurations
print_header "7. OS-Aware Configuration Checks"

# Check .zshrc has OS detection
if grep -Fq "if [[ \"\$(uname -s)\" == \"Darwin\" ]]" "$HOME/.zshrc"; then
	print_success ".zshrc has OS detection"
	((TESTS_PASSED++)) || true
else
	print_error ".zshrc missing OS detection"
	((TESTS_FAILED++)) || true
fi

# Check Fish paths.fish has OS detection
if grep -q 'if test (uname -s) = "Darwin"' "$HOME/.config/fish/paths.fish"; then
	print_success "Fish paths.fish has OS detection"
	((TESTS_PASSED++)) || true
else
	print_error "Fish paths.fish missing OS detection"
	((TESTS_FAILED++)) || true
fi

# Check tmux.conf has OS detection
if grep -q 'if-shell "uname | grep -q Darwin"' "$HOME/.tmux.conf"; then
	print_success "Tmux config has OS detection"
	((TESTS_PASSED++)) || true
else
	print_error "Tmux config missing OS detection"
	((TESTS_FAILED++)) || true
fi

# Test 8: Linux-Specific Checks
print_header "8. Linux-Specific Features"

# Check for systemd user directory
if [[ -d "$HOME/.config/systemd/user" ]] || mkdir -p "$HOME/.config/systemd/user" 2>/dev/null; then
	print_success "systemd user directory exists"
	((TESTS_PASSED++)) || true
else
	print_warning "Could not create systemd user directory"
	((TESTS_WARNED++)) || true
fi

# Check for inotify-tools (used by Obsidian sync)
if command -v inotifywait &>/dev/null; then
	print_success "inotify-tools installed (for file watching)"
	((TESTS_PASSED++)) || true
else
	print_warning "inotify-tools not installed (optional for Obsidian sync)"
	((TESTS_WARNED++)) || true
fi

# Check for X11 or Wayland clipboard tools
if command -v xclip &>/dev/null; then
	print_success "xclip installed (clipboard support)"
	((TESTS_PASSED++)) || true
elif command -v xsel &>/dev/null; then
	print_success "xsel installed (clipboard support)"
	((TESTS_PASSED++)) || true
elif command -v wl-copy &>/dev/null; then
	print_success "wl-clipboard installed (Wayland clipboard support)"
	((TESTS_PASSED++)) || true
else
	print_warning "No clipboard tool found (install xclip, xsel, or wl-clipboard)"
	((TESTS_WARNED++)) || true
fi

# Test 9: Setup Script Dry-Run
print_header "9. Setup Script Dry-Run (Minimal Profile)"
print_info "Running dry-run test (this may take 30-60 seconds)..."

cd "$HOME/dotfiles"
if ./scripts/setup.sh --dry-run --profile minimal &>/tmp/setup-dryrun.log; then
	print_success "Setup script dry-run completed successfully"
	((TESTS_PASSED++)) || true

	# Show summary
	if grep -q "Found.*package" /tmp/setup-dryrun.log; then
		package_count=$(grep "Found.*package" /tmp/setup-dryrun.log | awk '{sum += $2} END {print sum}')
		print_info "Would install/check $package_count packages"
	fi
else
	print_error "Setup script dry-run failed"
	((TESTS_FAILED++)) || true
	print_info "See /tmp/setup-dryrun.log for details"
fi

# Test 10: Key Tool Availability
print_header "10. Key Tool Availability (Optional)"
run_test_with_warning "Git installed" "command -v git"
run_test_with_warning "Fish installed" "command -v fish"
run_test_with_warning "Zsh installed" "command -v zsh"
run_test_with_warning "Tmux installed" "command -v tmux"

# Test 11: Git Repository Status
print_header "11. Git Repository Status"
cd "$HOME/dotfiles"
if git rev-parse --git-dir &>/dev/null; then
	print_success "Dotfiles is a git repository"
	((TESTS_PASSED++)) || true

	# Check for uncommitted changes
	if [[ -n $(git status --porcelain) ]]; then
		print_info "Uncommitted changes detected:"
		git status --short | head -5 | while read -r line; do
			print_info "  $line"
		done
	else
		print_success "No uncommitted changes"
		((TESTS_PASSED++)) || true
	fi
else
	print_error "Dotfiles is not a git repository"
	((TESTS_FAILED++)) || true
fi

# Final Summary
print_header "Validation Summary"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "  ${YELLOW}Warned:${NC}  $TESTS_WARNED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
	echo -e "${GREEN}✓ All critical tests passed!${NC}"
	echo -e "${GREEN}✓ Linux installation is working correctly.${NC}"
	exit 0
elif [[ $TESTS_FAILED -le 2 ]]; then
	echo -e "${YELLOW}⚠ Some tests failed, but core functionality appears intact.${NC}"
	echo -e "${YELLOW}⚠ Review failures above for details.${NC}"
	exit 1
else
	echo -e "${RED}✗ Multiple critical tests failed.${NC}"
	echo -e "${RED}✗ Please review the errors above.${NC}"
	exit 1
fi
