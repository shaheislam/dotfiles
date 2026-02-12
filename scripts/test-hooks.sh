#!/usr/bin/env bash
# Test suite for Claude Code hooks
# Usage: ./scripts/test-hooks.sh [--live]
#   --live: Also test hooks that require Claude Code session (skipped by default)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$DOTFILES_DIR/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
LIVE_MODE=false

[[ "${1:-}" == "--live" ]] && LIVE_MODE=true

pass() { PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "  ${RED}FAIL${NC} $1"; }
skip() { SKIP=$((SKIP + 1)); echo -e "  ${YELLOW}SKIP${NC} $1"; }
info() { echo -e "${BLUE}==>${NC} $1"; }

# ─── Settings Validation ───────────────────────────────────────────────

info "Settings file validation"

if [ -f "$SETTINGS_FILE" ]; then
    pass "Settings file exists: $SETTINGS_FILE"
else
    fail "Settings file missing: $SETTINGS_FILE"
fi

if jq . "$SETTINGS_FILE" >/dev/null 2>&1; then
    pass "Settings JSON is valid"
else
    fail "Settings JSON is invalid"
fi

# Check all expected hook events are configured
for event in SessionStart PreToolUse PostToolUse PreCompact Notification UserPromptSubmit Stop; do
    if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
        pass "Hook event configured: $event"
    else
        fail "Hook event missing: $event"
    fi
done

# ─── Hook Scripts Exist & Executable ───────────────────────────────────

info "Hook scripts existence and permissions"

# Python hooks
for script in use_bun.py validate-bash.py macos_notification.py deepwiki-context.py add-context.py log_pre_tool_use.py ts_lint.py play_audio.py; do
    if [ -f "$HOOKS_DIR/$script" ]; then
        if [ -x "$HOOKS_DIR/$script" ]; then
            pass "Script exists and executable: $script"
        else
            fail "Script exists but not executable: $script (run: chmod +x $HOOKS_DIR/$script)"
        fi
    else
        fail "Script missing: $HOOKS_DIR/$script"
    fi
done

# Bash hooks
for script in cross-provider-bridge.sh log-notification.sh file-modified.sh; do
    if [ -f "$HOOKS_DIR/$script" ]; then
        if [ -x "$HOOKS_DIR/$script" ]; then
            pass "Script exists and executable: $script"
        else
            fail "Script exists but not executable: $script"
        fi
    else
        fail "Script missing: $HOOKS_DIR/$script"
    fi
done

# Checkpoint hooks
for script in checkpoint-pre-prompt.sh checkpoint-capture.sh; do
    hook_path="$HOME/dotfiles/scripts/hooks/$script"
    if [ -f "$hook_path" ]; then
        pass "Checkpoint hook exists: $script"
    else
        # Check worktree location too
        wt_path="$DOTFILES_DIR/scripts/hooks/$script"
        if [ -f "$wt_path" ]; then
            pass "Checkpoint hook exists (worktree): $script"
        else
            fail "Checkpoint hook missing: $script"
        fi
    fi
done

# ─── use_bun.py Tests ──────────────────────────────────────────────────

info "use_bun.py (PreToolUse: Bun enforcement)"

# Should block npm
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"npm install express"},"session_id":"test"}' | python3 "$HOOKS_DIR/use_bun.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "2" ]; then
    pass "Blocks 'npm install' (exit 2)"
else
    fail "Should block 'npm install' but got exit $exit_code"
fi

# Should block npx
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"npx create-react-app my-app"},"session_id":"test"}' | python3 "$HOOKS_DIR/use_bun.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "2" ]; then
    pass "Blocks 'npx' command (exit 2)"
else
    fail "Should block 'npx' but got exit $exit_code"
fi

# Should allow bun
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"bun install express"},"session_id":"test"}' | python3 "$HOOKS_DIR/use_bun.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Allows 'bun install' (exit 0)"
else
    fail "Should allow 'bun install' but got exit $exit_code"
fi

# Should allow npx exceptions (drawio)
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"npx drawio-mcp-server start"},"session_id":"test"}' | python3 "$HOOKS_DIR/use_bun.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Allows npx exception: drawio-mcp-server (exit 0)"
else
    fail "Should allow npx drawio-mcp-server but got exit $exit_code"
fi

# Should allow non-package-manager commands
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"test"}' | python3 "$HOOKS_DIR/use_bun.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Allows non-package-manager commands (exit 0)"
else
    fail "Should allow 'ls -la' but got exit $exit_code"
fi

# ─── validate-bash.py Tests ────────────────────────────────────────────

info "validate-bash.py (PreToolUse: Bash validation)"

# Should block rm -rf /
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/important"}}' | python3 "$HOOKS_DIR/validate-bash.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "2" ]; then
    pass "Blocks 'rm -rf /' (exit 2)"
else
    fail "Should block 'rm -rf /' but got exit $exit_code"
fi

# Should allow safe commands
result=$(echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | python3 "$HOOKS_DIR/validate-bash.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Allows 'git status' (exit 0)"
else
    fail "Should allow 'git status' but got exit $exit_code"
fi

# Should not block non-Bash tools
result=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"}}' | python3 "$HOOKS_DIR/validate-bash.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Ignores non-Bash tools (exit 0)"
else
    fail "Should ignore non-Bash tools but got exit $exit_code"
fi

# ─── deepwiki-context.py Tests ─────────────────────────────────────────

info "deepwiki-context.py (PostToolUse: language detection)"

# Should provide context for Python files
output=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/home/user/project/main.py"}}' | python3 "$HOOKS_DIR/deepwiki-context.py" 2>/dev/null)
if echo "$output" | grep -q "python"; then
    pass "Detects Python language from .py extension"
else
    fail "Should detect Python for .py files"
fi

# Should provide context for TypeScript files
output=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/home/user/project/app.tsx"}}' | python3 "$HOOKS_DIR/deepwiki-context.py" 2>/dev/null)
if echo "$output" | grep -q "typescript"; then
    pass "Detects TypeScript language from .tsx extension"
else
    fail "Should detect TypeScript for .tsx files"
fi

# Should exit silently for unknown extensions
result=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/data.xyz"}}' | python3 "$HOOKS_DIR/deepwiki-context.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Exits silently for unknown file types"
else
    fail "Should exit 0 for unknown types but got exit $exit_code"
fi

# ─── macos_notification.py Tests ───────────────────────────────────────

info "macos_notification.py (Notification: desktop alerts)"

# Should handle valid notification input without error
result=$(echo '{"notification_type":"info","message":"Test notification"}' | python3 "$HOOKS_DIR/macos_notification.py" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Processes notification without error (exit 0)"
else
    fail "Notification processing failed (exit $exit_code)"
fi

# ─── log-notification.sh Tests ─────────────────────────────────────────

info "log-notification.sh (Notification: logging)"

result=$(echo '{"notification_type":"test","message":"Test log entry"}' | bash "$HOOKS_DIR/log-notification.sh" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Logs notification without error (exit 0)"
else
    fail "Notification logging failed (exit $exit_code)"
fi

# Check log file was created
LOG_FILE="$HOME/.claude/hooks/logs/notifications-$(date +%Y-%m-%d).log"
if [ -f "$LOG_FILE" ]; then
    pass "Notification log file created: $LOG_FILE"
else
    fail "Notification log file not created"
fi

# ─── cross-provider-bridge.sh Tests ────────────────────────────────────

info "cross-provider-bridge.sh (Stop: cross-provider review)"

# Should exit 0 when bridge is disabled (default)
result=$(echo '{"session_id":"test","transcript_path":"/tmp/nonexistent.jsonl","stop_hook_active":false}' | CROSS_PROVIDER_BRIDGE="" bash "$HOOKS_DIR/cross-provider-bridge.sh" 2>/dev/null; echo "EXIT:$?")
exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | cut -d: -f2)
if [ "$exit_code" = "0" ]; then
    pass "Exits cleanly when bridge disabled (exit 0)"
else
    fail "Should exit 0 when bridge disabled but got exit $exit_code"
fi

# ─── Settings Wiring Verification ──────────────────────────────────────

info "Hook wiring verification (settings.json references valid scripts)"

# Extract all command paths from settings.json
commands=$(jq -r '.. | objects | select(.type == "command") | .command' "$SETTINGS_FILE" 2>/dev/null | sort -u)

while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue

    # Expand ~ and env vars for validation
    expanded=$(echo "$cmd" | sed "s|~/|$HOME/|g" | sed 's| 2>/dev/null.*||' | sed 's| ||g' | head -1)

    # Extract the script path (before any arguments)
    script_path=$(echo "$expanded" | awk '{
        for (i=1; i<=NF; i++) {
            if ($i ~ /\.(sh|py)$/ || $i ~ /^(bash|python3)$/) continue
            if ($i ~ /\// && $i !~ /^-/) { print $i; exit }
        }
    }')

    # For python3/bash commands, get the actual script
    if echo "$cmd" | grep -q "python3\|^bash "; then
        script_path=$(echo "$cmd" | sed 's|.*python3 ||; s|.*bash ||' | sed 's| 2>/dev/null.*||' | sed "s|~/|$HOME/|g; s|~/.claude|$HOME/.claude|g" | awk '{print $1}')
    fi

    if [ -n "$script_path" ] && [ -f "$script_path" ]; then
        pass "Wired script exists: $(basename "$script_path")"
    elif echo "$cmd" | grep -q "^bd "; then
        # bd (beads) is a CLI tool, not a file
        if command -v bd >/dev/null 2>&1; then
            pass "CLI tool available: bd (beads)"
        else
            skip "CLI tool not installed: bd (beads)"
        fi
    else
        skip "Could not verify: $cmd"
    fi
done <<< "$commands"

# ─── Summary ───────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "  ${GREEN}All tests passed!${NC}"
    exit 0
fi
