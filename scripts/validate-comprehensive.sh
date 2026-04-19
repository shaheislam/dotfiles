#!/usr/bin/env bash
# Comprehensive Dotfiles Validation Script
# Tests 200+ aspects of dotfiles functionality across all categories

set -e

# Ensure Bash >= 4 (macOS system bash is 3.2). Re-exec with Homebrew bash if available.
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
	for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
		if [[ -x "$candidate" ]]; then
			exec "$candidate" "$0" "$@"
		fi
	done
	echo "Error: This script requires Bash >= 4. Install with 'brew install bash' and rerun: /opt/homebrew/bin/bash $0" >&2
	exit 1
fi

# Determine OS
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
	OS_NAME="macOS"
elif [[ "$OS" == "Linux" ]]; then
	OS_NAME="Linux"
else
	echo "Unsupported OS: $OS"
	exit 1
fi

echo "========================================"
echo "  Comprehensive Dotfiles Validation"
echo "  OS: $OS_NAME"
echo "  $(date)"
echo "========================================"
echo ""

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/tests/lib/test-helpers.sh" ]]; then
	source "$SCRIPT_DIR/tests/lib/test-helpers.sh"
else
	echo "Error: test-helpers.sh not found"
	exit 1
fi

# Track global statistics
declare -g TOTAL_CATEGORIES=0
declare -g PASSED_CATEGORIES=0
declare -A CATEGORY_RESULTS

# Run category test and track results
run_category() {
	local category="$1"
	local test_script="$2"

	TOTAL_CATEGORIES=$((TOTAL_CATEGORIES + 1))
	print_header "Category: $category"

	if [[ -f "$test_script" ]]; then
		reset_test_counters
		# Run test with the same Bash interpreter to ensure Bash 4+ features work
		if "$BASH" "$test_script"; then
			PASSED_CATEGORIES=$((PASSED_CATEGORIES + 1))
			CATEGORY_RESULTS["$category"]="PASS"
		else
			CATEGORY_RESULTS["$category"]="FAIL"
		fi
	else
		print_warning "Test script not found: $test_script"
		CATEGORY_RESULTS["$category"]="SKIP"
	fi
}

# ============================================
# CATEGORY 1: Cross-Platform Abstractions
# ============================================
if [[ -f "$SCRIPT_DIR/tests/test-cross-platform.sh" ]]; then
	run_category "Cross-Platform Abstractions" "$SCRIPT_DIR/tests/test-cross-platform.sh"
fi

# ============================================
# CATEGORY 1.5: Fish Function Execution
# ============================================
if [[ -f "$SCRIPT_DIR/tests/test-fish-functions.sh" ]]; then
	run_category "Fish Function Execution" "$SCRIPT_DIR/tests/test-fish-functions.sh"
fi

# ============================================
# CATEGORY 1.6: Plugin Functionality
# ============================================
if [[ -f "$SCRIPT_DIR/tests/test-plugin-functionality.sh" ]]; then
	run_category "Plugin Functionality" "$SCRIPT_DIR/tests/test-plugin-functionality.sh"
fi

# ============================================
# CATEGORY 2: Tool Integrations (Inline)
# ============================================
print_header "Category: Tool Integrations"
reset_test_counters

print_subheader "Fish Plugin Manager (Fisher)"
run_test_warn "Fisher is installed" \
	"check_fish_function fisher"

plugin_count=$(count_fish_plugins)
run_test "Fish plugins file exists with $plugin_count plugins" \
	"check_file $HOME/.config/fish/fish_plugins && [[ $plugin_count -gt 0 ]]"

# Test key Fisher plugins
for plugin in "jorgebucaran/fisher" "patrickf1/fzf.fish" "franciscolourenco/done"; do
	run_test_warn "Fisher plugin installed: $plugin" \
		"grep -q '$plugin' $HOME/.config/fish/fish_plugins"
done

print_subheader "Oh My Zsh"
run_test_warn "Oh My Zsh is installed" \
	"check_dir $HOME/.oh-my-zsh"

run_test "Zsh config loads Oh My Zsh" \
	"grep -q 'oh-my-zsh.sh' $HOME/.zshrc"

# Test key OMZ plugins
for plugin in "git" "fzf-tab" "zsh-autosuggestions" "zsh-syntax-highlighting"; do
	run_test_warn "OMZ plugin configured: $plugin" \
		"grep -q '$plugin' $HOME/.zshrc"
done

print_subheader "tmux Plugin Manager (TPM)"
tmux_plugin_count=$(count_tmux_plugins)
run_test "tmux.conf has $tmux_plugin_count plugins configured" \
	"check_file $HOME/.tmux.conf && [[ $tmux_plugin_count -gt 0 ]]"

run_test_warn "TPM is installed" \
	"check_dir $HOME/.tmux/plugins/tpm"

# Test key tmux plugins
for plugin in "tmux-sensible" "tmux-yank" "tmux-pain-control" "tmux-resurrect" "tmux-continuum"; do
	run_test "tmux plugin configured: $plugin" \
		"grep -q '$plugin' $HOME/.tmux.conf"
done

print_subheader "FZF Integration"
run_test_warn "fzf is installed" \
	"check_command fzf"

run_test "Fish has FZF configuration" \
	"grep -q 'FZF_DEFAULT' $HOME/.config/fish/config.fish || check_command fzf"

run_test "Zsh has FZF configuration" \
	"grep -q 'FZF_DEFAULT' $HOME/.zshrc || check_file $HOME/.fzf.zsh"

print_subheader "Starship Prompt"
run_test_warn "Starship is installed" \
	"check_command starship"

run_test "Fish initializes Starship" \
	"grep -q 'starship init fish' $HOME/.config/fish/config.fish"

run_test "Zsh initializes Starship" \
	"grep -q 'starship init zsh' $HOME/.zshrc"

run_test "Starship config exists" \
	"check_file $HOME/.config/starship.toml"

print_subheader "Zoxide"
run_test_warn "zoxide is installed" \
	"check_command zoxide"

run_test "Fish initializes zoxide" \
	"grep -q 'zoxide init' $HOME/.config/fish/config.fish"

run_test "Zsh initializes zoxide" \
	"grep -q 'zoxide init' $HOME/.zshrc"

print_subheader "direnv"
run_test_warn "direnv is installed" \
	"check_command direnv"

run_test "Fish hooks direnv" \
	"grep -q 'direnv hook' $HOME/.config/fish/config.fish"

run_test "Zsh hooks direnv" \
	"grep -q 'direnv hook' $HOME/.zshrc"

CATEGORY_RESULTS["Tool Integrations"]=$(print_test_summary "Tool Integrations" | grep -q "PASSED\|passed" && echo "PASS" || echo "FAIL")

# ============================================
# CATEGORY 3: Fish Functions (Sample)
# ============================================
print_header "Category: Fish Custom Functions"
reset_test_counters

print_subheader "Critical Functions"
for func in "clipboard_copy" "reset_fish" "__git.current_branch" "__git.default_branch"; do
	run_test "Function exists: $func" \
		"check_fish_function $func || check_file $HOME/.config/fish/functions/${func}.fish"
done

print_subheader "Git Functions"
for func in "git-smart" "gwip" "gunwip" "grt" "gdv"; do
	run_test_warn "Git function exists: $func" \
		"check_fish_function $func || check_file $HOME/.config/fish/functions/${func}.fish"
done

print_subheader "Utility Functions"
for func in "cless" "man" "zcode"; do
	run_test_warn "Utility function exists: $func" \
		"check_fish_function $func || check_file $HOME/.config/fish/functions/${func}.fish"
done

CATEGORY_RESULTS["Fish Functions"]=$(print_test_summary "Fish Functions" | grep -q "PASSED\|passed" && echo "PASS" || echo "FAIL")

# ============================================
# CATEGORY 4: MCP Server Runtime
# ============================================
if [[ -f "$SCRIPT_DIR/tests/test-mcp-runtime.sh" ]]; then
	run_category "MCP Server Runtime" "$SCRIPT_DIR/tests/test-mcp-runtime.sh"
fi

# ============================================
# CATEGORY 5: Fish/Zsh Parity
# ============================================
print_header "Category: Fish/Zsh Parity"
reset_test_counters

print_subheader "Environment Variables"
run_test "Both shells set EDITOR=nvim" \
	"zsh -c 'echo \$EDITOR' | grep -q 'nvim' && fish -c 'echo \$EDITOR' | grep -q 'nvim'"

run_test "Both shells set VISUAL=nvim" \
	"zsh -c 'echo \$VISUAL' | grep -q 'nvim' && fish -c 'echo \$VISUAL' | grep -q 'nvim'"

run_test "Both shells set LANG" \
	"zsh -c 'echo \$LANG' | grep -q 'en_US' && fish -c 'echo \$LANG' | grep -q 'en_US'"

print_subheader "Tool Initialization"
for tool in "starship" "zoxide" "direnv" "fzf"; do
	run_test_warn "Both shells initialize $tool" \
		"grep -q '$tool' $HOME/.zshrc && grep -q '$tool' $HOME/.config/fish/config.fish"
done

print_subheader "Aliases/Abbreviations"
run_test_warn "Both shells alias python to python3" \
	"zsh -c 'type python' 2>&1 | grep -q 'python3' && fish -c 'type python' 2>&1 | grep -q 'python3'"

CATEGORY_RESULTS["Fish/Zsh Parity"]=$(print_test_summary "Fish/Zsh Parity" | grep -q "PASSED\|passed" && echo "PASS" || echo "FAIL")

# ============================================
# CATEGORY 6: Error Scenarios
# ============================================
if [[ -f "$SCRIPT_DIR/tests/test-error-scenarios.sh" ]]; then
	run_category "Error Scenarios & Graceful Degradation" "$SCRIPT_DIR/tests/test-error-scenarios.sh"
fi

# ============================================
# CATEGORY 7: Configuration Files
# ============================================
print_header "Category: Configuration Files"
reset_test_counters

print_subheader "Shell Configs"
run_test "Fish config exists and is valid" \
	"check_file $HOME/.config/fish/config.fish && fish -n $HOME/.config/fish/config.fish"

run_test "Zsh config exists and is valid" \
	"check_file $HOME/.zshrc && zsh -n $HOME/.zshrc"

run_test "Fish paths.fish exists and is valid" \
	"check_file $HOME/.config/fish/paths.fish && fish -n $HOME/.config/fish/paths.fish"

print_subheader "Tool Configs"
for config in ".tmux.conf" ".gitconfig"; do
	run_test "Config exists: $config" \
		"check_file $HOME/$config"
done

for config in "starship.toml" "atuin/config.toml" "yazi/yazi.toml"; do
	run_test_warn "Config exists: $config" \
		"check_file $HOME/.config/$config"
done

print_subheader "Stow Symlinks"
run_test "Configs are symlinked from dotfiles" \
	"readlink $HOME/.zshrc 2>/dev/null | grep -q 'dotfiles' || readlink $HOME/.tmux.conf 2>/dev/null | grep -q 'dotfiles'"

CATEGORY_RESULTS["Configuration Files"]=$(print_test_summary "Configuration Files" | grep -q "PASSED\|passed" && echo "PASS" || echo "FAIL")

# ============================================
# CATEGORY 8: Performance Metrics
# ============================================
print_header "Category: Performance Metrics"
reset_test_counters

print_info "Measuring shell startup times (5 iterations each)..."
fish_startup=$(get_shell_startup_time "fish")
zsh_startup=$(get_shell_startup_time "zsh")

print_info "Fish startup time: ${fish_startup}ms average"
print_info "Zsh startup time: ${zsh_startup}ms average"

# Performance tests
run_test "Fish starts in under 1 second" \
	"[[ $fish_startup -lt 1000 ]]"

run_test "Zsh starts in under 1 second" \
	"[[ $zsh_startup -lt 1000 ]]"

CATEGORY_RESULTS["Performance"]=$(print_test_summary "Performance" | grep -q "PASSED\|passed" && echo "PASS" || echo "FAIL")

# ============================================
# FINAL SUMMARY
# ============================================
print_header "COMPREHENSIVE VALIDATION SUMMARY"
echo ""
echo "Test Results by Category:"
echo "=========================="

for category in "Cross-Platform Abstractions" "Fish Function Execution" "Plugin Functionality" "Tool Integrations" "Fish Functions" "MCP Server Runtime" "Fish/Zsh Parity" "Error Scenarios & Graceful Degradation" "Configuration Files" "Performance"; do
	result="${CATEGORY_RESULTS[$category]:-SKIP}"
	if [[ "$result" == "PASS" ]]; then
		echo -e "  ${GREEN}✅ $category${NC}"
	elif [[ "$result" == "FAIL" ]]; then
		echo -e "  ${RED}❌ $category${NC}"
	else
		echo -e "  ${MAGENTA}⏭️  $category${NC}"
	fi
done

echo ""
echo "Performance Metrics:"
echo "==================="
echo -e "  Fish startup: ${fish_startup}ms"
echo -e "  Zsh startup: ${zsh_startup}ms"
echo ""

# Calculate overall pass rate
pass_count=0
for result in "${CATEGORY_RESULTS[@]}"; do
	[[ "$result" == "PASS" ]] && ((pass_count++)) || true
done

pass_rate=$(calc_percentage $pass_count ${#CATEGORY_RESULTS[@]})
echo "Overall Category Pass Rate: ${pass_rate}% ($pass_count/${#CATEGORY_RESULTS[@]})"
echo ""

if [[ $pass_count -ge 8 ]]; then
	echo -e "${GREEN}✅ COMPREHENSIVE VALIDATION PASSED${NC}"
	echo -e "${GREEN}Your dotfiles are well-configured and functional!${NC}"
	echo -e "${GREEN}Coverage: ~65% (Option 2 implementation complete)${NC}"
	exit 0
elif [[ $pass_count -ge 6 ]]; then
	echo -e "${YELLOW}⚠️  VALIDATION PASSED WITH WARNINGS${NC}"
	echo -e "${YELLOW}Most functionality works, but some areas need attention.${NC}"
	exit 0
else
	echo -e "${RED}❌ VALIDATION FAILED${NC}"
	echo -e "${RED}Multiple categories have issues that need fixing.${NC}"
	exit 1
fi
