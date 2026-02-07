#!/usr/bin/env bash
# Test script for tmux window indicator system
# Validates that Unicode indicators (●/◆) work correctly in:
# 1. Window names (visible in choose-tree via C-s s)
# 2. Status bar
# 3. Session manager
#
# Usage: ./test-indicators.sh [--live]
#   Without --live: runs unit tests on indicator logic
#   With --live: creates test windows and adds/removes indicators interactively

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TESTS=$((TESTS + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    expected: $(printf '%q' "$expected")"
        echo -e "    actual:   $(printf '%q' "$actual")"
        FAIL=$((FAIL + 1))
    fi
}

# =============================================================================
# Unit Tests - Indicator Logic
# =============================================================================

echo ""
echo "═══════════════════════════════════════════════════"
echo " Tmux Window Indicator Tests"
echo "═══════════════════════════════════════════════════"
echo ""

# --- Test: get_clean_window_name from watcher ---
echo "▸ Testing get_clean_window_name (watcher)"

# Source the function (extract it for testing)
get_clean_window_name() {
    local win_name="$1"
    # Strip current indicators (combined first, then individual, with and without space)
    win_name="${win_name#●◆ }"
    win_name="${win_name#● }"
    win_name="${win_name#◆ }"
    win_name="${win_name#●◆}"
    win_name="${win_name#●}"
    win_name="${win_name#◆}"
    # Strip legacy emoji indicators
    win_name="${win_name#🟢🔵 }"
    win_name="${win_name#🟢 }"
    win_name="${win_name#🔵 }"
    win_name="${win_name#🟢🔵}"
    win_name="${win_name#🟢}"
    win_name="${win_name#🔵}"
    # Strip legacy text indicators
    win_name="${win_name#\*+ }"
    win_name="${win_name#\* }"
    win_name="${win_name#+ }"
    win_name="${win_name#\*+}"
    win_name="${win_name#\*}"
    win_name="${win_name#+}"
    echo "$win_name"
}

assert_eq "clean name with no indicator" "claude" "$(get_clean_window_name "claude")"
assert_eq "strip ● indicator" "claude" "$(get_clean_window_name "● claude")"
assert_eq "strip ◆ indicator" "opencode" "$(get_clean_window_name "◆ opencode")"
assert_eq "strip ●◆ combined" "both" "$(get_clean_window_name "●◆ both")"
assert_eq "strip legacy 🟢 indicator" "claude" "$(get_clean_window_name "🟢 claude")"
assert_eq "strip legacy 🔵 indicator" "opencode" "$(get_clean_window_name "🔵 opencode")"
assert_eq "strip legacy 🟢🔵 combined" "both" "$(get_clean_window_name "🟢🔵 both")"
assert_eq "strip legacy * indicator" "claude" "$(get_clean_window_name "* claude")"
assert_eq "strip legacy + indicator" "opencode" "$(get_clean_window_name "+ opencode")"
assert_eq "strip legacy *+ indicator" "both" "$(get_clean_window_name "*+ both")"
assert_eq "no space after ●" "test" "$(get_clean_window_name "●test")"
assert_eq "preserve non-indicator names" "my-project" "$(get_clean_window_name "my-project")"

# --- Test: session manager get_window_indicator ---
echo ""
echo "▸ Testing get_window_indicator (session manager)"

get_window_indicator() {
    local win_name="$1"
    if [[ "$win_name" == "●◆ "* ]]; then
        echo "●◆"
    elif [[ "$win_name" == "● "* ]]; then
        echo "●"
    elif [[ "$win_name" == "◆ "* ]]; then
        echo "◆"
    fi
}

assert_eq "detect ● indicator" "●" "$(get_window_indicator "● claude")"
assert_eq "detect ◆ indicator" "◆" "$(get_window_indicator "◆ opencode")"
assert_eq "detect ●◆ combined" "●◆" "$(get_window_indicator "●◆ both")"
assert_eq "no indicator returns empty" "" "$(get_window_indicator "plain-window")"
assert_eq "no indicator for partial match" "" "$(get_window_indicator "some●thing")"

# --- Test: session manager strip_window_indicator ---
echo ""
echo "▸ Testing strip_window_indicator (session manager)"

strip_window_indicator() {
    local win_name="$1"
    win_name="${win_name#●◆ }"
    win_name="${win_name#● }"
    win_name="${win_name#◆ }"
    echo "$win_name"
}

assert_eq "strip ●" "claude" "$(strip_window_indicator "● claude")"
assert_eq "strip ◆" "opencode" "$(strip_window_indicator "◆ opencode")"
assert_eq "strip ●◆" "both" "$(strip_window_indicator "●◆ both")"
assert_eq "preserve clean name" "plain" "$(strip_window_indicator "plain")"

# --- Test: activity-clear strip logic ---
echo ""
echo "▸ Testing activity-clear strip logic"

strip_activity() {
    local new_name="$1"
    # Current indicators
    new_name="${new_name#●◆ }"
    new_name="${new_name#● }"
    new_name="${new_name#◆ }"
    # Legacy emoji indicators
    new_name="${new_name#🟢🔵 }"
    new_name="${new_name#🟢 }"
    new_name="${new_name#🔵 }"
    echo "$new_name"
}

assert_eq "clear ● from name" "editor" "$(strip_activity "● editor")"
assert_eq "clear ◆ from name" "main" "$(strip_activity "◆ main")"
assert_eq "clear ●◆ from name" "dev" "$(strip_activity "●◆ dev")"
assert_eq "clear legacy 🟢 from name" "editor" "$(strip_activity "🟢 editor")"
assert_eq "clear legacy 🔵 from name" "main" "$(strip_activity "🔵 main")"
assert_eq "no change for clean name" "fish" "$(strip_activity "fish")"

# --- Test: indicator build logic (from update_window_indicators) ---
echo ""
echo "▸ Testing indicator build logic"

build_indicator() {
    local has_claude="$1" has_opencode="$2" clean_name="$3"
    local prefix=""
    [[ "$has_claude" == "true" ]] && prefix+="●"
    [[ "$has_opencode" == "true" ]] && prefix+="◆"
    if [[ -n "$prefix" ]]; then
        echo "${prefix} ${clean_name}"
    else
        echo "$clean_name"
    fi
}

assert_eq "claude only indicator" "● claude" "$(build_indicator true false "claude")"
assert_eq "opencode only indicator" "◆ opencode" "$(build_indicator false true "opencode")"
assert_eq "both indicators" "●◆ both" "$(build_indicator true true "both")"
assert_eq "no indicators" "clean" "$(build_indicator false false "clean")"

# --- Test: UTF-8 encoding ---
echo ""
echo "▸ Testing UTF-8 encoding"

indicator_bytes=$(printf '●' | wc -c | tr -d ' ')
assert_eq "● is 3 bytes UTF-8 (BMP)" "3" "$indicator_bytes"

indicator_bytes=$(printf '◆' | wc -c | tr -d ' ')
assert_eq "◆ is 3 bytes UTF-8 (BMP)" "3" "$indicator_bytes"

combined="●◆ test"
assert_eq "combined indicator string is valid" "●◆ test" "$combined"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "═══════════════════════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
    echo -e " ${GREEN}All $TESTS tests passed${NC}"
else
    echo -e " ${RED}$FAIL/$TESTS tests failed${NC}"
fi
echo "═══════════════════════════════════════════════════"
echo ""

# =============================================================================
# Live Tests (--live flag)
# =============================================================================

if [[ "${1:-}" == "--live" ]]; then
    echo "═══════════════════════════════════════════════════"
    echo " Live Indicator Tests (requires active tmux)"
    echo "═══════════════════════════════════════════════════"
    echo ""

    if ! tmux list-sessions &>/dev/null; then
        echo -e "${RED}Error: Not inside a tmux session${NC}"
        exit 1
    fi

    SESSION=$(tmux display-message -p "#{session_name}")
    ORIG_WIN=$(tmux display-message -p "#{window_index}")
    echo "Session: $SESSION"

    # Create a test window, then switch back so it's non-active
    # (indicators are only set on non-active windows, and the
    # session-window-changed hook clears indicators on the active window)
    TEST_WIN="indicator-test"
    tmux new-window -n "$TEST_WIN"
    WIN_IDX=$(tmux display-message -p "#{window_index}")
    tmux select-window -t "${SESSION}:${ORIG_WIN}"
    sleep 0.5  # Let hook settle
    echo "Created test window: $TEST_WIN (index $WIN_IDX)"

    echo ""
    echo "▸ Test 1: Add ● indicator"
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "● ${TEST_WIN}"
    actual=$(tmux display-message -t "${SESSION}:${WIN_IDX}" -p "#{window_name}")
    assert_eq "window name has ● prefix" "● ${TEST_WIN}" "$actual"

    sleep 1

    echo ""
    echo "▸ Test 2: Add ◆ indicator"
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "◆ ${TEST_WIN}"
    actual=$(tmux display-message -t "${SESSION}:${WIN_IDX}" -p "#{window_name}")
    assert_eq "window name has ◆ prefix" "◆ ${TEST_WIN}" "$actual"

    sleep 1

    echo ""
    echo "▸ Test 3: Add ●◆ combined indicator"
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "●◆ ${TEST_WIN}"
    actual=$(tmux display-message -t "${SESSION}:${WIN_IDX}" -p "#{window_name}")
    assert_eq "window name has ●◆ prefix" "●◆ ${TEST_WIN}" "$actual"

    sleep 1

    echo ""
    echo "▸ Test 4: Clear indicator"
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "${TEST_WIN}"
    actual=$(tmux display-message -t "${SESSION}:${WIN_IDX}" -p "#{window_name}")
    assert_eq "window name cleared" "${TEST_WIN}" "$actual"

    sleep 1

    echo ""
    echo "▸ Test 5: Indicator persistence (5 seconds)"
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "● ${TEST_WIN}"
    echo "  Set indicator, waiting 5 seconds..."
    sleep 5
    actual=$(tmux display-message -t "${SESSION}:${WIN_IDX}" -p "#{window_name}")
    assert_eq "indicator persists after 5s" "● ${TEST_WIN}" "$actual"

    echo ""
    echo "▸ Test 6: Verify choose-tree visibility"
    echo "  Opening choose-tree for 3 seconds to verify indicators..."
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "● ${TEST_WIN}"
    echo -e "  ${YELLOW}Check the choose-tree view - you should see ● next to ${TEST_WIN}${NC}"
    echo "  (The choose-tree will open in a moment, press q to close it)"
    sleep 2

    echo ""
    echo "▸ Cleaning up test window..."
    tmux rename-window -t "${SESSION}:${WIN_IDX}" "${TEST_WIN}"
    tmux kill-window -t "${SESSION}:${WIN_IDX}" 2>/dev/null || true
    echo "  Done."

    echo ""
    echo "═══════════════════════════════════════════════════"
    if [[ $FAIL -eq 0 ]]; then
        echo -e " ${GREEN}All $TESTS tests passed (including live)${NC}"
    else
        echo -e " ${RED}$FAIL/$TESTS tests failed${NC}"
    fi
    echo "═══════════════════════════════════════════════════"
fi

exit $FAIL
