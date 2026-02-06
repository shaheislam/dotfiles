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
}

test_tmux() {
    echo -e "${BLUE}--- tmux Tests ---${NC}"
    run_test ".tmux.conf exists at root" "[ -f '$DOTFILES_ROOT/.tmux.conf' ]"
    run_test "tmux scripts directory exists" "[ -d '$DOTFILES_ROOT/scripts/tmux' ]"
    run_test "Claude watcher script exists" "[ -f '$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh' ]"
    run_test "Claude watcher is executable" "[ -x '$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh' ]"
}

test_hooks() {
    echo -e "${BLUE}--- Claude Code Hooks Tests ---${NC}"
    run_test "Hooks directory exists" "[ -d '$DOTFILES_ROOT/.claude/hooks' ]"

    for hook in use_bun.py validate-bash.py ts_lint.py macos_notification.py; do
        run_test "Hook $hook exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
    done

    # Validate Python syntax
    for hook in "$DOTFILES_ROOT"/.claude/hooks/*.py; do
        if [ -f "$hook" ]; then
            local name=$(basename "$hook")
            run_test "Hook $name valid Python" "python3 -c \"import py_compile; py_compile.compile('$hook', doraise=True)\""
        fi
    done
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
        ;;
    *)
        echo "Unknown test group: $GROUP"
        echo ""
        list_groups
        exit 1
        ;;
esac

print_summary
