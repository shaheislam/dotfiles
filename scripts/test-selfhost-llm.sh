#!/usr/bin/env bash

# test-selfhost-llm.sh - Smoke tests for self-hosted LLM setup
#
# Validates that the self-hosted LLM infrastructure is correctly configured.
# Does NOT require models to be downloaded or Ollama to be running.
# Tests configuration, file structure, and Fish function availability.
#
# Usage:
#   ./scripts/test-selfhost-llm.sh           # Run all tests
#   ./scripts/test-selfhost-llm.sh --live     # Include live Ollama tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0
SKIPPED=0
LIVE_TESTS=false

[[ "${1:-}" == "--live" ]] && LIVE_TESTS=true

# ============================================================================
# Test Helpers
# ============================================================================

pass() {
    echo -e "\033[0;32m  PASS\033[0m $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "\033[0;31m  FAIL\033[0m $1"
    FAILED=$((FAILED + 1))
}

skip() {
    echo -e "\033[1;33m  SKIP\033[0m $1"
    SKIPPED=$((SKIPPED + 1))
}

# ============================================================================
# Configuration Tests
# ============================================================================

echo "=== Self-Hosted LLM Configuration Tests ==="
echo ""

# Test: Setup script exists and is executable
echo "--- Setup Script ---"
if [[ -f "$DOTFILES_ROOT/scripts/setup-selfhost-llm.sh" ]]; then
    pass "Setup script exists"
else
    fail "Setup script missing: scripts/setup-selfhost-llm.sh"
fi

if [[ -x "$DOTFILES_ROOT/scripts/setup-selfhost-llm.sh" ]]; then
    pass "Setup script is executable"
else
    fail "Setup script is not executable"
fi

# Test: Setup script has valid bash syntax
if bash -n "$DOTFILES_ROOT/scripts/setup-selfhost-llm.sh" 2>/dev/null; then
    pass "Setup script syntax is valid"
else
    fail "Setup script has syntax errors"
fi

# Test: Brewfile has Ollama entry
echo ""
echo "--- Brewfile ---"
if grep -q 'cask "ollama"' "$DOTFILES_ROOT/homebrew/Brewfile"; then
    pass "Ollama is in Brewfile"
else
    fail "Ollama missing from Brewfile"
fi

# ============================================================================
# Fish Function Tests
# ============================================================================

echo ""
echo "--- Fish Functions ---"

FISH_FUNCTIONS=(
    "llm"
    "llm-code"
    "llm-chat"
    "llm-status"
    "llm-pull"
    "llm-web"
)

for func in "${FISH_FUNCTIONS[@]}"; do
    func_file="$DOTFILES_ROOT/.config/fish/functions/${func}.fish"
    if [[ -f "$func_file" ]]; then
        pass "Fish function exists: $func"
    else
        fail "Fish function missing: $func ($func_file)"
    fi
done

# Test: Fish functions have --help support
for func in "${FISH_FUNCTIONS[@]}"; do
    func_file="$DOTFILES_ROOT/.config/fish/functions/${func}.fish"
    if [[ -f "$func_file" ]] && grep -qF -- "--help" "$func_file"; then
        pass "Fish function has --help: $func"
    else
        fail "Fish function missing --help: $func"
    fi
done

# Test: Fish functions have description
for func in "${FISH_FUNCTIONS[@]}"; do
    func_file="$DOTFILES_ROOT/.config/fish/functions/${func}.fish"
    if [[ -f "$func_file" ]] && grep -qF -- "--description" "$func_file"; then
        pass "Fish function has description: $func"
    else
        fail "Fish function missing description: $func"
    fi
done

# ============================================================================
# Live Tests (optional - requires Ollama running)
# ============================================================================

if [[ "$LIVE_TESTS" == "true" ]]; then
    echo ""
    echo "--- Live Ollama Tests ---"

    # Test: Ollama binary exists
    if command -v ollama &>/dev/null; then
        pass "Ollama binary is installed"
    else
        fail "Ollama binary not found in PATH"
    fi

    # Test: Ollama server is reachable
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        pass "Ollama server is running"

        # Test: At least one model is installed
        model_count=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
        if [[ "$model_count" -gt 0 ]]; then
            pass "Models installed: $model_count"
        else
            fail "No models installed (run: llm-pull llama3.1:8b)"
        fi

        # Test: API responds correctly
        response=$(curl -sf http://localhost:11434/api/tags 2>/dev/null)
        if echo "$response" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
            pass "Ollama API returns valid JSON"
        else
            fail "Ollama API response is not valid JSON"
        fi
    else
        skip "Ollama server not running (start with: ollama serve)"
    fi

    # Test: Open WebUI
    webui_port="${OPEN_WEBUI_PORT:-8080}"
    if command -v open-webui &>/dev/null; then
        pass "Open WebUI is installed"
    else
        skip "Open WebUI not installed (install with: pipx install open-webui)"
    fi
else
    echo ""
    echo "--- Live Tests ---"
    skip "Live tests skipped (use --live to enable)"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=== Results ==="
echo -e "  \033[0;32mPassed: $PASSED\033[0m"
echo -e "  \033[0;31mFailed: $FAILED\033[0m"
echo -e "  \033[1;33mSkipped: $SKIPPED\033[0m"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo "Some tests failed. Check the output above."
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
