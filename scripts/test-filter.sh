#!/usr/bin/env bash
# Filtered Test Runner - Run specific test groups from dotfiles test suites
# Usage: ./scripts/test-filter.sh [group] [--list]
#
# This is a "harness engineering" tool designed for AI agents.
# Instead of running full test suites, agents can run targeted test groups
# to get faster feedback on specific changes.
#
# Examples:
#   ./scripts/test-filter.sh fish          # Test Fish shell config only
#   ./scripts/test-filter.sh stow          # Test stow compatibility only
#   ./scripts/test-filter.sh claude        # Test Claude Code config only
#   ./scripts/test-filter.sh setup-syntax  # Validate setup.sh syntax only
#   ./scripts/test-filter.sh brewfile      # Validate Brewfile structure
#   ./scripts/test-filter.sh mcp           # Test MCP server parity
#   ./scripts/test-filter.sh all           # Run all groups
#   ./scripts/test-filter.sh --list        # List available test groups

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}  PASS${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}  FAIL${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

list_groups() {
    echo "Available test groups:"
    echo "  fish          - Fish shell configuration and functions"
    echo "  stow          - GNU Stow compatibility"
    echo "  claude        - Claude Code configuration files"
    echo "  setup-syntax  - setup.sh bash syntax validation"
    echo "  brewfile      - Brewfile structure and duplicates"
    echo "  mcp           - MCP server configuration parity"
    echo "  tmux          - tmux configuration"
    echo "  hooks         - Claude Code hooks"
    echo "  agents-md     - AGENTS.md file validation"
    echo "  openclaw      - OpenClaw integration"
    echo "  all           - Run all groups"
}

test_fish() {
    echo -e "${BLUE}--- Fish Shell Tests ---${NC}"
    run_test "Fish config.fish exists" "[ -f '$DOTFILES_ROOT/.config/fish/config.fish' ]"
    run_test "Fish functions directory exists" "[ -d '$DOTFILES_ROOT/.config/fish/functions' ]"
    run_test "Fish config.fish has no bare export statements" "! grep -qE '^[[:space:]]*export ' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Check key functions exist
    for func in gwt-dev gwt-ticket gwt-parallel gwt-status devcon pihole; do
        run_test "Fish function $func exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/$func.fish' ]"
    done

    # Validate Fish syntax if fish is available
    if command -v fish &> /dev/null; then
        run_test "Fish config.fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/config.fish'"
    fi
}

test_stow() {
    echo -e "${BLUE}--- Stow Compatibility Tests ---${NC}"
    run_test ".stow-local-ignore exists" "[ -f '$DOTFILES_ROOT/.stow-local-ignore' ]"
    run_test "Stow ignores scripts" "grep -q 'scripts' '$DOTFILES_ROOT/.stow-local-ignore'"
    run_test "Stow ignores README" "grep -q 'README' '$DOTFILES_ROOT/.stow-local-ignore'"
    run_test "No tmux.conf in .config/tmux" "[ ! -f '$DOTFILES_ROOT/.config/tmux/tmux.conf' ]"
    run_test "tmux.conf at repo root" "[ -f '$DOTFILES_ROOT/.tmux.conf' ]"
}

test_claude() {
    echo -e "${BLUE}--- Claude Code Configuration Tests ---${NC}"
    run_test ".claude directory exists" "[ -d '$DOTFILES_ROOT/.claude' ]"
    run_test ".claude/CLAUDE.md exists" "[ -f '$DOTFILES_ROOT/.claude/CLAUDE.md' ]"
    run_test "Root CLAUDE.md exists" "[ -f '$DOTFILES_ROOT/CLAUDE.md' ]"
    run_test "Root AGENTS.md exists" "[ -f '$DOTFILES_ROOT/AGENTS.md' ]"
    run_test "settings.json exists" "[ -f '$DOTFILES_ROOT/.claude/settings.json' ]"
    run_test "settings.json is valid JSON" "python3 -c \"import json; json.load(open('$DOTFILES_ROOT/.claude/settings.json'))\""
}

test_setup_syntax() {
    echo -e "${BLUE}--- Setup Script Syntax Tests ---${NC}"
    run_test "setup.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "smoke-test.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/smoke-test.sh'"

    # Check key scripts
    for script in ticket-execute.sh ticket-complete.sh; do
        if [ -f "$DOTFILES_ROOT/scripts/$script" ]; then
            run_test "$script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/$script'"
        fi
    done
}

test_brewfile() {
    echo -e "${BLUE}--- Brewfile Tests ---${NC}"
    run_test "Brewfile exists" "[ -f '$DOTFILES_ROOT/homebrew/Brewfile' ]"

    # Check for duplicate entries
    if [ -f "$DOTFILES_ROOT/homebrew/Brewfile" ]; then
        DUPES=$(grep -E '^(brew|cask|mas) ' "$DOTFILES_ROOT/homebrew/Brewfile" | sort | uniq -d | wc -l | tr -d ' ')
        run_test "No duplicate Brewfile entries" "[ '$DUPES' -eq 0 ]"
    fi
}

test_mcp() {
    echo -e "${BLUE}--- MCP Parity Tests ---${NC}"

    # Check Claude Desktop config exists
    local desktop_config="$DOTFILES_ROOT/Library/Application Support/Claude/claude_desktop_config.json"
    run_test "Claude Desktop config exists" "[ -f '$desktop_config' ]"

    if [ -f "$desktop_config" ]; then
        run_test "Claude Desktop config is valid JSON" "python3 -c \"import json; json.load(open('$desktop_config'))\""
    fi

    # Check .mcp.json exists
    run_test ".mcp.json exists" "[ -f '$DOTFILES_ROOT/.mcp.json' ]"
    if [ -f "$DOTFILES_ROOT/.mcp.json" ]; then
        run_test ".mcp.json is valid JSON" "python3 -c \"import json; json.load(open('$DOTFILES_ROOT/.mcp.json'))\""
    fi

    # Hook-dependent MCP servers: deepwiki-context.py requires deepwiki MCP
    # deepwiki is a Claude Code built-in MCP (not in .mcp.json), so verify
    # context7 parity as the hook's fallback documentation source
    if [ -f "$desktop_config" ] && [ -f "$DOTFILES_ROOT/.mcp.json" ]; then
        run_test "context7 in Desktop config" "python3 -c \"import json; d=json.load(open('$desktop_config')); assert 'context7' in d.get('mcpServers', {})\""
        run_test "context7 in CLI config" "python3 -c \"import json; d=json.load(open('$DOTFILES_ROOT/.mcp.json')); assert 'context7' in d.get('mcpServers', {})\""
    fi
}

test_tmux() {
    echo -e "${BLUE}--- tmux Tests ---${NC}"
    run_test ".tmux.conf exists at root" "[ -f '$DOTFILES_ROOT/.tmux.conf' ]"
    run_test "tmux scripts directory exists" "[ -d '$DOTFILES_ROOT/scripts/tmux' ]"
    run_test "Claude watcher script exists" "[ -f '$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh' ]"
    run_test "Claude watcher is executable" "[ -x '$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh' ]"

    # Session close behavior: closing last window should switch to another session, not detach
    run_test "detach-on-destroy set to off (switch session on close)" \
        "grep -q 'detach-on-destroy off' '$DOTFILES_ROOT/.tmux.conf'"

    # exit-empty off keeps server alive so hooks can recreate main
    run_test "exit-empty set to off (server survives sole session close)" \
        "grep -q 'exit-empty off' '$DOTFILES_ROOT/.tmux.conf'"

    # session-closed hook ensures main session is recreated if destroyed
    run_test "session-closed hook recreates main session" \
        "grep -q 'session-closed.*has-session -t main.*new-session -d -s main' '$DOTFILES_ROOT/.tmux.conf'"

    # Integration tests: use a minimal config extracting only session-close settings
    # (full .tmux.conf includes TPM plugins that fail in headless server mode)
    run_test "killing non-main session preserves main (integration)" \
        "bash '$DOTFILES_ROOT/scripts/tmux/test-session-close.sh' kill-nonmain"

    run_test "session-closed hook recreates main after destruction (integration)" \
        "bash '$DOTFILES_ROOT/scripts/tmux/test-session-close.sh' recreate-main"

    run_test "client switches to main when session is killed (integration)" \
        "bash '$DOTFILES_ROOT/scripts/tmux/test-session-close.sh' client-switches"

    run_test "sole main session handled gracefully (integration)" \
        "bash '$DOTFILES_ROOT/scripts/tmux/test-session-close.sh' sole-main-graceful"

    # Empty window fix: gwt-ticket should create session with named window directly
    local GWT_TICKET="$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish"
    run_test "gwt-ticket creates session with window name (-n flag)" \
        "grep -q 'tmux new-session -d -s \$session_name -n \$window_name -c \$worktree_path' '$GWT_TICKET'"
    run_test "gwt-ticket tracks new session creation" \
        "grep -q 'created_new_session' '$GWT_TICKET'"
    run_test "gwt-ticket skips new-window when session just created" \
        "grep -q 'created_new_session.*false' '$GWT_TICKET'"
    run_test "gwt-ticket only creates extra window for existing sessions" \
        "grep -A2 'test.*created_new_session.*false' '$GWT_TICKET' | grep -q 'tmux new-window'"
}

test_hooks() {
    echo -e "${BLUE}--- Claude Code Hooks Tests ---${NC}"
    run_test "Hooks directory exists" "[ -d '$DOTFILES_ROOT/.claude/hooks' ]"

    # Core hook scripts exist and are executable
    for hook in use_bun.py validate-bash.py ts_lint.py macos_notification.py deepwiki-context.py add-context.py log_pre_tool_use.py; do
        run_test "Hook $hook exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
        run_test "Hook $hook executable" "[ -x '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
    done

    for hook in cross-provider-bridge.sh log-notification.sh file-modified.sh; do
        run_test "Hook $hook exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
        run_test "Hook $hook executable" "[ -x '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
    done

    # Validate Python syntax
    for hook in "$DOTFILES_ROOT"/.claude/hooks/*.py; do
        if [ -f "$hook" ]; then
            local name=$(basename "$hook")
            run_test "Hook $name valid Python" "python3 -c \"import py_compile; py_compile.compile('$hook', doraise=True)\""
        fi
    done

    # Settings.json hook events configured
    local settings="$DOTFILES_ROOT/.claude/settings.json"
    if [ -f "$settings" ]; then
        for event in SessionStart PreToolUse PostToolUse PreCompact Notification UserPromptSubmit Stop; do
            run_test "Hook event wired: $event" "python3 -c \"import json; d=json.load(open('$settings')); assert '$event' in d.get('hooks', {})\""
        done
    fi

    # Functional: use_bun.py blocks npm, allows bun
    local hooks_dir="$DOTFILES_ROOT/.claude/hooks"
    run_test "use_bun.py blocks npm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py allows bun" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bun install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null"

    # Functional: validate-bash.py - blocklist
    run_test "validate-bash blocks rm -rf /" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /tmp\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "validate-bash blocks sudo rm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sudo rm -rf node_modules\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "validate-bash blocks dd to device" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"dd if=/dev/zero of=/dev/sda\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null; [ \$? -eq 2 ]"

    # Functional: validate-bash.py - allowlist (devcontainer/worktree)
    run_test "validate-bash allows git status" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: devcontainer up" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"devcontainer up\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: worktree add" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git worktree add ../feat\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: worktree list" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git worktree list\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: docker compose" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker compose up -d\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"

    # Functional: validate-bash.py - fail-closed on bad input
    run_test "validate-bash fail-closed on bad JSON" "echo 'not-json' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null; [ \$? -eq 2 ]"

    # Functional: deepwiki-context.py language detection
    run_test "deepwiki detects Python" "echo '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/x/main.py\"}}' | python3 '$hooks_dir/deepwiki-context.py' 2>/dev/null | grep -q python"
    run_test "deepwiki silent for unknown" "echo '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/x/data.xyz\"}}' | python3 '$hooks_dir/deepwiki-context.py' 2>/dev/null"
}

test_agents_md() {
    echo -e "${BLUE}--- AGENTS.md Validation ---${NC}"
    run_test "Root AGENTS.md exists" "[ -f '$DOTFILES_ROOT/AGENTS.md' ]"

    if [ -f "$DOTFILES_ROOT/AGENTS.md" ]; then
        # Check it contains practical guidance (Hashimoto style)
        run_test "AGENTS.md mentions file locations" "grep -qi 'file.location\|\.tmux\.conf\|config\.fish' '$DOTFILES_ROOT/AGENTS.md'"
        run_test "AGENTS.md mentions available tools" "grep -qi 'available.tool\|smoke-test\|validate' '$DOTFILES_ROOT/AGENTS.md'"
        run_test "AGENTS.md mentions common mistakes" "grep -qi 'mistake\|avoid\|never\|do not' '$DOTFILES_ROOT/AGENTS.md'"
    fi
}

print_summary() {
    echo ""
    echo -e "${BLUE}--- Summary ---${NC}"
    echo -e "  Total: ${TESTS_RUN}  ${GREEN}Pass: ${TESTS_PASSED}${NC}  ${RED}Fail: ${TESTS_FAILED}${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    fi
}

# Main
GROUP="${1:-all}"

case "$GROUP" in
    --list|-l)
        list_groups
        exit 0
        ;;
    fish) test_fish ;;
    stow) test_stow ;;
    claude) test_claude ;;
    setup-syntax) test_setup_syntax ;;
    brewfile) test_brewfile ;;
    mcp) test_mcp ;;
    tmux) test_tmux ;;
    hooks) test_hooks ;;
    agents-md) test_agents_md ;;
    openclaw) source "$SCRIPT_DIR/openclaw/test-openclaw.sh" ;;
    all)
        test_fish
        test_stow
        test_claude
        test_setup_syntax
        test_brewfile
        test_mcp
        test_tmux
        test_hooks
        test_agents_md
        # OpenClaw tests run from their own script (separate counters)
        echo ""
        source "$SCRIPT_DIR/openclaw/test-openclaw.sh"
        ;;
    *)
        echo "Unknown test group: $GROUP"
        echo ""
        list_groups
        exit 1
        ;;
esac

print_summary
