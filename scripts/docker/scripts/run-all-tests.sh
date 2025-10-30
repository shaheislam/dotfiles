#!/usr/bin/env bash
# Main Test Orchestrator for Dotfiles Testing
# Runs all test suites and reports results

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/dotfiles-test-results}"
DISTRO="${TEST_DISTRO:-$(cat /etc/os-release | grep ^ID= | cut -d= -f2 | tr -d '"')}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$TEST_RESULTS_DIR/${DISTRO}_${TIMESTAMP}.log"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

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

log_test() {
    echo -e "${CYAN}🧪 $1${NC}"
}

# Initialize results directory
init_results() {
    mkdir -p "$TEST_RESULTS_DIR"
    touch "$RESULTS_FILE"

    log_info "Test results will be saved to: $RESULTS_FILE"
    echo "Distribution: $DISTRO" >> "$RESULTS_FILE"
    echo "Timestamp: $TIMESTAMP" >> "$RESULTS_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
}

# Run a test script and record results
run_test() {
    local test_name="$1"
    local test_script="$2"
    local required="${3:-true}"

    TESTS_RUN=$((TESTS_RUN + 1))

    log_test "Running: $test_name"
    echo "Test: $test_name" >> "$RESULTS_FILE"

    if [ ! -f "$test_script" ]; then
        if [ "$required" = "true" ]; then
            log_error "Test script not found: $test_script"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo "Result: FAILED (script not found)" >> "$RESULTS_FILE"
        else
            log_warning "Optional test script not found: $test_script"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            echo "Result: SKIPPED (optional)" >> "$RESULTS_FILE"
        fi
        echo "" >> "$RESULTS_FILE"
        return
    fi

    if bash "$test_script" >> "$RESULTS_FILE" 2>&1; then
        log_success "$test_name passed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo "Result: PASSED ✅" >> "$RESULTS_FILE"
    else
        log_error "$test_name failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "Result: FAILED ❌" >> "$RESULTS_FILE"
    fi

    echo "" >> "$RESULTS_FILE"
}

# Run all tests
run_all_tests() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Starting Dotfiles Test Suite"
    log_info "Distribution: $DISTRO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Core tests (required)
    run_test "Package Manager Detection" "$SCRIPT_DIR/test-packages.sh" "true"
    run_test "GNU Stow Operations" "$SCRIPT_DIR/test-stow.sh" "true"

    # Shell configuration tests
    run_test "Fish Shell Configuration" "$SCRIPT_DIR/test-fish.sh" "false"
    run_test "Zsh Shell Configuration" "$SCRIPT_DIR/test-zsh.sh" "false"

    # CLI tools tests
    run_test "CLI Tools Configuration" "$SCRIPT_DIR/test-cli-tools.sh" "false"

    # Git configuration test
    run_test "Git Configuration" "$SCRIPT_DIR/test-git.sh" "false"

    # Tmux configuration test
    run_test "Tmux Configuration" "$SCRIPT_DIR/test-tmux.sh" "false"
}

# Generate test summary
generate_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Test Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo ""
    echo "Total Tests Run:    $TESTS_RUN"
    echo -e "${GREEN}Tests Passed:       $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed:       $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Tests Skipped:      $TESTS_SKIPPED${NC}"

    local pass_rate=0
    if [ "$TESTS_RUN" -gt 0 ]; then
        pass_rate=$(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_RUN" | bc)
    fi

    echo ""
    echo "Pass Rate:          ${pass_rate}%"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Append summary to results file
    echo "" >> "$RESULTS_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$RESULTS_FILE"
    echo "SUMMARY" >> "$RESULTS_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$RESULTS_FILE"
    echo "Total:   $TESTS_RUN" >> "$RESULTS_FILE"
    echo "Passed:  $TESTS_PASSED" >> "$RESULTS_FILE"
    echo "Failed:  $TESTS_FAILED" >> "$RESULTS_FILE"
    echo "Skipped: $TESTS_SKIPPED" >> "$RESULTS_FILE"
    echo "Rate:    ${pass_rate}%" >> "$RESULTS_FILE"

    # Exit with appropriate code
    if [ "$TESTS_FAILED" -eq 0 ]; then
        log_success "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Main function
main() {
    init_results
    run_all_tests
    generate_summary
}

# Run main function
main "$@"
