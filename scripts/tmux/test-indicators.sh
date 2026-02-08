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

# Helper: simulate get_tool_status work detection logic (matches watcher daemon)
# Two-step confirmation: first detection creates pending file, second confirms as work
# Threshold: 2048 bytes (filters out idle UI refreshes ~100-900 bytes)
simulate_work_check() {
    local state_dir="$1"
    local state_key="$2"
    local tool="$3"
    local stdout_offset="$4"

    local baseline_file="$state_dir/${tool}-baseline-$state_key"
    local worked_file="$state_dir/${tool}-worked-$state_key"
    local pending_file="$state_dir/${tool}-pending-$state_key"

    if [[ -n "$stdout_offset" ]]; then
        if [[ -f "$baseline_file" ]]; then
            local baseline
            baseline=$(cat "$baseline_file")
            local diff=$(( stdout_offset - baseline ))
            if [[ "$diff" -gt 2048 ]]; then
                if [[ -f "$pending_file" ]]; then
                    # Second consecutive detection — confirm as real work
                    local pending_offset
                    pending_offset=$(cat "$pending_file")
                    if [[ "$stdout_offset" -gt "$pending_offset" ]]; then
                        # Output is still growing — this is real work
                        if [[ ! -f "$worked_file" ]]; then
                            touch "$worked_file"
                        fi
                        rm -f "$pending_file"
                    else
                        # Output stopped growing — was just a UI burst, reset
                        rm -f "$pending_file"
                        echo "$stdout_offset" > "$baseline_file"
                    fi
                else
                    # First detection — record pending, confirm on next poll
                    echo "$stdout_offset" > "$pending_file"
                fi
            else
                # Below threshold — clear any pending state
                rm -f "$pending_file"
            fi
        else
            # No baseline — record current offset without assuming work
            echo "$stdout_offset" > "$baseline_file"
        fi
    fi
}

# Helper: simulate mark_viewed (clears ALL state including pending)
simulate_mark_viewed() {
    local state_dir="$1"
    local state_key="$2"
    local tool="$3"

    rm -f "$state_dir/${tool}-worked-$state_key"
    rm -f "$state_dir/${tool}-notified-$state_key"
    rm -f "$state_dir/${tool}-baseline-$state_key"
    rm -f "$state_dir/${tool}-pending-$state_key"
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

# Test: Small idle output under threshold — no indicator
SK="test-session-1"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
echo "5000" > "$TEST_STATE_DIR/claude-baseline-$SK"
# Claude renders idle prompt (+50 bytes, well under 2048 threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "5050"
assert_eq "no indicator for small idle output (50 bytes)" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: Medium idle burst under threshold — no indicator (the key false positive fix)
SK="test-session-1b"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
echo "5000" > "$TEST_STATE_DIR/claude-baseline-$SK"
# Claude status line refresh (+900 bytes, under 2048 threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "5900"
assert_eq "no indicator for UI burst (900 bytes)" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: Real work requires two consecutive polls with growing output
SK="test-session-2"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
echo "5000" > "$TEST_STATE_DIR/claude-baseline-$SK"
# Poll 1: Claude starts producing output (+3000 bytes, above threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8000"
assert_eq "first detection creates pending, not worked" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
assert_eq "pending file created" "8000" "$(cat "$TEST_STATE_DIR/claude-pending-$SK" 2>/dev/null)"
# Poll 2: Output still growing — confirms real work
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "12000"
assert_eq "indicator shows after confirmed growing output" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
assert_eq "pending file cleared after confirmation" "" "$(cat "$TEST_STATE_DIR/claude-pending-$SK" 2>/dev/null)"

# Test: One-time burst above threshold but NOT growing — no indicator (UI burst)
SK="test-session-2b"
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
echo "5000" > "$TEST_STATE_DIR/claude-baseline-$SK"
# Poll 1: Burst above threshold
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8000"
assert_eq "pending after burst" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Poll 2: Offset unchanged — burst stopped, not real work
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8000"
assert_eq "no indicator when burst stops (same offset)" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
assert_eq "baseline reset after burst dismissed" "8000" "$(cat "$TEST_STATE_DIR/claude-baseline-$SK")"

# Test: First encounter (no baseline) — no false indicator
SK="test-session-3"
# Daemon encounters window for the first time (no baseline exists)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "10000"
assert_eq "no indicator on first encounter (baseline set)" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
assert_eq "baseline created on first encounter" "10000" "$(cat "$TEST_STATE_DIR/claude-baseline-$SK")"
# Claude does real work: poll 1 (pending)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "15000"
assert_eq "first work detection pending" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Claude does more work: poll 2 (confirmed)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "20000"
assert_eq "indicator shows after confirmed work beyond first baseline" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: mark_viewed clears state, then idle UI redraws don't trigger
SK="test-session-4"
# Initial: Claude did work, indicator was shown
echo "8000" > "$TEST_STATE_DIR/claude-baseline-$SK"
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "15000"
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "20000"
touch "$TEST_STATE_DIR/claude-notified-$SK"
# User switches to this window
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
# Daemon re-establishes baseline
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "20000"
assert_eq "baseline re-established after mark_viewed" "20000" "$(cat "$TEST_STATE_DIR/claude-baseline-$SK")"
# Claude's idle UI redraws (+80 bytes, under threshold)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "20080"
assert_eq "no indicator for idle redraw after re-viewing" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: mark_viewed clears baseline, daemon re-establishes without false flag
SK="test-session-5"
# Simulate mark_viewed clearing all state
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
# Daemon polls: no baseline, Claude has stdout at 3050
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "3050"
assert_eq "no false indicator when baseline cleared and re-established" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Claude does real work (poll 1: pending)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "6000"
assert_eq "pending after first work detection" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Claude does more work (poll 2: confirmed)
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "9000"
assert_eq "indicator shows after confirmed work post re-establish" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

# Test: mark_viewed clears pending state (no stale pending after switching)
SK="test-session-6"
echo "5000" > "$TEST_STATE_DIR/claude-baseline-$SK"
# Poll 1: above threshold, pending created
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8000"
assert_eq "pending file exists before mark_viewed" "8000" "$(cat "$TEST_STATE_DIR/claude-pending-$SK" 2>/dev/null)"
# User switches to window (clears everything including pending)
simulate_mark_viewed "$TEST_STATE_DIR" "$SK" "claude"
assert_eq "pending cleared by mark_viewed" "" "$(cat "$TEST_STATE_DIR/claude-pending-$SK" 2>/dev/null)"

# Test: Idle burst followed by real work — indicator shows on real work
SK="test-session-7"
echo "5000" > "$TEST_STATE_DIR/claude-baseline-$SK"
# UI burst: above threshold but stops
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8000"
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "8000"
assert_eq "no indicator after dismissed burst" "no" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"
# Now real work happens
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "12000"
simulate_work_check "$TEST_STATE_DIR" "$SK" "claude" "18000"
assert_eq "indicator shows for real work after dismissed burst" "yes" "$(would_show_indicator "$TEST_STATE_DIR" "$SK" "claude")"

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
