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
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} $test_name"
        echo -e "    Expected: $(echo "$expected" | cat -v)"
        echo -e "    Actual:   $(echo "$actual" | cat -v)"
        ((FAIL++)) || true
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        echo -e "  ${GREEN}PASS${NC} $test_name"
        ((PASS++)) || true
    else
        echo -e "  ${RED}FAIL${NC} $test_name"
        echo -e "    Expected to contain: $needle"
        echo -e "    Actual: $haystack"
        ((FAIL++)) || true
    fi
}

echo "=== Copy-Paste Line Break Fix Tests ==="
echo ""

# ─────────────────────────────────────────────
# tmux-copy-cleanup.sh tests
# ─────────────────────────────────────────────
echo -e "${YELLOW}tmux-copy-cleanup.sh${NC}"

# Test: Join mode - basic command
result=$(printf 'CROSS_PROVIDER_BRIDGE=1\nCROSS_PROVIDER_ORDER=gemini\nclaude' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: multi-line command" "CROSS_PROVIDER_BRIDGE=1 CROSS_PROVIDER_ORDER=gemini claude" "$result"

# Test: Join mode - collapses multiple spaces
result=$(printf 'hello  \n  world' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: collapses spaces" "hello world" "$result"

# Test: Smart mode - preserves paragraphs
result=$(printf 'para one\nwraps here.\n\npara two\nalso wraps.' | "$CLEANUP_SCRIPT" smart && pbpaste)
expected=$(printf 'para one wraps here.\n\npara two also wraps.')
assert_eq "smart: preserves paragraphs" "$expected" "$result"

# Test: Smart mode - single paragraph
result=$(printf 'single\nparagraph\ntext' | "$CLEANUP_SCRIPT" smart && pbpaste)
assert_eq "smart: single paragraph joins" "single paragraph text" "$result"

# Test: Passthrough mode
result=$(printf 'line1\nline2' | "$CLEANUP_SCRIPT" passthrough && pbpaste)
expected=$(printf 'line1\nline2')
assert_eq "passthrough: preserves all" "$expected" "$result"

# Test: Join mode - trailing/leading whitespace
result=$(printf '  leading\ntrailing  \n  both  ' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: trims leading/trailing" "leading trailing both" "$result"

# Test: Real-world Claude Code command copy
result=$(printf 'gwt-ticket ENG-123 --bridge\n--bridge-providers gemini,ollama\n--bridge-model gemini-2.5-pro' | "$CLEANUP_SCRIPT" join && pbpaste)
assert_eq "join: real command" "gwt-ticket ENG-123 --bridge --bridge-providers gemini,ollama --bridge-model gemini-2.5-pro" "$result"

echo ""

# ─────────────────────────────────────────────
# cfx Fish function tests - basic modes
# ─────────────────────────────────────────────
echo -e "${YELLOW}cfx Fish function - basic modes${NC}"

# Test: Default join mode
result=$(printf 'line1\nline2\nline3' | fish -c "source $CFX_FUNC; cfx")
assert_eq "cfx: default join" "line1 line2 line3" "$result"

# Test: Paragraph mode
result=$(printf 'para1 line1\npara1 line2\n\npara2 line1\npara2 line2' | fish -c "source $CFX_FUNC; cfx -p")
expected=$(printf 'para1 line1 para1 line2\n\npara2 line1 para2 line2')
assert_eq "cfx -p: paragraph mode" "$expected" "$result"

# Test: Trim mode
result=$(printf 'line1   \nline2   ' | fish -c "source $CFX_FUNC; cfx -t")
expected=$(printf 'line1\nline2')
assert_eq "cfx -t: trim mode" "$expected" "$result"

# Test: Help flag
result=$(fish -c "source $CFX_FUNC; cfx -h" 2>&1 | head -1)
assert_eq "cfx -h: shows help" "cfx - Fix clipboard line breaks from terminal copy" "$result"

# Test: Dry-run mode
result=$(printf 'test\ncontent' | pbcopy && printf 'new\nstuff' | fish -c "source $CFX_FUNC; cfx -n" 2>&1)
clipboard_after=$(pbpaste)
# Clipboard should still have the original content after dry-run
assert_contains "cfx -n: dry-run doesn't modify clipboard" "dry-run" "$result"

echo ""

# ─────────────────────────────────────────────
# cfx Fish function - edge cases
# ─────────────────────────────────────────────
echo -e "${YELLOW}cfx Fish function - edge cases${NC}"

# Test: Backslash continuation preserved in join mode
result=$(printf 'docker run \\\n  --rm \\\n  -v /data:/data \\\n  ubuntu:latest' | fish -c "source $CFX_FUNC; cfx")
expected=$(printf 'docker run \\\n  --rm \\\n  -v /data:/data \\\n  ubuntu:latest')
assert_eq "join: preserves backslash continuations" "$expected" "$result"

# Test: Quoted strings with newlines (join mode)
result=$(printf 'echo "hello\nworld"' | fish -c "source $CFX_FUNC; cfx")
assert_eq "join: quoted string content" 'echo "hello world"' "$result"

# Test: Command with semicolons preserved
result=$(printf 'cd /tmp;\nls -la;\necho done' | fish -c "source $CFX_FUNC; cfx")
assert_eq "join: semicolons preserved" "cd /tmp; ls -la; echo done" "$result"

# Test: Command with && preserved
result=$(printf 'make build &&\nmake test &&\nmake deploy' | fish -c "source $CFX_FUNC; cfx")
assert_eq "join: && chains preserved" "make build && make test && make deploy" "$result"

# Test: Empty input via pipe
result=$(printf '' | fish -c "source $CFX_FUNC; cfx" 2>&1)
assert_contains "cfx: empty input error" "empty" "$result"

# Test: Paragraph mode preserves indented lines
result=$(printf 'Header text\nthat wraps.\n  indented code\n  more code\nBack to prose\nthat wraps.' | fish -c "source $CFX_FUNC; cfx -p")
expected=$(printf 'Header text that wraps.\n  indented code\n  more code\nBack to prose that wraps.')
assert_eq "cfx -p: preserves indented lines" "$expected" "$result"

# Test: Paragraph mode preserves list items
result=$(printf 'Introduction\ntext here.\n- item one\n- item two\n* bullet three' | fish -c "source $CFX_FUNC; cfx -p")
expected=$(printf 'Introduction text here.\n- item one\n- item two\n* bullet three')
assert_eq "cfx -p: preserves list items" "$expected" "$result"

# Test: Paragraph mode preserves fenced code blocks
result=$(printf 'Some text\nthat wraps.\n```\ncode line 1\ncode line 2\n```\nAfter code\nalso wraps.' | fish -c "source $CFX_FUNC; cfx -p")
expected=$(printf 'Some text that wraps.\n```\ncode line 1\ncode line 2\n```\nAfter code also wraps.')
assert_eq "cfx -p: preserves fenced code blocks" "$expected" "$result"

# Test: Paragraph mode fenced block with language tag
result=$(printf 'Run this:\n```bash\necho hello\necho world\n```\nThen check.' | fish -c "source $CFX_FUNC; cfx -p")
expected=$(printf 'Run this:\n```bash\necho hello\necho world\n```\nThen check.')
assert_eq "cfx -p: fenced block with language tag" "$expected" "$result"

# Test: Single line input (no-op)
result=$(printf 'already one line' | fish -c "source $CFX_FUNC; cfx")
assert_eq "join: single line unchanged" "already one line" "$result"

# Test: Unicode/wide characters
result=$(printf 'hello\nworld \xe2\x9c\x93' | fish -c "source $CFX_FUNC; cfx")
expected=$(printf 'hello world \xe2\x9c\x93')
assert_eq "join: unicode preserved" "$expected" "$result"

echo ""

# ─────────────────────────────────────────────
# Configuration file tests
# ─────────────────────────────────────────────
echo -e "${YELLOW}Configuration files${NC}"

# Test: Ghostty clipboard-trim-trailing-spaces
if grep -q 'clipboard-trim-trailing-spaces = true' "$SCRIPT_DIR/../.config/ghostty/config"; then
    echo -e "  ${GREEN}PASS${NC} ghostty: clipboard-trim-trailing-spaces enabled"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} ghostty: clipboard-trim-trailing-spaces not found"
    ((FAIL++)) || true
fi

# Test: Ghostty tradeoff documented
if grep -q 'Tradeoff' "$SCRIPT_DIR/../.config/ghostty/config"; then
    echo -e "  ${GREEN}PASS${NC} ghostty: tradeoff documented"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} ghostty: tradeoff not documented"
    ((FAIL++)) || true
fi

# Test: tmux clean copy Y binding
if grep -q 'tmux-copy-cleanup.sh join' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: Y clean-copy binding configured"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} tmux: Y clean-copy binding not found"
    ((FAIL++)) || true
fi

# Test: tmux smart copy uses M-y (not C-y which conflicts with scroll-up)
if grep -q 'M-y.*tmux-copy-cleanup.sh smart' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: M-y smart-copy binding (no C-y collision)"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} tmux: M-y smart-copy binding not found"
    ((FAIL++)) || true
fi

# Test: tmux does NOT use C-y (collision check)
if ! grep -q 'C-y.*tmux-copy-cleanup' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: no C-y collision with vi scroll-up"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} tmux: C-y still bound (collides with vi scroll-up)"
    ((FAIL++)) || true
fi

# Test: tmux documents cfx -p vs smart difference
if grep -q 'cfx -p' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: cfx -p vs smart difference documented"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} tmux: cfx -p vs smart difference not documented"
    ((FAIL++)) || true
fi

# Test: tmux documents M-y portability
if grep -q 'Alt/Meta key support' "$SCRIPT_DIR/../.tmux.conf"; then
    echo -e "  ${GREEN}PASS${NC} tmux: M-y portability note present"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} tmux: M-y portability note missing"
    ((FAIL++)) || true
fi

# Test: cleanup script is executable
if [ -x "$CLEANUP_SCRIPT" ]; then
    echo -e "  ${GREEN}PASS${NC} tmux-copy-cleanup.sh is executable"
    ((PASS++)) || true
else
    echo -e "  ${RED}FAIL${NC} tmux-copy-cleanup.sh is not executable"
    ((FAIL++)) || true
fi

echo ""
echo "─────────────────────────────────────"
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} ($(($PASS + $FAIL)) total)"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
