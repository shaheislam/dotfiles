#!/usr/bin/env bash
# test-copypaste.sh - Tests for copy-paste line break fixes
# Tests cfx Fish function and tmux-copy-cleanup.sh script

set -uo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/tmux/tmux-copy-cleanup.sh"
CFX_FUNC="$SCRIPT_DIR/../.config/fish/functions/cfx.fish"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}PASS${NC} $test_name"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} $test_name"
        echo -e "    Expected: $(echo "$expected" | cat -v)"
        echo -e "    Actual:   $(echo "$actual" | cat -v)"
        ((FAIL++))
    fi
}

echo "=== Copy-Paste Line Break Fix Tests ==="
echo ""

# ─────────────────────────────────────────────
# tmux-copy-cleanup.sh tests
# ─────────────────────────────────────────────
echo -e "${YELLOW}tmux-copy-cleanup.sh${NC}"

# Test 1: Join mode - basic command
result=$(printf 'CROSS_PROVIDER_BRIDGE=1\nCROSS_PROVIDER_ORDER=gemini\nclaude' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: multi-line command" "CROSS_PROVIDER_BRIDGE=1 CROSS_PROVIDER_ORDER=gemini claude" "$result"

# Test 2: Join mode - collapses multiple spaces
result=$(printf 'hello  \n  world' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: collapses spaces" "hello world" "$result"

# Test 3: Smart mode - preserves paragraphs
result=$(printf 'para one\nwraps here.\n\npara two\nalso wraps.' | "$CLEANUP_SCRIPT" smart && pbpaste)
expected=$(printf 'para one wraps here.\n\npara two also wraps.')
assert_eq "smart: preserves paragraphs" "$expected" "$result"

# Test 4: Smart mode - single paragraph
result=$(printf 'single\nparagraph\ntext' | "$CLEANUP_SCRIPT" smart && pbpaste)
assert_eq "smart: single paragraph joins" "single paragraph text" "$result"

# Test 5: Passthrough mode
result=$(printf 'line1\nline2' | "$CLEANUP_SCRIPT" passthrough && pbpaste)
expected=$(printf 'line1\nline2')
assert_eq "passthrough: preserves all" "$expected" "$result"

# Test 6: Join mode - trailing/leading whitespace
result=$(printf '  leading\ntrailing  \n  both  ' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: trims leading/trailing" "leading trailing both" "$result"

# Test 7: Real-world Claude Code command copy
result=$(printf 'gwt-ticket ENG-123 --bridge\n--bridge-providers gemini,ollama\n--bridge-model gemini-2.5-pro' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: real command" "gwt-ticket ENG-123 --bridge --bridge-providers gemini,ollama --bridge-model gemini-2.5-pro" "$result"

echo ""

# ─────────────────────────────────────────────
# cfx Fish function tests
# ─────────────────────────────────────────────
echo -e "${YELLOW}cfx Fish function${NC}"

# Test 8: Default join mode
result=$(printf 'line1\nline2\nline3' | fish -c "source $CFX_FUNC; cfx")
assert_eq "cfx: default join" "line1 line2 line3" "$result"

# Test 9: Paragraph mode
result=$(printf 'para1 line1\npara1 line2\n\npara2 line1\npara2 line2' | fish -c "source $CFX_FUNC; cfx -p")
expected=$(printf 'para1 line1 para1 line2\n\npara2 line1 para2 line2')
assert_eq "cfx -p: paragraph mode" "$expected" "$result"

# Test 10: Trim mode
result=$(printf 'line1   \nline2   ' | fish -c "source $CFX_FUNC; cfx -t")
expected=$(printf 'line1\nline2')
assert_eq "cfx -t: trim mode" "$expected" "$result"

# Test 11: Help flag
result=$(fish -c "source $CFX_FUNC; cfx -h" 2>&1 | head -1)
assert_eq "cfx -h: shows help" "cfx - Fix clipboard line breaks from terminal copy" "$result"

echo ""

# ─────────────────────────────────────────────
# Config file tests
# ─────────────────────────────────────────────
echo -e "${YELLOW}Configuration files${NC}"

# Test 12: Ghostty clipboard-trim-trailing-spaces
if grep -q 'clipboard-trim-trailing-spaces = true' "$SCRIPT_DIR/../.config/ghostty/config"; then
    echo -e "  ${GREEN}PASS${NC} ghostty: clipboard-trim-trailing-spaces enabled"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} ghostty: clipboard-trim-trailing-spaces not found"
    ((FAIL++))
fi

# Test 13: tmux clean copy Y binding
if grep -q 'tmux-copy-cleanup.sh join' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: Y clean-copy binding configured"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} tmux: Y clean-copy binding not found"
    ((FAIL++))
fi

# Test 14: tmux smart copy Ctrl-y binding
if grep -q 'tmux-copy-cleanup.sh smart' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: Ctrl-y smart-copy binding configured"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} tmux: Ctrl-y smart-copy binding not found"
    ((FAIL++))
fi

# Test 15: cleanup script is executable
if [ -x "$CLEANUP_SCRIPT" ]; then
    echo -e "  ${GREEN}PASS${NC} tmux-copy-cleanup.sh is executable"
    ((PASS++))
else
    echo -e "  ${RED}FAIL${NC} tmux-copy-cleanup.sh is not executable"
    ((FAIL++))
fi

echo ""
echo "─────────────────────────────────────"
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} ($(($PASS + $FAIL)) total)"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
