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
    if command -v fish &>/dev/null; then
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
            local name=$(basename "$hook")
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
cd-perf) test_cd_perf ;;
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
    test_cd_perf
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
