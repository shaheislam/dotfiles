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
    if eval "$test_command" >/dev/null 2>&1; then
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
    echo "  cd-perf       - CD performance optimizations"
    echo "  lsp           - Claude Code LSP integration"
    echo "  nvim-bridge   - Neovim-Claude Code bridge"
    echo "  remote-control - Claude Code Remote Control"
    echo "  settings      - Claude Code settings validation"
    echo "  gitattributes - Gitattributes and custom diff/merge drivers"
    echo "  merge-driver  - CLAUDE.md merge conflict auto-resolution"
    echo "  openclaw      - OpenClaw integration"
    echo "  subagents     - Claude Code subagent files"
    echo "  integrations  - Third-party provider integrations"
    echo "  opencode      - OpenCode project config, commands, agents, and plugins"
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

    run_test "codex-accounts supports capture" \
        "grep -q 'case capture refresh' '$DOTFILES_ROOT/.config/fish/functions/codex-accounts.fish'"
    run_test "codex-accounts supports workspace pinning" \
        "grep -q 'case workspace' '$DOTFILES_ROOT/.config/fish/functions/codex-accounts.fish'"
    run_test "codex-rotate preserves live session candidate" \
        "grep -q '__active__' '$DOTFILES_ROOT/.config/fish/functions/codex-rotate.fish'"
    run_test "codex-rotate supports forced workspace config" \
        "grep -q 'forced_chatgpt_workspace_id' '$DOTFILES_ROOT/.config/fish/functions/codex-rotate.fish'"
    run_test "_codex_workspace_id helper exists" \
        "[ -f '$DOTFILES_ROOT/.config/fish/functions/_codex_workspace_id.fish' ]"

    # Check tab completion functions exist
    for func in _cd_fzf_tab_complete _fifc_or_fzf _autopair_tab; do
        run_test "Fish tab completion $func exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/$func.fish' ]"
    done

    # Validate Fish syntax if fish is available
    if command -v fish &>/dev/null; then
        run_test "Fish config.fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/config.fish'"
        # Validate tab completion function syntax
        for func in _cd_fzf_tab_complete _fifc_or_fzf; do
            run_test "Fish function $func syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/$func.fish'"
        done
        for func in _codex_workspace_id codex-accounts codex-rotate; do
            run_test "Fish function $func syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/$func.fish'"
        done
        # Validate _cd_fzf_tab_complete loads and is queryable
        run_test "Fish _cd_fzf_tab_complete loads" "fish -c 'source $DOTFILES_ROOT/.config/fish/functions/_cd_fzf_tab_complete.fish && functions -q _cd_fzf_tab_complete'"
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

    # --skill flag: invoke skills at prompt start
    run_test "gwt-ticket supports --skill flag" \
        "grep -q 'case --skill' '$GWT_TICKET'"
    run_test "gwt-ticket --skill consumes multiple args until next flag" \
        "grep -q 'string match -q -- .--.*. \$argv' '$GWT_TICKET'"
    run_test "gwt-ticket --skill normalizes leading slash" \
        "grep -q \"string replace -r '\\^/' '' --\" '$GWT_TICKET'"
    run_test "gwt-ticket --skill injects skill invocations into prompt" \
        "grep -q 'IMPORTANT: Before starting the task below, invoke these skills' '$GWT_TICKET'"
    run_test "gwt-ticket --skill shown in verbose output" \
        "grep -q 'Skills:.*string join' '$GWT_TICKET'"
    run_test "gwt-ticket --skill shown in help text" \
        "grep -q '\\-\\-skill NAME' '$GWT_TICKET'"
    run_test "gwt-ticket --skill documented in header comment" \
        "grep -q '#.*--skill NAME' '$GWT_TICKET'"

    # --bridge optional arg uses -- to prevent flag injection into string match
    run_test "gwt-ticket --bridge string match uses -- separator" \
        "grep -q 'string match -qr.*\\^\\[0-9\\].*-- \\\$argv' '$GWT_TICKET'"
    run_test "gwt-ticket --bridge --skill combination safe (no string match error)" \
        "fish -c 'string match -qr \"^[0-9]+\\\$\" -- \"--skill\"; or true'"
}

test_hooks() {
    echo -e "${BLUE}--- Claude Code Hooks Tests ---${NC}"
    run_test "Hooks directory exists" "[ -d '$DOTFILES_ROOT/.claude/hooks' ]"

    # Core hook scripts exist and are executable
    for hook in use_bun.py validate-bash.py ts_lint.py macos_notification.py deepwiki-context.py add-context.py log_pre_tool_use.py protect-files.py log-tool-failure.py auto-format.py; do
        run_test "Hook $hook exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
        run_test "Hook $hook executable" "[ -x '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
    done

    for hook in cross-provider-bridge.sh log-notification.sh file-modified.sh post-compact-reinject.sh; do
        run_test "Hook $hook exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
        run_test "Hook $hook executable" "[ -x '$DOTFILES_ROOT/.claude/hooks/$hook' ]"
    done

    # Validate Python syntax
    for hook in "$DOTFILES_ROOT"/.claude/hooks/*.py; do
        if [ -f "$hook" ]; then
            local name
            name=$(basename "$hook")
            run_test "Hook $name valid Python" "python3 -c \"import py_compile; py_compile.compile('$hook', doraise=True)\""
        fi
    done

    # Settings.json hook events configured
    local settings="$DOTFILES_ROOT/.claude/settings.json"
    if [ -f "$settings" ]; then
        for event in SessionStart PreToolUse PostToolUse PostToolUseFailure PreCompact Notification UserPromptSubmit Stop; do
            run_test "Hook event wired: $event" "python3 -c \"import json; d=json.load(open('$settings')); assert '$event' in d.get('hooks', {})\""
        done
    fi

    # Functional: use_bun.py blocks npm, allows bun
    local hooks_dir="$DOTFILES_ROOT/.claude/hooks"
    run_test "use_bun.py blocks npm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py blocks yarn" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"yarn add react\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py blocks pnpm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pnpm install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py blocks npx" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npx create-react-app\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py allows bun" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bun install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null"
    run_test "use_bun.py allows bunx" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bunx create-react-app\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null"

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

    # Functional: protect-files.py blocks sensitive files
    run_test "protect-files blocks .env" "echo '{\"tool_input\":{\"file_path\":\"/app/.env\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "protect-files blocks .env.local" "echo '{\"tool_input\":{\"file_path\":\"/app/.env.local\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "protect-files blocks package-lock.json" "echo '{\"tool_input\":{\"file_path\":\"/app/package-lock.json\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "protect-files blocks yarn.lock" "echo '{\"tool_input\":{\"file_path\":\"/app/yarn.lock\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "protect-files blocks pnpm-lock.yaml" "echo '{\"tool_input\":{\"file_path\":\"/app/pnpm-lock.yaml\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "protect-files blocks node_modules" "echo '{\"tool_input\":{\"file_path\":\"/app/node_modules/foo/index.js\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "protect-files allows normal files" "echo '{\"tool_input\":{\"file_path\":\"/app/src/main.py\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null"

    # Functional: protect-files.py allowlist (avoid false positives)
    run_test "protect-files allows .env.example" "echo '{\"tool_input\":{\"file_path\":\"/app/.env.example\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null"
    run_test "protect-files allows bun.lockb" "echo '{\"tool_input\":{\"file_path\":\"/app/bun.lockb\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null"
    run_test "protect-files allows Cargo.lock" "echo '{\"tool_input\":{\"file_path\":\"/app/Cargo.lock\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null"
    run_test "protect-files allows poetry.lock" "echo '{\"tool_input\":{\"file_path\":\"/app/poetry.lock\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null"

    # Functional: log-tool-failure.py exits 0 (non-blocking)
    run_test "log-tool-failure exits 0" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bad\"},\"error\":\"fail\"}' | python3 '$hooks_dir/log-tool-failure.py' 2>/dev/null"

    # Functional: log-tool-failure.py redacts secrets
    run_test "log-tool-failure redacts secrets" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"export API_KEY=abc123\"},\"error\":\"password leaked\"}' | python3 '$hooks_dir/log-tool-failure.py' 2>/dev/null && tail -1 ~/.claude/hooks/logs/tool-failures-\$(date +%Y-%m-%d).jsonl | grep -q REDACTED"

    # Functional: auto-format.py exits 0 on non-existent file (non-blocking)
    run_test "auto-format exits 0 for missing file" "echo '{\"tool_input\":{\"file_path\":\"/nonexistent/file.py\"}}' | python3 '$hooks_dir/auto-format.py' 2>/dev/null"

    # Functional: auto-format.py skips unknown extensions (non-blocking)
    run_test "auto-format skips unknown extension" "echo '{\"tool_input\":{\"file_path\":\"/tmp/data.xyz\"}}' | python3 '$hooks_dir/auto-format.py' 2>/dev/null"

    # Functional: auto-format.py graceful on empty .sh file
    run_test "auto-format graceful on empty sh" "
        tmpsh=\$(mktemp /tmp/hook-test-XXXXXX.sh)
        echo '{\"tool_input\":{\"file_path\":\"'\"\$tmpsh\"'\"}}' | python3 '$hooks_dir/auto-format.py' 2>/dev/null
        rc=\$?; rm -f \"\$tmpsh\"; [ \$rc -eq 0 ]
    "

    # Functional: auto-format.py JSON idempotency (already formatted file unchanged)
    run_test "auto-format JSON idempotent" "
        tmpjson=\$(mktemp /tmp/hook-test-XXXXXX.json)
        echo '{\"a\": 1}' > \"\$tmpjson\"
        echo '{\"tool_input\":{\"file_path\":\"'\"\$tmpjson\"'\"}}' | python3 '$hooks_dir/auto-format.py' 2>/dev/null
        md5_1=\$(md5 -q \"\$tmpjson\")
        echo '{\"tool_input\":{\"file_path\":\"'\"\$tmpjson\"'\"}}' | python3 '$hooks_dir/auto-format.py' 2>/dev/null
        md5_2=\$(md5 -q \"\$tmpjson\")
        rm -f \"\$tmpjson\"
        [ \"\$md5_1\" = \"\$md5_2\" ]
    "

    # Functional: protect-files.py path normalization (traversal prevention)
    run_test "protect-files blocks traversal to .env" "echo '{\"tool_input\":{\"file_path\":\"/app/foo/../../.env\"}}' | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"

    # Functional: hook ordering — PreToolUse Bash has use_bun before validate-bash
    run_test "hook order: use_bun before validate-bash" "python3 -c \"
import json
d=json.load(open('$DOTFILES_ROOT/.claude/settings.json'))
bash_hooks=[h for h in d['hooks']['PreToolUse'] if h.get('matcher')=='Bash'][0]['hooks']
cmds=[h['command'] for h in bash_hooks]
assert cmds.index([c for c in cmds if 'use_bun' in c][0]) < cmds.index([c for c in cmds if 'validate-bash' in c][0])
\""

    # Functional: post-compact-reinject.sh outputs context reminders
    run_test "post-compact outputs bun reminder" "[[ \$(bash '$hooks_dir/post-compact-reinject.sh' 2>/dev/null) == *bun* ]]"
    run_test "post-compact outputs Tokyo Night" "[[ \$(bash '$hooks_dir/post-compact-reinject.sh' 2>/dev/null) == *'Tokyo Night'* ]]"
    run_test "post-compact exits 0" "bash '$hooks_dir/post-compact-reinject.sh' >/dev/null 2>&1"
}

test_cd_perf() {
    echo -e "${BLUE}--- CD Performance Tests ---${NC}"

    # z plugin PWD hook should be disabled (commented out)
    run_test "z plugin PWD hook is disabled" "grep -q '# function __z_on_variable_pwd' '$DOTFILES_ROOT/.config/fish/conf.d/z.fish'"
    run_test "z plugin __z_add not called on cd" "! grep -qE '^[[:space:]]+__z_add' '$DOTFILES_ROOT/.config/fish/conf.d/z.fish'"

    # Diffview hook should have negative caching (counter-based, no date subprocess)
    run_test "Diffview hook has negative cache" "grep -q '__diffview_neg_remaining' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"
    run_test "Diffview hook uses async tmux probe" "grep -q '__diffview_probe_file' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"
    run_test "Diffview hook no date subprocess" "! grep -v '^#' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish' | grep -q 'date +%s'"
    run_test "Diffview hook single-flight guard" "grep -q 'Single-flight guard' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"
    run_test "Diffview hook exit cleanup" "grep -q 'fish_exit' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"

    # z.fish and diffview-follow.fish should have valid Fish syntax
    if command -v fish &>/dev/null; then
        run_test "z.fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/conf.d/z.fish'"
        run_test "diffview-follow.fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"
    fi

    # Zoxide should still be the active directory tracker
    run_test "Zoxide init in config.fish" "grep -q 'zoxide' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Starship should have performance optimizations
    run_test "Starship ignores submodules" "grep -q 'ignore_submodules = true' '$DOTFILES_ROOT/.config/starship.toml'"
    run_test "Starship skips repo truncation" "grep -q 'truncate_to_repo = false' '$DOTFILES_ROOT/.config/starship.toml'"
    run_test "Starship only_attached branch" "grep -q 'only_attached = true' '$DOTFILES_ROOT/.config/starship.toml'"
    run_test "Starship command_timeout <= 200ms" "grep -qE 'command_timeout = (1[0-9]{0,2}|200|[1-9][0-9]?)$' '$DOTFILES_ROOT/.config/starship.toml'"
    # Kubernetes module disabled by default (reads ~/.kube/config, ~110ms per prompt)
    run_test "Starship k8s disabled by default" "grep -A10 '^\[kubernetes\]' '$DOTFILES_ROOT/.config/starship.toml' | grep -q 'disabled = true'"

    # Direnv and mise should use deferred evaluation
    run_test "Direnv uses eval_after_arrow" "grep -q 'direnv_fish_mode eval_after_arrow' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Mise uses eval_after_arrow" "grep -q 'mise_fish_mode eval_after_arrow' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Prompt handlers should be overridden to skip redundant evaluations
    run_test "Direnv prompt handler uses init guard" "grep -q '__direnv_initialized' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Mise prompt handler uses init guard" "grep -q '__mise_initialized' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Direnv preexec should check .envrc scope to skip re-evaluation within same project
    run_test "Direnv preexec has envrc scope check" "grep -q '__direnv_last_envrc' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Scope tracker must use walk-up path, NOT $DIRENV_FILE (worktree-safe)
    # In git worktrees, $DIRENV_FILE points to the main worktree's .envrc,
    # which breaks the scope check and causes 660ms re-evaluation on every cd
    run_test "Direnv scope uses walk-up not DIRENV_FILE" "! grep -q 'last_envrc.*DIRENV_FILE' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Nested .envrc: walk-up must find nearest, so child .envrc triggers re-eval
    if command -v fish &>/dev/null; then
        run_test "Nested .envrc detected by walk-up" "fish -c '
            mkdir -p /tmp/test-envrc-nested/sub
            echo x > /tmp/test-envrc-nested/.envrc
            echo y > /tmp/test-envrc-nested/sub/.envrc
            set -l d1 /tmp/test-envrc-nested; set -l f1 \"\"
            while test \"\$d1\" != /
                test -f \"\$d1/.envrc\"; and set f1 \"\$d1/.envrc\"; and break
                set d1 (string replace -r \"/[^/]+\\\$\" \"\" -- \"\$d1\")
            end
            set -l d2 /tmp/test-envrc-nested/sub; set -l f2 \"\"
            while test \"\$d2\" != /
                test -f \"\$d2/.envrc\"; and set f2 \"\$d2/.envrc\"; and break
                set d2 (string replace -r \"/[^/]+\\\$\" \"\" -- \"\$d2\")
            end
            rm -rf /tmp/test-envrc-nested
            test \"\$f1\" != \"\$f2\"
        '"
    fi

    # Direnv reload helper should exist for manual .envrc refresh
    run_test "Direnv reload function (denv) exists" "grep -q 'function denv' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Mise preexec should check config scope to skip re-evaluation within same project
    run_test "Mise preexec has config scope check" "grep -q '__mise_last_config' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Mise preexec is overridden" "grep -q 'function __mise_env_eval_2' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Mise preexec no stray echo" "! grep -A2 'mise hook-env.*source' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -qE '^[[:space:]]*echo;?\$'"
    # Mise scope tracks mtime to detect in-place config edits (not just path)
    run_test "Mise scope tracks mtime" "grep -A20 'function __mise_env_eval_2' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'stat.*%m'"

    # denv should reset both direnv and mise scope caches
    run_test "denv resets mise scope cache" "grep -A15 'function denv' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q '__mise_last_config'"

    # PWD hooks must be persistent (not erased by preexec)
    # BUG FIX: The upstream eval_after_arrow pattern defines PWD hooks inside fish_prompt
    # and erases them in fish_preexec. But fish_preexec fires BEFORE cd runs, so the hooks
    # are gone when PWD actually changes. Fix: persistent top-level hooks.
    run_test "Direnv cd hook is persistent (top-level)" "grep -qE '^[[:space:]]+function __direnv_cd_hook --on-variable PWD' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Mise cd hook is persistent (top-level)" "grep -qE '^[[:space:]]+function __mise_cd_hook --on-variable PWD' '$DOTFILES_ROOT/.config/fish/config.fish'"
    # Preexec must NOT erase cd hooks (that was the bug)
    run_test "Direnv preexec does not erase cd hook" "! grep -A20 'function __direnv_export_eval_2' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'functions --erase __direnv_cd_hook'"
    run_test "Mise preexec does not erase cd hook" "! grep -A20 'function __mise_env_eval_2' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'functions --erase __mise_cd_hook'"
    # CD hooks must be flag-only (no cd/PWD mutation = no reentrancy risk)
    run_test "Direnv cd hook is flag-only (no reentrancy)" "grep -A3 'function __direnv_cd_hook' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'set -g __direnv_export_again' && ! grep -A3 'function __direnv_cd_hook' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -qE '(builtin cd|direnv export|source)'"
    run_test "Mise cd hook is flag-only (no reentrancy)" "grep -A3 'function __mise_cd_hook' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'set -g __mise_env_again' && ! grep -A3 'function __mise_cd_hook' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -qE '(builtin cd|mise hook-env|source)'"

    # Diffview should cache positive socket results (avoid 52ms tmux IPC per cd)
    run_test "Diffview caches positive socket" "grep -q '__diffview_cached_socket' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"
    run_test "Diffview socket self-heals on stale" "grep -q 'Socket gone.*clear cache' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"
    # Diffview cache invalidates on tmux server/session change
    run_test "Diffview invalidates on TMUX change" "grep -q '__diffview_cached_tmux' '$DOTFILES_ROOT/.config/fish/conf.d/diffview-follow.fish'"

    # Direnv must be defined before mise (ordering invariant for PATH precedence)
    run_test "Direnv hooks defined before mise hooks" "
        direnv_line=\$(grep -n 'function __direnv_export_eval ' '$DOTFILES_ROOT/.config/fish/config.fish' | head -1 | cut -d: -f1)
        mise_line=\$(grep -n 'function __mise_env_eval ' '$DOTFILES_ROOT/.config/fish/config.fish' | head -1 | cut -d: -f1)
        test -n \"\$direnv_line\" && test -n \"\$mise_line\" && test \"\$direnv_line\" -lt \"\$mise_line\"
    "

    # PWD hooks use --on-variable PWD which fires for any PWD change mechanism
    # (cd, pushd, popd, z, j, builtin cd, etc.) — verify the hook binding
    run_test "Direnv hook fires on any PWD change" "grep -q '__direnv_cd_hook --on-variable PWD' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Mise hook fires on any PWD change" "grep -q '__mise_cd_hook --on-variable PWD' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # All hooks must be inside non-interactive guard
    run_test "Hooks gated by is-interactive" "grep -q 'status is-interactive' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Inline event handler exception is documented (AGENTS.md says functions/ for new funcs)
    run_test "Inline handler justification documented" "grep -q 'event handlers require sourcing to register' '$DOTFILES_ROOT/.config/fish/config.fish' || grep -q 'autoload.*register event handlers' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Scope cache must never use universal variables (set -U)
    run_test "No universal vars in scope cache" "! grep -qE '__direnv_(last_envrc|initialized|export_again).*set -U' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "No universal vars in mise scope cache" "! grep -qE '__mise_(last_config|initialized|env_again).*set -U' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # Escape delay should be low
    run_test "Fish escape delay <= 10ms" "grep -q 'fish_escape_delay_ms 10' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # tmux escape-time should be 0
    run_test "tmux escape-time is 0" "grep -q 'escape-time 0' '$DOTFILES_ROOT/.tmux.conf'"
}

test_lsp() {
    echo -e "${BLUE}--- Claude Code LSP Tests ---${NC}"

    # LSP status hook exists and is executable
    run_test "LSP hook lsp-status.sh exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/lsp-status.sh' ]"
    run_test "LSP hook lsp-status.sh executable" "[ -x '$DOTFILES_ROOT/.claude/hooks/lsp-status.sh' ]"

    # LSP hook is wired in settings.json SessionStart
    local settings="$DOTFILES_ROOT/.claude/settings.json"
    run_test "LSP hook wired in SessionStart" "grep -q 'lsp-status.sh' '$settings'"

    # LSP hook produces valid output (exits 0, output contains LSP or is empty)
    run_test "LSP hook exits 0" "bash '$DOTFILES_ROOT/.claude/hooks/lsp-status.sh' >/dev/null 2>&1"

    # Fish function exists
    run_test "cc-lsp Fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/cc-lsp.fish' ]"

    # Setup script has LSP marketplace and plugin installs
    run_test "setup.sh adds boostvolt LSP marketplace" "grep -q 'boostvolt/claude-code-lsps' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh installs pyright LSP" "grep -q 'pyright@claude-code-lsps' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh installs typescript LSP" "grep -q 'typescript@claude-code-lsps' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh installs bash-lsp" "grep -q 'bash-lsp@claude-code-lsps' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh installs nix-lsp" "grep -q 'nix-lsp@claude-code-lsps' '$DOTFILES_ROOT/scripts/setup.sh'"

    # LSP documentation exists
    run_test "LSP docs exist" "[ -f '$DOTFILES_ROOT/docs/claude-code-lsp.md' ]"

    # Check LSP binaries available (non-blocking - just informational)
    for bin in pyright-langserver typescript-language-server gopls rust-analyzer bash-language-server yaml-language-server terraform-ls nil; do
        if command -v "$bin" &>/dev/null; then
            run_test "LSP binary in PATH: $bin" "true"
        else
            echo -e "${YELLOW}  SKIP${NC} LSP binary not in PATH: $bin (install via Nix or Homebrew)"
        fi
    done

    # Validate lsp-status.sh has bash associative array syntax
    run_test "lsp-status.sh uses bash (not sh)" "head -1 '$DOTFILES_ROOT/.claude/hooks/lsp-status.sh' | grep -q bash"
}

test_remote_control() {
    echo -e "${BLUE}--- Claude Code Remote Control Tests ---${NC}"

    # Fish function exists
    run_test "cc-rc Fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish' ]"

    # Fish function syntax valid
    if command -v fish &>/dev/null; then
        run_test "cc-rc Fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
        run_test "cc-rc function loads" "fish -c 'source $DOTFILES_ROOT/.config/fish/functions/cc-rc.fish && functions -q cc-rc'"
    fi

    # Fish function has required subcommands
    run_test "cc-rc has start command" "grep -q 'case start' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc has status command" "grep -q 'case status' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc has enable command" "grep -q 'case enable' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc has disable command" "grep -q 'case disable' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc has tmux command" "grep -q 'case tmux' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc has help command" "grep -q 'case help' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"

    # Fish function uses claude remote-control command
    run_test "cc-rc calls claude remote-control" "grep -q 'claude remote-control' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc has interactive command" "grep -q 'case interactive' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc interactive uses --remote-control flag" "grep -q '\-\-remote-control' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"

    # Launch commands use --remote-control flag for deterministic enablement
    run_test "gwt-ticket uses --remote-control flag" "grep -q '\-\-remote-control' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-parallel uses --remote-control flag" "grep -q '\-\-remote-control' '$DOTFILES_ROOT/.config/fish/functions/gwt-parallel.fish'"

    # Fish function supports --verbose and --sandbox flags
    run_test "cc-rc supports --verbose flag" "grep -q '\-\-verbose' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"
    run_test "cc-rc supports --sandbox flag" "grep -q '\-\-sandbox' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"

    # Fish function reads enableRemoteControl from ~/.claude.json
    run_test "cc-rc reads enableRemoteControl" "grep -q 'enableRemoteControl' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"

    # Fish function uses jq for config manipulation
    run_test "cc-rc uses jq" "grep -q 'jq' '$DOTFILES_ROOT/.config/fish/functions/cc-rc.fish'"

    # setup.sh enables remote control
    run_test "setup.sh enables remote control" "grep -q 'enableRemoteControl' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh has remote control comment reference" "grep -q 'remote-control' '$DOTFILES_ROOT/scripts/setup.sh'"
}

test_settings() {
    echo -e "${BLUE}--- Claude Code Settings Tests ---${NC}"

    local SETTINGS="$DOTFILES_ROOT/.claude/settings.json"

    # Schema validation
    run_test "settings.json has \$schema" "grep -q 'json.schemastore.org/claude-code-settings' '$SETTINGS'"
    run_test "settings.json valid JSON" "python3 -m json.tool '$SETTINGS' > /dev/null 2>&1"

    # Permission rules exist
    run_test "settings has permissions block" "python3 -c \"import json; d=json.load(open('$SETTINGS')); assert 'permissions' in d\""
    run_test "settings has allow rules" "python3 -c \"import json; d=json.load(open('$SETTINGS')); assert len(d['permissions']['allow']) > 0\""
    run_test "settings has deny rules" "python3 -c \"import json; d=json.load(open('$SETTINGS')); assert len(d['permissions']['deny']) > 0\""

    # Deny rules protect sensitive files
    run_test "deny .env files" "grep -q 'Read(./.env)' '$SETTINGS'"
    run_test "deny SSH keys" "grep -q 'Read(~/.ssh/id_' '$SETTINGS'"
    run_test "deny AWS credentials" "grep -q 'Read(~/.aws/credentials)' '$SETTINGS'"
    run_test "deny destructive rm" "grep -q 'rm -rf /' '$SETTINGS'"
    run_test "deny pipe-to-shell" "grep -q 'curl .* | bash' '$SETTINGS'"

    # Allow rules for safe commands
    run_test "allow git status" "grep -q 'Bash(git status' '$SETTINGS'"
    run_test "allow bun run" "grep -q 'Bash(bun run' '$SETTINGS'"
    run_test "allow --version" "grep -q '\-\-version' '$SETTINGS'"

    # Sandbox config in setup.sh
    run_test "setup.sh has sandbox config" "grep -q 'sandbox' '$DOTFILES_ROOT/scripts/setup.sh' && grep -q 'autoAllowBashIfSandboxed' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh excludes docker from sandbox" "grep -q 'excludedCommands.*docker' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh sandbox denies credential reads" "grep -q 'denyRead.*aws/credentials' '$DOTFILES_ROOT/scripts/setup.sh'"

    # Attribution config in setup.sh
    run_test "setup.sh suppresses attribution" "grep -q 'attribution.*commit.*pr' '$DOTFILES_ROOT/scripts/setup.sh'"

    # Environment variables in Fish config
    run_test "Fish has CLAUDE_CODE_EFFORT_LEVEL" "grep -q 'CLAUDE_CODE_EFFORT_LEVEL' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Fish has FORCE_AUTOUPDATE_PLUGINS" "grep -q 'FORCE_AUTOUPDATE_PLUGINS' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Fish has CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD" "grep -q 'CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD' '$DOTFILES_ROOT/.config/fish/config.fish'"

    # CLAUDE.md documentation
    run_test "CLAUDE.md documents settings section" "grep -q 'Claude Code Settings & Security' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents permission rules" "grep -q 'Permission Rules' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents sandbox config" "grep -q 'Sandbox Configuration' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents attribution" "grep -q 'attribution.commit' '$DOTFILES_ROOT/CLAUDE.md'"
}

test_nvim_bridge() {
    echo -e "${BLUE}--- Neovim-Claude Bridge Tests ---${NC}"

    # Hook exists and is executable
    run_test "nvim-bridge.sh exists" "[ -f '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' ]"
    run_test "nvim-bridge.sh executable" "[ -x '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' ]"
    run_test "nvim-bridge.sh uses bash" "head -1 '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' | grep -q bash"

    # Hook wired in settings.json
    run_test "nvim-bridge wired in UserPromptSubmit" "grep -q 'nvim-bridge.sh' '$DOTFILES_ROOT/.claude/settings.json'"

    # Hook exits 0 with no state (graceful no-op)
    run_test "nvim-bridge exits 0 (no state)" "bash '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' >/dev/null 2>&1"

    # Hook outputs valid JSON when state exists
    # shellcheck disable=SC2034
    local test_dir="/tmp/nvim-claude-bridge-test-$$"
    local test_hash
    test_hash=$(echo -n "/tmp/test-project" | shasum -a 256 | cut -c1-8)
    local test_state_dir="/tmp/nvim-claude-bridge/$test_hash"
    mkdir -p "$test_state_dir"
    local now
    now=$(date +%s)
    cat >"$test_state_dir/state.json" <<TESTEOF
{"project":"/tmp/test-project","nvim_pid":$$,"diagnostics":{"timestamp":$now,"errors":[{"file":"src/main.py","line":42,"message":"Undefined var","source":"Pyright"}],"warnings":[],"error_count":1,"warning_count":0},"focus":{"timestamp":$now,"file":"src/main.py","line":42,"filetype":"python"}}
TESTEOF

    run_test "nvim-bridge outputs JSON with state" "CLAUDE_PROJECT_DIR=/tmp/test-project bash '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' 2>/dev/null | python3 -c 'import json,sys; json.load(sys.stdin)'"
    run_test "nvim-bridge output has systemMessage" "CLAUDE_PROJECT_DIR=/tmp/test-project bash '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' 2>/dev/null | grep -q systemMessage"

    # Staleness: old timestamps should be skipped
    cat >"$test_state_dir/state.json" <<TESTEOF2
{"project":"/tmp/test-project","nvim_pid":$$,"diagnostics":{"timestamp":1000000,"errors":[{"file":"old.py","line":1,"message":"stale","source":"x"}],"warnings":[],"error_count":1,"warning_count":0}}
TESTEOF2

    run_test "nvim-bridge skips stale sections" "[ -z \"\$(CLAUDE_PROJECT_DIR=/tmp/test-project bash '$DOTFILES_ROOT/.claude/hooks/nvim-bridge.sh' 2>/dev/null)\" ]"

    # Cleanup test state
    rm -rf "$test_state_dir" 2>/dev/null

    # Fish function exists
    run_test "cc-bridge Fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/cc-bridge.fish' ]"

    # Documentation
    run_test "Bridge docs exist" "[ -f '$DOTFILES_ROOT/docs/nvim-claude-bridge.md' ]"
}

test_entire() {
    echo -e "${BLUE}--- Entire CLI Integration Tests ---${NC}"

    # Brewfile has entire
    run_test "Brewfile has entireio/tap tap" "grep -q 'entireio/tap' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "Brewfile has entire formula" "grep -q 'entireio/tap/entire' '$DOTFILES_ROOT/homebrew/Brewfile'"

    # Setup.sh has entire installation
    run_test "setup.sh installs entire" "grep -q 'entireio/tap/entire' '$DOTFILES_ROOT/scripts/setup.sh'"

    # Fish wrappers exist
    run_test "checkpoints.fish wraps entire" "grep -q 'entire' '$DOTFILES_ROOT/.config/fish/functions/checkpoints.fish'"
    run_test "ckpt.fish alias exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/ckpt.fish' ]"

    # gwt-ticket uses entire enable
    run_test "gwt-ticket uses entire enable" "grep -q 'entire_args enable' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket no old checkpoints.sh" "! grep -q 'checkpoints.sh enable' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    # Old checkpoint scripts removed
    run_test "No old checkpoints.sh" "[ ! -f '$DOTFILES_ROOT/scripts/checkpoints.sh' ]"
    run_test "No old checkpoint-capture.sh" "[ ! -f '$DOTFILES_ROOT/scripts/hooks/checkpoint-capture.sh' ]"
    run_test "No old checkpoint-pre-prompt.sh" "[ ! -f '$DOTFILES_ROOT/scripts/hooks/checkpoint-pre-prompt.sh' ]"

    # Old hooks removed from settings.json
    run_test "No checkpoint-pre-prompt in settings" "! grep -q 'checkpoint-pre-prompt' '$DOTFILES_ROOT/.claude/settings.json'"
    run_test "No checkpoint-capture in settings" "! grep -q 'checkpoint-capture' '$DOTFILES_ROOT/.claude/settings.json'"

    # .gitignore updated
    run_test ".gitignore has .entire/" "grep -q '\.entire/' '$DOTFILES_ROOT/.gitignore'"
    run_test ".gitignore no .checkpoints/" "! grep -q '\.checkpoints/' '$DOTFILES_ROOT/.gitignore'"

    # git-fzf uses entire explain
    run_test "git-fzf uses entire explain" "grep -q 'entire explain' '$DOTFILES_ROOT/.config/fish/functions/git-fzf-actions.fish'"
    run_test "git-fzf no old checkpoints.sh show" "! grep -q 'checkpoints.sh show' '$DOTFILES_ROOT/.config/fish/functions/git-fzf-actions.fish'"

    # worktree-witness uses entire
    run_test "worktree-witness uses entire" "grep -q 'entire resume' '$DOTFILES_ROOT/scripts/worktree-witness.sh'"
    run_test "worktree-witness no old checkpoints.sh" "! grep -q 'ckpt_script.*checkpoints.sh' '$DOTFILES_ROOT/scripts/worktree-witness.sh'"

    # CLAUDE.md documentation updated
    run_test "CLAUDE.md mentions entireio/cli" "grep -q 'entireio/cli' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md mentions entire enable" "grep -q 'entire enable' '$DOTFILES_ROOT/CLAUDE.md'"

    # Phase 1: Project configuration
    run_test ".entire/settings.json exists" "[ -f '$DOTFILES_ROOT/.entire/settings.json' ]"
    run_test ".entire/settings.json has enabled key" "jq -e '.enabled' '$DOTFILES_ROOT/.entire/settings.json' >/dev/null 2>&1"
    run_test ".entire/settings.json has commit_linking" "jq -e '.commit_linking' '$DOTFILES_ROOT/.entire/settings.json' >/dev/null 2>&1"
    run_test ".entire/settings.json has telemetry=false" "[ \"\$(jq -r '.telemetry' '$DOTFILES_ROOT/.entire/settings.json')\" = 'false' ]"
    run_test ".gitignore carve-out for settings.json" "grep -q '!\.entire/settings\.json' '$DOTFILES_ROOT/.gitignore'"

    # Phase 2: Enhanced checkpoints.fish subcommands
    run_test "checkpoints.fish has attribution case" "grep -q 'case attribution' '$DOTFILES_ROOT/.config/fish/functions/checkpoints.fish'"
    run_test "checkpoints.fish has generate case" "grep -q 'case generate' '$DOTFILES_ROOT/.config/fish/functions/checkpoints.fish'"
    run_test "checkpoints.fish has explain case" "grep -q 'case explain' '$DOTFILES_ROOT/.config/fish/functions/checkpoints.fish'"

    # Phase 3: Attribution bindings in FZF browsers
    run_test "Commit browser has ALT-A attribution" "grep -q 'alt-a:change-preview' '$DOTFILES_ROOT/.config/fish/functions/git-fzf-actions.fish'"
    run_test "Checkpoint browser has ALT-A attribution" "grep -c 'alt-a:change-preview' '$DOTFILES_ROOT/.config/fish/functions/git-fzf-actions.fish' | grep -q '2'"

    # Phase 4: Multi-agent support in gwt-ticket
    run_test "gwt-ticket supports --ckpt-agent" "grep -q 'ckpt-agent' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket passes --agent to entire" "grep -q '\-\-agent.*ckpt_agent' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    # Phase 5: Checkpoint browser uses entire rewind --list
    run_test "Checkpoint browser tries entire rewind --list" "grep -q 'entire rewind --list' '$DOTFILES_ROOT/.config/fish/functions/git-fzf-actions.fish'"

    # Phase 6: Documentation
    run_test "CLAUDE.md documents ckpt-agent flag" "grep -q 'ckpt-agent' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents attribution subcommand" "grep -q 'attribution' '$DOTFILES_ROOT/CLAUDE.md'"
}

test_opencode() {
    echo -e "${BLUE}--- OpenCode Tests ---${NC}"

    run_test "OpenCode config exists" "[ -f '$DOTFILES_ROOT/.config/opencode/opencode.json' ]"
    run_test "OpenCode config is valid JSON" "jq empty '$DOTFILES_ROOT/.config/opencode/opencode.json'"
    run_test "OpenCode permissions are blanket allow" "[ \"\$(jq -r '.permission' '$DOTFILES_ROOT/.config/opencode/opencode.json')\" = 'allow' ]"
    run_test "OpenCode config has openai provider" "jq -e '.provider.openai' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode config has gpt-5.1-codex model" "jq -e '.provider.openai.models[\"gpt-5.1-codex\"]' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"

    run_test "OpenCode command directory exists" "[ -d '$DOTFILES_ROOT/.opencode/command' ]"
    run_test "OpenCode doctor command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/doctor.md' ]"
    run_test "OpenCode review command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/review-changes.md' ]"
    run_test "OpenCode fix command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/fix-dotfiles.md' ]"

    run_test "OpenCode agents directory exists" "[ -d '$DOTFILES_ROOT/.opencode/agents' ]"
    run_test "OpenCode review agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/dotfiles-review.md' ]"
    run_test "OpenCode debug agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/dotfiles-debug.md' ]"

    run_test "OpenCode entire plugin exists" "[ -f '$DOTFILES_ROOT/.opencode/plugins/entire.ts' ]"
    run_test "OpenCode project env plugin exists" "[ -f '$DOTFILES_ROOT/.opencode/plugins/project-env.ts' ]"
    run_test "OpenCode project env plugin sets CLAUDE_PROJECT_DIR" "grep -q 'CLAUDE_PROJECT_DIR' '$DOTFILES_ROOT/.opencode/plugins/project-env.ts'"
    run_test "OpenCode tmux status plugin exists" "[ -f '$DOTFILES_ROOT/.opencode/plugins/tmux-status.ts' ]"

    run_test "OpenCode model routing config exists" "[ -f '$DOTFILES_ROOT/.opencode/model-routing.json' ]"
    run_test "OpenCode model routing config is valid JSON" "jq empty '$DOTFILES_ROOT/.opencode/model-routing.json'"
    run_test "OpenCode model routing has presets" "jq -e '.presets | length > 0' '$DOTFILES_ROOT/.opencode/model-routing.json' >/dev/null 2>&1"

    run_test "OpenCode route command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/route.md' ]"
    run_test "OpenCode worktree-status command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/worktree-status.md' ]"
    run_test "OpenCode sync-beads command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/sync-beads.md' ]"

    run_test "OpenCode doctor script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/doctor.sh' ]"
    run_test "OpenCode doctor script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/doctor.sh'"
    run_test "OpenCode doctor fish wrapper exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/opencode-doctor.fish' ]"
    run_test "OpenCode doctor fish wrapper syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/opencode-doctor.fish'"

    run_test "gwt-ticket has OpenCode doctor preflight" "grep -q 'opencode/doctor.sh' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    run_test "OpenCode usage-check script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/usage-check.sh' ]"
    run_test "OpenCode usage-check script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/usage-check.sh' ]"
    run_test "OpenCode usage-check script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/usage-check.sh'"

    run_test "OpenCode accounts fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/opencode-accounts.fish' ]"
    run_test "OpenCode accounts fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/opencode-accounts.fish'"
    run_test "OpenCode accounts has check-and-rotate" "grep -q 'check-and-rotate' '$DOTFILES_ROOT/.config/fish/functions/opencode-accounts.fish'"

    run_test "gwt-ticket has usage-check preflight" "grep -q 'usage-check.sh' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    run_test "OpenCode npm plugins configured" "jq -e '.plugin | length > 0' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode DCP plugin configured" "jq -e '.plugin[] | select(contains(\"dcp\"))' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode PTY plugin configured" "jq -e '.plugin[] | select(contains(\"pty\"))' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode VibeGuard plugin configured" "jq -e '.plugin[] | select(contains(\"vibeguard\"))' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode DCP config exists" "[ -f '$DOTFILES_ROOT/.opencode/dcp.jsonc' ]"
    run_test "OpenCode VibeGuard config exists" "[ -f '$DOTFILES_ROOT/.opencode/vibeguard.config.json' ]"
    run_test "OpenCode VibeGuard enabled" "jq -e '.enabled == true' '$DOTFILES_ROOT/.opencode/vibeguard.config.json' >/dev/null 2>&1"
}

test_subagents() {
    echo -e "${BLUE}--- Claude Code Subagent Tests ---${NC}"

    # Agents directory exists
    run_test "Agents directory exists" "[ -d '$DOTFILES_ROOT/.claude/agents' ]"

    # All 12 AGENTS.md-referenced agents exist
    for agent in architect frontend backend security performance analyzer qa refactorer devops devops-security-auditor mentor scribe; do
        run_test "Agent file: $agent.md exists" "[ -f '$DOTFILES_ROOT/.claude/agents/$agent.md' ]"
    done

    # Project-specific agents exist
    for agent in shell-expert test-runner dotfiles-doctor; do
        run_test "Project agent: $agent.md exists" "[ -f '$DOTFILES_ROOT/.claude/agents/$agent.md' ]"
    done

    # Validate each agent file has required frontmatter fields
    for agent_file in "$DOTFILES_ROOT"/.claude/agents/*.md; do
        if [ -f "$agent_file" ]; then
            local name
            name=$(basename "$agent_file" .md)

            # Has YAML frontmatter delimiters
            run_test "Agent $name has frontmatter" "head -1 '$agent_file' | grep -q '^---$'"

            # Has required 'name' field
            run_test "Agent $name has name field" "grep -q '^name:' '$agent_file'"

            # Has required 'description' field
            run_test "Agent $name has description field" "grep -q '^description:' '$agent_file'"

            # Name field matches filename
            run_test "Agent $name name matches filename" "grep -q \"^name: $name\" '$agent_file'"

            # Description is non-empty (at least 10 chars after 'description: ')
            run_test "Agent $name description non-empty" "grep '^description:' '$agent_file' | sed 's/^description: //' | grep -qE '.{10,}'"

            # Has a system prompt body (content after closing ---)
            run_test "Agent $name has system prompt" "awk '/^---$/{c++}c==2{found=1;exit}END{exit !found}' '$agent_file'"

            # Model field is valid if present
            if grep -q '^model:' "$agent_file"; then
                run_test "Agent $name model is valid" "grep '^model:' '$agent_file' | grep -qE '(inherit|sonnet|opus|haiku)'"
            fi

            # Tools field has valid tool names if present
            if grep -q '^tools:' "$agent_file"; then
                run_test "Agent $name tools field valid" "grep '^tools:' '$agent_file' | grep -qE '(Read|Write|Edit|Bash|Grep|Glob)'"
            fi

            # maxTurns field is a positive integer if present
            if grep -q '^maxTurns:' "$agent_file"; then
                run_test "Agent $name maxTurns is positive integer" "grep '^maxTurns:' '$agent_file' | grep -qE '^maxTurns: [0-9]+$'"
            fi

            # skills field references existing skills if present
            if grep -q '^skills:' "$agent_file"; then
                local skills_valid=true
                for skill_name in $(grep '^skills:' "$agent_file" | sed 's/^skills: //' | tr ',' '\n' | sed 's/^ *//;s/ *$//'); do
                    if [ ! -d "$DOTFILES_ROOT/.claude/skills/$skill_name" ]; then
                        skills_valid=false
                    fi
                done
                run_test "Agent $name skills reference existing skills" "$skills_valid"
            fi

            # mcpServers field is non-empty if present
            if grep -q '^mcpServers:' "$agent_file"; then
                run_test "Agent $name mcpServers non-empty" "grep '^mcpServers:' '$agent_file' | grep -qE '^mcpServers: .+'"
            fi

            # memory field is valid scope if present
            if grep -q '^memory:' "$agent_file"; then
                run_test "Agent $name memory scope valid" "grep '^memory:' '$agent_file' | grep -qE '(user|project|local)'"
            fi

            # background field is boolean if present
            if grep -q '^background:' "$agent_file"; then
                run_test "Agent $name background is boolean" "grep '^background:' '$agent_file' | grep -qE '(true|false)'"
            fi
        fi
    done

    # Specific agent enhancements from official docs
    run_test "architect has memory: project" "grep -q '^memory: project' '$DOTFILES_ROOT/.claude/agents/architect.md'"
    run_test "architect has mcpServers" "grep -q '^mcpServers:' '$DOTFILES_ROOT/.claude/agents/architect.md'"
    run_test "test-runner has background: true" "grep -q '^background: true' '$DOTFILES_ROOT/.claude/agents/test-runner.md'"
    run_test "test-runner has maxTurns" "grep -q '^maxTurns:' '$DOTFILES_ROOT/.claude/agents/test-runner.md'"
    run_test "dotfiles-doctor has maxTurns" "grep -q '^maxTurns:' '$DOTFILES_ROOT/.claude/agents/dotfiles-doctor.md'"
    run_test "mentor has maxTurns" "grep -q '^maxTurns:' '$DOTFILES_ROOT/.claude/agents/mentor.md'"
    run_test "mentor has mcpServers" "grep -q '^mcpServers:' '$DOTFILES_ROOT/.claude/agents/mentor.md'"
    run_test "shell-expert has skills" "grep -q '^skills:' '$DOTFILES_ROOT/.claude/agents/shell-expert.md'"

    # SubagentStart/SubagentStop hooks in settings.json
    if [ -f "$DOTFILES_ROOT/.claude/settings.json" ]; then
        run_test "settings.json has SubagentStart hook" "grep -q 'SubagentStart' '$DOTFILES_ROOT/.claude/settings.json'"
        run_test "settings.json has SubagentStop hook" "grep -q 'SubagentStop' '$DOTFILES_ROOT/.claude/settings.json'"
    fi

    # AGENTS.md links should resolve to actual files
    if [ -f "$DOTFILES_ROOT/.claude/AGENTS.md" ]; then
        local broken_links=0
        while IFS= read -r link; do
            local target="$DOTFILES_ROOT/.claude/$link"
            if [ ! -f "$target" ]; then
                broken_links=$((broken_links + 1))
            fi
        done < <(grep -oE 'agents/[a-z-]+\.md' "$DOTFILES_ROOT/.claude/AGENTS.md" | sort -u)
        run_test "AGENTS.md has no broken agent links" "[ '$broken_links' -eq 0 ]"
    fi
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

test_integrations() {
    echo -e "${BLUE}--- Third-Party Integrations Tests ---${NC}"

    # Fish function
    run_test "cc-provider Fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/cc-provider.fish' ]"
    if command -v fish &>/dev/null; then
        run_test "cc-provider Fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/cc-provider.fish'"
        run_test "cc-provider function loads" "fish -c 'source $DOTFILES_ROOT/.config/fish/functions/cc-provider.fish && functions -q cc-provider'"
    fi

    # Template script
    run_test "Provider template script exists" "[ -f '$DOTFILES_ROOT/scripts/cc-provider-templates.sh' ]"
    run_test "Provider template script executable" "[ -x '$DOTFILES_ROOT/scripts/cc-provider-templates.sh' ]"
    run_test "Provider template script valid bash" "bash -n '$DOTFILES_ROOT/scripts/cc-provider-templates.sh'"

    # Template generation
    local tmp_conf="/tmp/test-cc-provider-$$.conf"
    for provider in bedrock vertex foundry gateway; do
        run_test "Template generates $provider profile" "'$DOTFILES_ROOT/scripts/cc-provider-templates.sh' $provider '$tmp_conf' && [ -s '$tmp_conf' ]"
        run_test "$provider template has provider comment" "grep -q '# provider: $provider' '$tmp_conf'"
        rm -f "$tmp_conf" 2>/dev/null
    done

    # Documentation
    run_test "Third-party integrations doc exists" "[ -f '$DOTFILES_ROOT/docs/third-party-integrations.md' ]"
    run_test "Doc covers Bedrock" "grep -q 'Amazon Bedrock' '$DOTFILES_ROOT/docs/third-party-integrations.md'"
    run_test "Doc covers Vertex" "grep -q 'Google Vertex' '$DOTFILES_ROOT/docs/third-party-integrations.md'"
    run_test "Doc covers Foundry" "grep -q 'Microsoft Foundry' '$DOTFILES_ROOT/docs/third-party-integrations.md'"
    run_test "Doc covers LLM Gateway" "grep -q 'LLM Gateway' '$DOTFILES_ROOT/docs/third-party-integrations.md'"
    run_test "Doc covers mTLS" "grep -q 'mTLS' '$DOTFILES_ROOT/docs/third-party-integrations.md'"

    # Setup.sh integration
    run_test "setup.sh references provider profiles" "grep -q 'cc-provider' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh creates providers directory" "grep -q 'providers' '$DOTFILES_ROOT/scripts/setup.sh'"

    # CLAUDE.md integration
    run_test "CLAUDE.md documents cc-provider" "grep -q 'cc-provider' '$DOTFILES_ROOT/CLAUDE.md'"

    # gwt-ticket --provider integration
    run_test "gwt-ticket has --provider flag" "grep -q '\-\-provider' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket --provider parses conf file" "grep -q 'provider_profile' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket --provider in help text" "grep -q 'provider.*bedrock.*vertex.*foundry' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket --provider in examples" "grep -q 'provider bedrock' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    rm -f "$tmp_conf" 2>/dev/null
}

test_gitattributes() {
    echo -e "${BLUE}--- Gitattributes Tests ---${NC}"
    run_test ".gitattributes exists" "[ -f '$DOTFILES_ROOT/.gitattributes' ]"
    run_test "JSON diff driver script exists" "[ -x '$DOTFILES_ROOT/scripts/git-diff-json.sh' ]"
    run_test "Union merge driver script exists" "[ -x '$DOTFILES_ROOT/scripts/merge-driver-union.sh' ]"

    # Verify key attributes are applied
    run_test "CLAUDE.md has union-doc merge" "git -C '$DOTFILES_ROOT' check-attr merge -- CLAUDE.md | grep -q 'union-doc'"
    run_test "Shell scripts enforce LF" "git -C '$DOTFILES_ROOT' check-attr eol -- scripts/setup.sh | grep -q 'lf'"
    run_test "Fish files enforce LF" "git -C '$DOTFILES_ROOT' check-attr eol -- .config/fish/config.fish | grep -q 'lf'"
    run_test "PNG files marked binary" "git -C '$DOTFILES_ROOT' check-attr binary -- generated-diagrams/diagram_335a360a.png | grep -q 'set'"
    run_test "JSON files use json diff driver" "git -C '$DOTFILES_ROOT' check-attr diff -- .config/vscode/settings.json | grep -q 'json'"
    run_test "Plist files use plist diff driver" "git -C '$DOTFILES_ROOT' check-attr diff -- Library/LaunchAgents/com.user.ssh-add.plist | grep -q 'plist'"

    # Verify JSON diff driver produces valid output
    run_test "JSON diff driver produces sorted output" "bash '$DOTFILES_ROOT/scripts/git-diff-json.sh' '$DOTFILES_ROOT/.config/vscode/settings.json' | head -1 | grep -q '{'"

    # Verify merge drivers are assigned
    run_test "Brewfile uses brewfile merge driver" "git -C '$DOTFILES_ROOT' check-attr merge -- homebrew/Brewfile | grep -q 'brewfile'"
    run_test "settings.json uses json-merge driver" "git -C '$DOTFILES_ROOT' check-attr merge -- .claude/settings.json | grep -q 'json-merge'"
    run_test "config.fish uses union-doc merge" "git -C '$DOTFILES_ROOT' check-attr merge -- .config/fish/config.fish | grep -q 'union-doc'"
    run_test "test-filter.sh uses union-doc merge" "git -C '$DOTFILES_ROOT' check-attr merge -- scripts/test-filter.sh | grep -q 'union-doc'"
    run_test "lazy-lock.json uses lockfile merge" "git -C '$DOTFILES_ROOT' check-attr merge -- .config/nvim/lazy-lock.json | grep -q 'lockfile'"

    # Verify merge driver scripts exist and are executable
    run_test "Brewfile merge driver exists" "[ -x '$DOTFILES_ROOT/scripts/merge-driver-brewfile.sh' ]"
    run_test "JSON merge driver exists" "[ -x '$DOTFILES_ROOT/scripts/merge-driver-json.sh' ]"
    run_test "Lockfile merge driver exists" "[ -x '$DOTFILES_ROOT/scripts/merge-driver-lockfile.sh' ]"

    # Verify setup.sh registers all drivers
    run_test "setup.sh registers JSON diff driver" "grep -q 'diff.json.textconv' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh registers plist diff driver" "grep -q 'diff.plist.textconv' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh registers union-doc merge driver" "grep -q 'merge.union-doc.driver' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh registers brewfile merge driver" "grep -q 'merge.brewfile.driver' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh registers json-merge driver" "grep -q 'merge.json-merge.driver' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh registers lockfile merge driver" "grep -q 'merge.lockfile.driver' '$DOTFILES_ROOT/scripts/setup.sh'"
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
--list | -l)
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
subagents) test_subagents ;;
cd-perf) test_cd_perf ;;
lsp) test_lsp ;;
nvim-bridge) test_nvim_bridge ;;
remote-control) test_remote_control ;;
settings) test_settings ;;
entire) test_entire ;;
gitattributes) test_gitattributes ;;
merge-driver) bash "$SCRIPT_DIR/tests/test-merge-driver.sh" ;;
openclaw) bash "$SCRIPT_DIR/openclaw/test-openclaw.sh" ;;
integrations) test_integrations ;;
opencode) test_opencode ;;
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
    test_subagents
    test_cd_perf
    test_lsp
    test_nvim_bridge
    test_remote_control
    test_settings
    test_entire
    test_integrations
    test_opencode
    test_gitattributes
    # OpenClaw tests run from their own script (separate counters)
    # External test suites run as subprocesses (own set -e / counters)
    bash "$SCRIPT_DIR/tests/test-merge-driver.sh"
    echo ""
    bash "$SCRIPT_DIR/openclaw/test-openclaw.sh"
    ;;
*)
    echo "Unknown test group: $GROUP"
    echo ""
    list_groups
    exit 1
    ;;
esac

print_summary
