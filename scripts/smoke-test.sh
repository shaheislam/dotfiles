#!/usr/bin/env bash
# Smoke Test - Quick verification of core dotfiles functionality
# Usage: ./scripts/smoke-test.sh [DOTFILES_PATH]
#
# If DOTFILES_PATH is provided, tests that directory instead of the parent.
# This allows testing against a different dotfiles installation.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via argument or default to parent directory
if [ $# -gt 0 ] && [ -d "$1" ]; then
    DOTFILES_ROOT="$(cd "$1" && pwd)"
else
    DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Skip test function
skip_test() {
    local test_name="$1"
    local reason="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    log_warning "$test_name (SKIPPED: $reason)"
}

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Dotfiles Smoke Test Suite                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
log_info "Operating System: $OS"
log_info "Dotfiles Root: $DOTFILES_ROOT"
echo ""

# ============================================================================
# Test 1: Core Directory Structure
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Directory Structure ━━━${NC}"

run_test "Dotfiles root exists" "[ -d '$DOTFILES_ROOT' ]"
run_test "Scripts directory exists" "[ -d '$DOTFILES_ROOT/scripts' ]"
run_test ".config directory exists" "[ -d '$DOTFILES_ROOT/.config' ]"
run_test "Homebrew directory exists" "[ -d '$DOTFILES_ROOT/homebrew' ]"

echo ""

# ============================================================================
# Test 2: Essential Files
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Essential Files ━━━${NC}"

run_test "CLAUDE.md exists" "[ -f '$DOTFILES_ROOT/CLAUDE.md' ]"
run_test "README.md exists" "[ -f '$DOTFILES_ROOT/README.md' ]"
run_test ".gitconfig exists" "[ -f '$DOTFILES_ROOT/.gitconfig' ]"
run_test ".tmux.conf exists" "[ -f '$DOTFILES_ROOT/.tmux.conf' ]"
run_test ".zshrc exists" "[ -f '$DOTFILES_ROOT/.zshrc' ]"
run_test "Brewfile exists" "[ -f '$DOTFILES_ROOT/homebrew/Brewfile' ]"
run_test "setup.sh exists and is executable" "[ -x '$DOTFILES_ROOT/scripts/setup.sh' ]"

echo ""

# ============================================================================
# Test 3: Fish Shell Configuration
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Fish Shell Configuration ━━━${NC}"

run_test "Fish config directory exists" "[ -d '$DOTFILES_ROOT/.config/fish' ]"
run_test "Fish config.fish exists" "[ -f '$DOTFILES_ROOT/.config/fish/config.fish' ]"
run_test "Fish functions directory exists" "[ -d '$DOTFILES_ROOT/.config/fish/functions' ]"

echo ""

# ============================================================================
# Test 4: Stow Compatibility
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Stow Compatibility ━━━${NC}"

run_test ".stow-local-ignore exists" "[ -f '$DOTFILES_ROOT/.stow-local-ignore' ]"

# Verify stow-local-ignore contains essential patterns
if [ -f "$DOTFILES_ROOT/.stow-local-ignore" ]; then
    run_test "Stow ignores README" "grep -q 'README' '$DOTFILES_ROOT/.stow-local-ignore'"
    run_test "Stow ignores scripts/" "grep -q 'scripts' '$DOTFILES_ROOT/.stow-local-ignore'"
else
    skip_test "Stow ignore patterns" "file not found"
fi

echo ""

# ============================================================================
# Test 5: Shell Scripts Syntax
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Shell Script Syntax ━━━${NC}"

if command -v bash &> /dev/null; then
    run_test "setup.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/setup.sh'"
else
    skip_test "setup.sh syntax check" "bash not available"
fi

echo ""

# ============================================================================
# Test 6: Git Configuration
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Git Configuration ━━━${NC}"

run_test ".gitignore exists" "[ -f '$DOTFILES_ROOT/.gitignore' ]"
run_test ".gitignore_global exists" "[ -f '$DOTFILES_ROOT/.gitignore_global' ]"

echo ""

# ============================================================================
# Test 7: Claude Code Configuration
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Claude Code Configuration ━━━${NC}"

run_test ".claude directory exists" "[ -d '$DOTFILES_ROOT/.claude' ]"
run_test ".claude/CLAUDE.md exists" "[ -f '$DOTFILES_ROOT/.claude/CLAUDE.md' ]"

echo ""

# ============================================================================
# Test 8: Nix Configuration (Optional)
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Nix Configuration ━━━${NC}"

run_test "nix directory exists" "[ -d '$DOTFILES_ROOT/nix' ]"

if [ -d "$DOTFILES_ROOT/nix" ]; then
    run_test "nix/global directory exists" "[ -d '$DOTFILES_ROOT/nix/global' ]"
    run_test "Nix documentation exists" "[ -f '$DOTFILES_ROOT/nix/README.md' ]"
else
    skip_test "Nix subdirectories" "nix directory not found"
fi

echo ""

# ============================================================================
# Test 9: macOS Specific (if applicable)
# ============================================================================
if [ "$OS" = "Darwin" ]; then
    echo -e "${BLUE}━━━ Test Group: macOS Configuration ━━━${NC}"

    run_test "Library directory exists" "[ -d '$DOTFILES_ROOT/Library' ]"

    if [ -d "$DOTFILES_ROOT/Library" ]; then
        run_test "Claude Desktop config directory exists" "[ -d '$DOTFILES_ROOT/Library/Application Support/Claude' ]"
    fi

    echo ""
fi

# ============================================================================
# Test 10: Docker Testing Infrastructure
# ============================================================================
echo -e "${BLUE}━━━ Test Group: Docker Testing Infrastructure ━━━${NC}"

run_test "Docker scripts directory exists" "[ -d '$DOTFILES_ROOT/scripts/docker' ]"

if [ -d "$DOTFILES_ROOT/scripts/docker" ]; then
    run_test "Docker README exists" "[ -f '$DOTFILES_ROOT/scripts/docker/README.md' ]"
    run_test "Dockerfiles directory exists" "[ -d '$DOTFILES_ROOT/scripts/docker/dockerfiles' ]"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Test Summary                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total Tests:   ${TESTS_RUN}"
echo -e "  ${GREEN}Passed:        ${TESTS_PASSED}${NC}"
echo -e "  ${RED}Failed:        ${TESTS_FAILED}${NC}"
echo -e "  ${YELLOW}Skipped:       ${TESTS_SKIPPED}${NC}"
echo ""

# Calculate pass rate
if [ $TESTS_RUN -gt 0 ]; then
    PASS_RATE=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
    echo -e "  Pass Rate:     ${PASS_RATE}%"
fi

echo ""

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
    log_error "Some tests failed!"
    exit 1
else
    log_success "All tests passed!"
    exit 0
fi
