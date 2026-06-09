#!/usr/bin/env bash
# Test Helper Library
# Shared utilities for comprehensive dotfiles validation

# Global test tracking
declare -g TOTAL_TESTS=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g TESTS_WARNED=0
declare -g TESTS_SKIPPED=0
declare -A TEST_RESULTS
declare -A TEST_TIMES

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test status symbols
SYMBOL_SUCCESS="✅"
SYMBOL_FAIL="❌"
SYMBOL_WARN="⚠️"
SYMBOL_SKIP="⏭️"
SYMBOL_INFO="ℹ️"

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_subheader() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

print_success() {
    echo -e "  ${GREEN}${SYMBOL_SUCCESS}${NC} $1"
}

print_error() {
    echo -e "  ${RED}${SYMBOL_FAIL}${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}${SYMBOL_WARN}${NC} $1"
}

print_skip() {
    echo -e "  ${MAGENTA}${SYMBOL_SKIP}${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}${SYMBOL_INFO}${NC} $1"
}

current_time_ms() {
    local value
    value=$(date +%s%3N 2>/dev/null || true)
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$value"
    else
        printf '%s000\n' "$(date +%s)"
    fi
}

# Test execution wrapper with timing
run_test() {
    local test_name="$1"
    local test_command="$2"
    local optional="${3:-false}"

    ((TOTAL_TESTS++)) || true

    local start_time
    local output
    local exit_code
    start_time=$(current_time_ms)

    # Execute test
    output=$(eval "$test_command" 2>&1)
    exit_code=$?

    local end_time
    end_time=$(current_time_ms)
    local duration=$((end_time - start_time))
    # shellcheck disable=SC2034
    TEST_TIMES["$test_name"]=$duration

    # Evaluate result
    if [[ $exit_code -eq 0 ]]; then
        print_success "$test_name (${duration}ms)"
        ((TESTS_PASSED++)) || true
        TEST_RESULTS["$test_name"]="pass"
        return 0
    else
        if [[ "$optional" == "true" ]]; then
            print_skip "$test_name (optional - ${duration}ms)"
            ((TESTS_SKIPPED++)) || true
            TEST_RESULTS["$test_name"]="skip"
            return 2
        else
            print_error "$test_name (${duration}ms)"
            if [[ -n "$output" ]]; then
                print_info "Error: $output" | head -3
            fi
            ((TESTS_FAILED++)) || true
            TEST_RESULTS["$test_name"]="fail"
            return 1
        fi
    fi
}

# Test with expected output
run_test_expect() {
    local test_name="$1"
    local test_command="$2"
    local expected="$3"
    local optional="${4:-false}"

    ((TOTAL_TESTS++)) || true

    local start_time
    local output
    local exit_code
    start_time=$(current_time_ms)

    output=$(eval "$test_command" 2>&1)
    exit_code=$?

    local end_time
    end_time=$(current_time_ms)
    local duration=$((end_time - start_time))
    # shellcheck disable=SC2034
    TEST_TIMES["$test_name"]=$duration

    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "$expected"; then
        print_success "$test_name (${duration}ms)"
        ((TESTS_PASSED++)) || true
        TEST_RESULTS["$test_name"]="pass"
        return 0
    else
        if [[ "$optional" == "true" ]]; then
            print_skip "$test_name (optional - ${duration}ms)"
            ((TESTS_SKIPPED++)) || true
            TEST_RESULTS["$test_name"]="skip"
            return 2
        else
            print_error "$test_name (${duration}ms)"
            print_info "Expected: $expected"
            print_info "Got: $output"
            ((TESTS_FAILED++)) || true
            TEST_RESULTS["$test_name"]="fail"
            return 1
        fi
    fi
}

# Test with warning instead of failure
run_test_warn() {
    local test_name="$1"
    local test_command="$2"

    ((TOTAL_TESTS++)) || true

    local start_time
    local output
    local exit_code
    start_time=$(current_time_ms)

    output=$(eval "$test_command" 2>&1)
    exit_code=$?

    local end_time
    end_time=$(current_time_ms)
    local duration=$((end_time - start_time))
    # shellcheck disable=SC2034
    TEST_TIMES["$test_name"]=$duration

    if [[ $exit_code -eq 0 ]]; then
        print_success "$test_name (${duration}ms)"
        ((TESTS_PASSED++)) || true
        TEST_RESULTS["$test_name"]="pass"
        return 0
    else
        print_warning "$test_name (${duration}ms)"
        if [[ -n "$output" ]]; then
            print_info "Warning: $output" | head -2
        fi
        ((TESTS_WARNED++)) || true
        # shellcheck disable=SC2034
        TEST_RESULTS["$test_name"]="warn"
        return 1
    fi
}

# Check if command exists
check_command() {
    command -v "$1" &>/dev/null
}

# Check if file exists
check_file() {
    [[ -f "$1" ]]
}

# Check if directory exists
check_dir() {
    [[ -d "$1" ]]
}

# Check if function exists in Fish
check_fish_function() {
    fish -c "functions $1" &>/dev/null
}

# Check if alias exists in Zsh
check_zsh_alias() {
    zsh -c "type $1" &>/dev/null
}

# Get OS type
get_os() {
    uname -s
}

# Check if running on macOS
is_macos() {
    [[ "$(get_os)" == "Darwin" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(get_os)" == "Linux" ]]
}

# Test clipboard functionality
test_clipboard() {
    local test_string
    test_string="validation-test-$$-$(date +%s)"

    # Try to copy
    if echo "$test_string" | fish -c "source ~/.config/fish/functions/clipboard_copy.fish; clipboard_copy" 2>/dev/null; then
        sleep 0.5

        # Try to paste
        local pasted=""
        if is_macos; then
            pasted=$(pbpaste 2>/dev/null || echo "")
        else
            if check_command xclip; then
                pasted=$(xclip -selection clipboard -o 2>/dev/null || echo "")
            elif check_command xsel; then
                pasted=$(xsel --clipboard --output 2>/dev/null || echo "")
            elif check_command wl-paste; then
                pasted=$(wl-paste 2>/dev/null || echo "")
            fi
        fi

        [[ "$pasted" == "$test_string" ]]
    else
        return 1
    fi
}

# Get Fish plugin count
count_fish_plugins() {
    if check_file "$HOME/.config/fish/fish_plugins"; then
        grep -cv '^[[:space:]]*$|^#' "$HOME/.config/fish/fish_plugins" | tr -d ' '
    else
        echo "0"
    fi
}

# Get tmux plugin count
count_tmux_plugins() {
    if check_file "$HOME/.tmux.conf"; then
        grep -c "set -g @plugin" "$HOME/.tmux.conf" | tr -d ' '
    else
        echo "0"
    fi
}

# Test Git operations in temp repo
with_test_git_repo() {
    local callback="$1"
    local test_repo="/tmp/dotfiles-test-repo-$$"

    # Create test repo
    mkdir -p "$test_repo"
    cd "$test_repo" || return 1
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "test" >README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Run callback
    eval "$callback"
    local result=$?

    # Cleanup
    cd - >/dev/null || true
    rm -rf "$test_repo"

    return $result
}

# Calculate percentage
calc_percentage() {
    local numerator=$1
    local denominator=$2

    if [[ $denominator -eq 0 ]]; then
        echo "0"
    else
        echo "scale=1; ($numerator * 100) / $denominator" | bc
    fi
}

# Print test summary
print_test_summary() {
    local category="$1"

    print_header "$category Test Summary"

    local pass_pct
    local fail_pct
    local warn_pct
    local skip_pct
    pass_pct=$(calc_percentage "$TESTS_PASSED" "$TOTAL_TESTS")
    fail_pct=$(calc_percentage "$TESTS_FAILED" "$TOTAL_TESTS")
    warn_pct=$(calc_percentage "$TESTS_WARNED" "$TOTAL_TESTS")
    skip_pct=$(calc_percentage "$TESTS_SKIPPED" "$TOTAL_TESTS")

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED / $TOTAL_TESTS (${pass_pct}%)"
    echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED / $TOTAL_TESTS (${fail_pct}%)"
    echo -e "  ${YELLOW}Warned:${NC}  $TESTS_WARNED / $TOTAL_TESTS (${warn_pct}%)"
    echo -e "  ${MAGENTA}Skipped:${NC} $TESTS_SKIPPED / $TOTAL_TESTS (${skip_pct}%)"
    echo ""

    # Overall status
    if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -eq 0 ]]; then
        echo -e "${GREEN}${SYMBOL_SUCCESS} ALL TESTS PASSED!${NC}"
        return 0
    elif [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 2 ]]; then
        echo -e "${YELLOW}${SYMBOL_WARN} Tests passed with minor warnings${NC}"
        return 0
    elif [[ $TESTS_FAILED -le 2 ]]; then
        echo -e "${YELLOW}${SYMBOL_WARN} Core functionality works, minor failures${NC}"
        return 1
    else
        echo -e "${RED}${SYMBOL_FAIL} Multiple test failures detected${NC}"
        return 1
    fi
}

# Reset test counters (for module boundaries)
reset_test_counters() {
    TOTAL_TESTS=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_WARNED=0
    TESTS_SKIPPED=0
}

# Get performance metrics
get_shell_startup_time() {
    local shell="$1"
    local total=0
    local iterations=5

    for ((i = 1; i <= iterations; i++)); do
        local start
        start=$(current_time_ms)
        if [[ "$shell" == "fish" ]]; then
            fish -c "exit" 2>/dev/null
        else
            zsh -c "exit" 2>/dev/null
        fi
        local end
        end=$(current_time_ms)
        local duration=$((end - start))
        total=$((total + duration))
    done

    echo "$((total / iterations))"
}

# Cleanup function
cleanup_test_artifacts() {
    rm -f /tmp/zsh-test.log 2>/dev/null
    rm -f /tmp/fish-test.log 2>/dev/null
    rm -f /tmp/clipboard-error.log 2>/dev/null
    rm -f /tmp/tmux-error.log 2>/dev/null
    rm -f /tmp/setup-dryrun.log 2>/dev/null
    rm -rf /tmp/dotfiles-test-repo-* 2>/dev/null
}

# Export all functions
export -f print_header print_subheader
export -f print_success print_error print_warning print_skip print_info current_time_ms
export -f run_test run_test_expect run_test_warn
export -f check_command check_file check_dir
export -f check_fish_function check_zsh_alias
export -f get_os is_macos is_linux
export -f test_clipboard
export -f count_fish_plugins count_tmux_plugins
export -f with_test_git_repo
export -f calc_percentage print_test_summary
export -f reset_test_counters
export -f get_shell_startup_time
export -f cleanup_test_artifacts
