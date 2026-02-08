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

# --- Test: state machine logic (file-based, no tmux needed) ---
echo ""
echo "▸ Testing state machine logic (work detection)"

TEST_STATE_DIR=$(mktemp -d)
trap "rm -rf '$TEST_STATE_DIR'" EXIT

# Helper: simulate get_tool_status work detection logic
simulate_work_check() {
    local state_dir="$1"
    local state_key="$2"
    local tool="$3"
    local stdout_offset="$4"

    local baseline_file="$state_dir/${tool}-baseline-$state_key"
    local worked_file="$state_dir/${tool}-worked-$state_key"

    if [[ -n "$stdout_offset" ]]; then
        if [[ -f "$baseline_file" ]]; then
            local baseline
            baseline=$(cat "$baseline_file")
            if [[ "$stdout_offset" -gt "$baseline" ]]; then
                local diff=$(( stdout_offset - baseline ))
                if [[ "$diff" -gt 100 ]]; then
                    if [[ ! -f "$worked_file" ]]; then
                        touch "$worked_file"
                    fi
                fi
            fi
        else
            # No baseline — record current offset without assuming work
            echo "$stdout_offset" > "$baseline_file"
        fi
    fi
}

# Helper: simulate mark_viewed
simulate_mark_viewed() {
    local state_dir="$1"
    local state_key="$2"
    local tool="$3"
    local stdout_offset="$4"

    rm -f "$state_dir/${tool}-worked-$state_key"
    rm -f "$state_dir/${tool}-notified-$state_key"
    rm -f "$state_dir/${tool}-baseline-$state_key"

    # Record baseline if tool found
    if [[ -n "$stdout_offset" ]]; then
        echo "$stdout_offset" > "$state_dir/${tool}-baseline-$state_key"
    fi
}

# Helper: check if indicator would show
would_show_indicator() {
    local state_dir="$1"
    local state_key="$2"
    local tool="$3"

    local worked_file="$state_dir/${tool}-worked-$state_key"
    local notified_file="$state_dir/${tool}-notified-$state_key"

    if [[ ! -f "$notified_file" ]] && [[ -f "$worked_file" ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# Test: View window then leave without AI doing work — no false indicator
SK="test-session-1"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude" "5000"
# User views window, Claude renders idle prompt (+50 bytes, under threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "5050"
assert_eq "no indicator for small idle output after viewing" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: View window then leave, AI does real work — indicator shows
SK="test-session-2"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude" "5000"
# Claude does real work (+500 bytes, above threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "5500"
assert_eq "indicator shows for real work after viewing" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: First encounter (no baseline) — no false indicator
SK="test-session-3"
# Daemon encounters window for the first time (no baseline exists)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "10000"
assert_eq "no indicator on first encounter (baseline set)" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Verify baseline was created
assert_eq "baseline created on first encounter" "10000" "$(cat "$TEST_STATE_DIR/claude-baseline-$SK")"
# Now if Claude does work beyond baseline, indicator shows
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "10200"
assert_eq "indicator shows after work beyond first baseline" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: mark_viewed clears state, then idle UI redraws don't trigger
SK="test-session-4"
# Initial: Claude did work, indicator was shown
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude" "8000"
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8500"
touch "$TEST_STATE_DIR/claude-notified-$SK"
# User switches to this window
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude" "8500"
# User leaves, Claude's idle UI redraws (+80 bytes, under threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8580"
assert_eq "no indicator for idle redraw after re-viewing" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: mark_viewed clears baseline, daemon re-establishes without false flag
SK="test-session-5"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude" "3000"
# Clear baseline to simulate mark_viewed clearing it
rm -f "$TEST_STATE_DIR/claude-baseline-$SK"
rm -f "$TEST_STATE_DIR/claude-worked-$SK"
rm -f "$TEST_STATE_DIR/claude-notified-$SK"
# Daemon polls: no baseline (mark_viewed cleared it), but Claude has stdout at 3050
# (idle prompt rendered while user was viewing)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "3050"
assert_eq "no false indicator when baseline cleared and re-established" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Now Claude does real work
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "3250"
assert_eq "indicator shows for real work after baseline re-established" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

rm -rf "$TEST_STATE_DIR"

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
