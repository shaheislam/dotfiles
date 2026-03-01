#!/usr/bin/env bash
# test-gwt-rename.sh - Tests for gwt-rename-session.sh and gwt-ticket rename integration
#
# Usage: bash scripts/test-gwt-rename.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENAME_SCRIPT="$SCRIPT_DIR/gwt-rename-session.sh"
GWT_TICKET="$SCRIPT_DIR/../.config/fish/functions/gwt-ticket.fish"

pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "  PASS: $desc"
        pass=$((pass + 1))
    else
        echo "  FAIL: $desc"
        fail=$((fail + 1))
    fi
}

echo "=== gwt-rename-session.sh tests ==="

# Test 1: Script exists and is executable
check "gwt-rename-session.sh exists" "$(test -f "$RENAME_SCRIPT" && echo 0 || echo 1)"
check "gwt-rename-session.sh is executable" "$(test -x "$RENAME_SCRIPT" && echo 0 || echo 1)"

# Test 2: Script requires correct arguments
output=$(bash "$RENAME_SCRIPT" 2>&1 || true)
check "Fails without arguments" "$(echo "$output" | grep -q "Usage" && echo 0 || echo 1)"

# Test 3: Script uses /rename command after completion
check "Uses /rename command" "$(grep -q '/rename \$WINDOW_NAME' "$RENAME_SCRIPT" && echo 0 || echo 1)"

# Test 4: Script uses send-keys for prompt delivery
check "Uses send-keys for prompt" "$(grep -q 'tmux send-keys -l' "$RENAME_SCRIPT" && echo 0 || echo 1)"

# Test 5: Script waits for TUI idle (❯ prompt)
check "Waits for TUI idle" "$(grep -q 'wait_for_idle' "$RENAME_SCRIPT" && echo 0 || echo 1)"

# Test 6: Script waits for agent to go busy before waiting for completion
check "Detects busy state" "$(grep -q 'busy_wait' "$RENAME_SCRIPT" && echo 0 || echo 1)"

echo ""
echo "=== gwt-ticket.fish integration tests ==="

# Test 7: gwt-ticket writes prompt-cmd.txt
check "Writes prompt-cmd.txt" "$(grep -q 'prompt_cmd_file.*prompt-cmd.txt' "$GWT_TICKET" && echo 0 || echo 1)"

# Test 8: gwt-ticket starts Claude without inline prompt
check "Claude starts without prompt arg" "$(grep -q "claude --dangerously-skip-permissions --add-dir.*add_dir_path >>.*launch_script" "$GWT_TICKET" && echo 0 || echo 1)"

# Test 9: gwt-ticket does NOT embed prompt in CLI args anymore
# Old pattern was: claude ... -- "/ralph-wiggum:ralph-loop \"$prompt\" ..."
inline_count=$(grep -c 'claude.*-- ".*slash_command.*prompt' "$GWT_TICKET" 2>/dev/null || true)
check "No inline prompt in claude CLI args" "$([ "$inline_count" = "0" ] && echo 0 || echo 1)"

# Test 10: gwt-ticket captures pane ID with -P -F
check "Captures pane ID with -P -F" "$(grep -q '\-P -F.*pane_id.*fish \$launch_script' "$GWT_TICKET" && echo 0 || echo 1)"

# Test 11: gwt-ticket references rename script (local path)
check "References rename script (local)" "$(grep -q 'rename_script.*gwt-rename-session.sh' "$GWT_TICKET" && echo 0 || echo 1)"

# Test 12: gwt-ticket backgrounds rename invocation
check "Backgrounds rename invocation" "$(grep -q 'rename_script.*claude_pane_id.*window_name.*prompt_cmd_file.*&' "$GWT_TICKET" && echo 0 || echo 1)"

# Test 13: prompt-cmd.txt includes ralph-loop args
check "prompt-cmd includes ralph-loop args" "$(grep -q 'max-iterations.*completion-promise.*prompt_cmd_file' "$GWT_TICKET" && echo 0 || echo 1)"

# Test 14: prompt-cmd.txt includes non-ralph args
check "prompt-cmd includes generic slash command" "$(grep -q 'slash_command.*prompt.*prompt_cmd_file' "$GWT_TICKET" && echo 0 || echo 1)"

# Test 15: No escaped_prompt variable remains
escaped_count=$(grep -c 'escaped_prompt' "$GWT_TICKET" 2>/dev/null || true)
check "No escaped_prompt variable" "$([ "$escaped_count" = "0" ] && echo 0 || echo 1)"

# Test 16: disown follows background job
check "disown follows background rename" "$(grep -A2 'rename_script.*&$' "$GWT_TICKET" | grep -q 'disown' && echo 0 || echo 1)"

# Test 17: devcon path also sets up rename
check "Devcon path has rename script" "$(grep -q 'rename_script_devcon.*gwt-rename-session.sh' "$GWT_TICKET" && echo 0 || echo 1)"

echo ""
echo "Results: $pass passed, $fail failed out of $((pass + fail)) tests"
[ "$fail" -eq 0 ] && exit 0 || exit 1
