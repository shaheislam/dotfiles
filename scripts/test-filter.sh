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
    echo "  gemini        - Gemini CLI docs, setup wiring, and package checks"
    echo "  pi            - Pi coding agent config, theme, packages, and setup wiring"
    echo "  setup-syntax  - setup.sh bash syntax validation"
    echo "  brewfile      - Brewfile structure and duplicates"
    echo "  mcp           - MCP server configuration parity"
    echo "  browser       - Browser automation config and wiring"
    echo "  tmux          - tmux configuration"
    echo "  hooks         - Agent harness hooks (Claude-compatible)"
    echo "  agents-md     - AGENTS.md file validation"
    echo "  cd-perf       - CD performance optimizations"
    echo "  lsp           - Claude Code LSP integration"
    echo "  nvim-bridge   - Neovim Agent bridge"
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
    for func in gwt-dev gwt-ticket gwt-parallel gwt-status devcon pihole tmux-main; do
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
        run_test "Fish function syntax valid" "for f in '$DOTFILES_ROOT'/.config/fish/functions/*.fish; do fish -n \"\$f\" || exit 1; done"
        run_test "Fish completion syntax valid" "for f in '$DOTFILES_ROOT'/.config/fish/completions/*.fish; do fish -n \"\$f\" || exit 1; done"
        run_test "Fish conf.d syntax valid" "for f in '$DOTFILES_ROOT'/.config/fish/conf.d/*.fish; do fish -n \"\$f\" || exit 1; done"
        # Validate tab completion function syntax
        for func in _cd_fzf_tab_complete _fifc_or_fzf; do
            run_test "Fish function $func syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/$func.fish'"
        done
        for func in _codex_workspace_id codex-accounts codex-rotate tmux-main; do
            run_test "Fish function $func syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/$func.fish'"
        done
        run_test "Fish gwt-doctor omits removed tmux watcher" "! grep -q 'tmux-claude-watcher' '$DOTFILES_ROOT/.config/fish/functions/gwt-doctor.fish'"
        run_test "Fish gwt-doctor checks native agent colors" "grep -q '@wname_style' '$DOTFILES_ROOT/.config/fish/functions/gwt-doctor.fish'"
        # Validate _cd_fzf_tab_complete loads and is queryable
        run_test "Fish _cd_fzf_tab_complete loads" "fish -c 'source $DOTFILES_ROOT/.config/fish/functions/_cd_fzf_tab_complete.fish && functions -q _cd_fzf_tab_complete'"
        run_test "Fish tmux-main loads" "fish -c 'source $DOTFILES_ROOT/.config/fish/functions/tmux-main.fish && functions -q tmux-main'"
        run_test "Fish kubectl lazy completion loads native helpers" "fish --no-config -c 'source $DOTFILES_ROOT/.config/fish/completions/kubectl.fish; complete -C \"kubectl get \" >/dev/null 2>&1; functions -q __fish_kubectl_print_resource_types'"
        run_test "Fish kubectl FZF loads native helpers" "fish --no-config -c 'source $DOTFILES_ROOT/.config/fish/functions/_kubectl_fzf_native_full.fish; __kubectl_fzf_load_native_helpers; and functions -q __fish_kubectl_print_resource_types; and set -q FISH_KUBECTL_COMPLETION_COMPLETE_CRDS; and set -q __fish_kubectl_resources; and set -g FISH_KUBECTL_COMPLETION_COMPLETE_CRDS 0; and __fish_kubectl_print_resource_types >/dev/null'"
        run_test "Fish Docker FZF handles missing helper" "fish --no-config -c 'set -l out (mktemp); set -l err (mktemp); set -g fish_function_path $DOTFILES_ROOT/.config/fish/functions \$fish_function_path; source $DOTFILES_ROOT/.config/fish/completions/docker-fzf.fish; source $DOTFILES_ROOT/.config/fish/functions/_docker_fzf_tab_complete.fish; complete -C \"docker ps \" >\$out 2>\$err; set -l rc \$status; set -l ok 1; test \$rc -eq 0; and not test -s \$err; and set ok 0; rm -f \$out \$err; exit \$ok'"
        run_test "Fish git FZF helper lazy-loads" "fish --no-config -c 'set -g fish_function_path $DOTFILES_ROOT/.config/fish/functions \$fish_function_path; source $DOTFILES_ROOT/.config/fish/functions/_git_fzf_tab_complete.fish; functions -e __fzf_git_sh; __git_fzf_load_helper; and functions -q __fzf_git_sh'"
        run_test "Fish git pull remote branch helper exists" "fish --no-config -c 'source $DOTFILES_ROOT/.config/fish/completions/git.fish; functions -q __fish_git_pull_remote_branches'"
        run_test "Fish git completion preserves builtin helper" "fish --no-config -c 'set -l before (functions --details __fish_seen_argument); source $DOTFILES_ROOT/.config/fish/completions/git.fish; set -l after (functions --details __fish_seen_argument); test \"\$before\" = \"\$after\"; and functions -q __fish_git_seen_argument'"
        run_test "Fish git completion preserves builtin commands" "fish --no-config -c 'source $DOTFILES_ROOT/.config/fish/completions/git.fish; set -l out (complete -C \"git config --\"); test (count \$out) -gt 0'"
        run_test "Fish git completion does not erase builtins" "! grep -q 'complete -c git -e' '$DOTFILES_ROOT/.config/fish/completions/git.fish'"
        run_test "Fish command-not-found fallback is safe" "fish --no-config -c 'source $DOTFILES_ROOT/.config/fish/functions/fish_command_not_found.fish; fish_command_not_found definitely_missing_command >/dev/null 2>&1; test \$status -eq 127'"
        run_test "Fish helm lazy loader uses repo implementation" "grep -q '(status dirname)/_helm_fzf_native_full.fish' '$DOTFILES_ROOT/.config/fish/functions/helm_fzf_native.fish'"
        run_test "Fish helm diff completion handled" "grep -q 'case diff' '$DOTFILES_ROOT/.config/fish/functions/_helm_fzf_native_full.fish' && grep -q 'upgrade revision release rollback' '$DOTFILES_ROOT/.config/fish/functions/_helm_fzf_native_full.fish'"
        run_test "Fish helm diff subflows continue" "grep -q 'case upgrade release' '$DOTFILES_ROOT/.config/fish/functions/_helm_fzf_native_full.fish' && grep -q 'case revision rollback' '$DOTFILES_ROOT/.config/fish/functions/_helm_fzf_native_full.fish' && grep -q '__helm_revision_select \$resource' '$DOTFILES_ROOT/.config/fish/functions/_helm_fzf_native_full.fish'"
        run_test "Fish ECS tab completion inserts selections" "grep -q '__ecs_fzf_insert' '$DOTFILES_ROOT/.config/fish/functions/_ecs_fzf_tab_complete.fish' && ! grep -nE '^[[:space:]]*echo \\$' '$DOTFILES_ROOT/.config/fish/functions/_ecs_fzf_tab_complete.fish'"
        run_test "Fish stern fallback completions exist" "fish --no-config -c 'source $DOTFILES_ROOT/.config/fish/completions/stern.fish; set -l out (complete -C \"stern --\"); test (count \$out) -gt 0'"
        run_test "Fish stern kubie action is guarded" "grep -q 'if command -q kubie' '$DOTFILES_ROOT/.config/fish/functions/_stern_fzf_tab_complete.fish'"
        run_test "Fish Claude resume completion is read-only" "! grep -nE '(^|[[:space:]])(mkdir|ln -s)([[:space:]]|$)' '$DOTFILES_ROOT/.config/fish/functions/_claude_resume_fzf_tab_complete.fish'"
        run_test "Fish labctl completion avoids eval" "! grep -nE '(^|[[:space:]])eval([[:space:]]|$)' '$DOTFILES_ROOT/.config/fish/completions/labctl.fish'"
        run_test "Fish carapace FZF miss is quiet" "! grep -q 'No completions available' '$DOTFILES_ROOT/.config/fish/functions/carapace_fzf_complete.fish'"
        run_test "Fish cloud completions guard dependencies" "grep -q 'command -q aws' '$DOTFILES_ROOT/.config/fish/functions/__fish_complete_aws_profiles.fish' && grep -q 'command -q aws' '$DOTFILES_ROOT/.config/fish/functions/__fish_complete_aws_s3_buckets.fish' && grep -q 'command -q kubectl' '$DOTFILES_ROOT/.config/fish/completions/kns.fish'"
    fi

    run_test "WezTerm auto-attach uses tmux-main helper" \
        "grep -q 'tmux-main' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "WezTerm auto-attach exits only after tmux-main succeeds" \
        "grep -A3 'tmux-main' '$DOTFILES_ROOT/.config/fish/config.fish' | grep -q 'if test .*status -eq 0'"
    run_test "tmux-main removes stale default socket before retry" \
        "grep -q 'socket_path' '$DOTFILES_ROOT/.config/fish/functions/tmux-main.fish' && grep -q 'rm -f \"' '$DOTFILES_ROOT/.config/fish/functions/tmux-main.fish' && grep -q 'tmux ls >/dev/null 2>&1' '$DOTFILES_ROOT/.config/fish/functions/tmux-main.fish'"
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
    run_test "Claude wrapper fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/claude.fish' ]"
    run_test "Claude rotation script exists" "[ -f '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh' ]"
    run_test "Claude rotation script executable" "[ -x '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh' ]"
    run_test "Claude rotation script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh'"
    run_test "Claude rotation uses usage checker" "grep -q 'CLAUDE_USAGE_CHECK_SCRIPT' '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh'"
    run_test "Claude rotation prefers native binary" "grep -q '\$HOME/.local/bin/claude' '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh'"
    run_test "Claude rotation tracks last profile" "grep -q 'last-profile' '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh'"
    run_test "Claude rotation detects limit message" "grep -q '/extra-usage' '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh'"
    run_test "Claude wrapper delegates to rotation script" "grep -q 'run-with-rotation.sh' '$DOTFILES_ROOT/.config/fish/functions/claude.fish'"
    run_test "Claude wrapper keeps print mode passthrough" "grep -q '\-p --print' '$DOTFILES_ROOT/.config/fish/functions/claude.fish'"
    run_test "Claude wrapper skips self-resolving symlinks" "grep -q 'candidate_real=.*canonicalize_path' '$DOTFILES_ROOT/scripts/bin/claude' && grep -q 'SELF_PATH=' '$DOTFILES_ROOT/scripts/bin/claude'"
    run_test "claude-sub login bypasses rotation" "grep -q 'CLAUDE_ROTATE_DISABLE=1 CLAUDE_CONFIG_DIR=.*command claude' '$DOTFILES_ROOT/.config/fish/functions/claude-sub.fish'"
    if command -v fish &>/dev/null; then
        run_test "Claude wrapper fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/claude.fish'"
        run_test "Claude wrapper loads" "fish -c 'source $DOTFILES_ROOT/.config/fish/functions/claude.fish && functions -q claude'"
        run_test "Claude wrapper smoke test" "fish -c 'set -gx CLAUDE_BIN /usr/bin/true; set -gx CLAUDE_USAGE_CHECK_SCRIPT /no/such/script; source $DOTFILES_ROOT/.config/fish/functions/claude.fish; claude test-prompt' >/dev/null"
    fi
    if command -v shellcheck &>/dev/null; then
        run_test "Claude rotation script passes ShellCheck" "shellcheck '$DOTFILES_ROOT/scripts/claude/run-with-rotation.sh'"
        run_test "test-filter.sh passes ShellCheck" "shellcheck '$DOTFILES_ROOT/scripts/test-filter.sh'"
    fi
}

test_gemini() {
    echo -e "${BLUE}--- Gemini CLI Tests ---${NC}"
    run_test "GEMINI.md exists" "[ -f '$DOTFILES_ROOT/GEMINI.md' ]"
    run_test "GEMINI.md documents canonical instruction source" "grep -q 'canonical instruction file' '$DOTFILES_ROOT/GEMINI.md'"
    run_test "GEMINI.md distinguishes Claude and OpenCode sources" "grep -q 'OpenCode follows' '$DOTFILES_ROOT/GEMINI.md'"
    run_test "Brewfile includes gemini-cli" "grep -q 'brew \"gemini-cli\"' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "setup.sh verifies Gemini CLI" "grep -q 'Verifying Gemini CLI' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "GEMINI.md references filtered Gemini tests" "grep -q 'scripts/test-filter.sh gemini' '$DOTFILES_ROOT/GEMINI.md'"
    run_test "tools.md documents Gemini CLI" "grep -q 'Gemini CLI' '$DOTFILES_ROOT/tools.md'"
    if command -v shellcheck &>/dev/null; then
        run_test "test-filter.sh passes ShellCheck" "shellcheck '$DOTFILES_ROOT/scripts/test-filter.sh'"
    fi
}

test_pi() {
    echo -e "${BLUE}--- Pi Coding Agent Tests ---${NC}"
    local pi_root="$DOTFILES_ROOT/.pi/agent"
    local required_theme_keys="accent border borderAccent borderMuted success error warning muted dim text thinkingText selectedBg userMessageBg userMessageText customMessageBg customMessageText customMessageLabel toolPendingBg toolSuccessBg toolErrorBg toolTitle toolOutput mdHeading mdLink mdLinkUrl mdCode mdCodeBlock mdCodeBlockBorder mdQuote mdQuoteBorder mdHr mdListBullet toolDiffAdded toolDiffRemoved toolDiffContext syntaxComment syntaxKeyword syntaxFunction syntaxVariable syntaxString syntaxNumber syntaxType syntaxOperator syntaxPunctuation thinkingOff thinkingMinimal thinkingLow thinkingMedium thinkingHigh thinkingXhigh bashMode"

    run_test ".pi/agent settings exists" "[ -f '$pi_root/settings.json' ]"
    run_test ".pi/agent keybindings exists" "[ -f '$pi_root/keybindings.json' ]"
    run_test ".pi/agent transparent theme exists" "[ -f '$pi_root/themes/transparent.json' ]"
    run_test ".pi/agent AGENTS.md exists" "[ -f '$pi_root/AGENTS.md' ]"
    run_test "Pi settings JSON valid" "python3 -c \"import json; json.load(open('$pi_root/settings.json'))\""
    run_test "Pi keybindings JSON valid" "python3 -c \"import json; json.load(open('$pi_root/keybindings.json'))\""
    run_test "Pi transparent theme JSON valid" "python3 -c \"import json; json.load(open('$pi_root/themes/transparent.json'))\""
    run_test "Pi settings selects transparent theme" "python3 -c \"import json; data=json.load(open('$pi_root/settings.json')); assert data.get('theme') == 'transparent'\""
    run_test "Pi settings enables skill commands" "python3 -c \"import json; data=json.load(open('$pi_root/settings.json')); assert data.get('enableSkillCommands') is True\""
    run_test "Pi settings includes curated packages" "python3 -c \"import json; pkgs=json.load(open('$pi_root/settings.json')).get('packages', []); required={'npm:context-mode','npm:pi-mcp-adapter','npm:pi-subagents','npm:pi-web-access','npm:@juicesharp/rpiv-ask-user-question','npm:@juicesharp/rpiv-todo','npm:pi-simplify'}; assert required <= set(pkgs)\""
    run_test "Pi transparent theme has required keys" "python3 -c \"import json; data=json.load(open('$pi_root/themes/transparent.json')); required=set('$required_theme_keys'.split()); assert data.get('name') == 'transparent'; assert required <= set(data.get('colors', {}))\""
    run_test "Pi transparent theme uses terminal passthrough backgrounds" "python3 -c \"import json; colors=json.load(open('$pi_root/themes/transparent.json'))['colors']; assert colors['userMessageBg'] == ''; assert colors['customMessageBg'] == ''; assert colors['toolPendingBg'] == ''\""
    run_test "Skill sync targets Pi" "grep -q '\.pi/agent/skills' '$DOTFILES_ROOT/scripts/sync-skills-harnesses.sh'"
    run_test "Skills profile tests include Pi surface" "grep -q '\.pi/agent/skills' '$DOTFILES_ROOT/scripts/test-skills-profile.sh'"
    run_test "Brewfile documents Pi install" "grep -q 'Pi coding agent' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "setup.sh installs Pi via bun" "grep -q '@earendil-works/pi-coding-agent@latest' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh verifies Pi CLI" "grep -q 'Pi coding agent verified' '$DOTFILES_ROOT/scripts/setup.sh'"
    if command -v shellcheck &>/dev/null; then
        run_test "test-filter.sh passes ShellCheck" "shellcheck '$DOTFILES_ROOT/scripts/test-filter.sh'"
    fi
}

test_setup_syntax() {
    echo -e "${BLUE}--- Setup Script Syntax Tests ---${NC}"
    run_test "setup.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "smoke-test.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/smoke-test.sh'"
    run_test "firefox-setup.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh'"
    run_test "firefox-capture-prefs.py syntax valid" "python3 -m py_compile '$DOTFILES_ROOT/scripts/setup/firefox-capture-prefs.py'"
    run_test "fluidvoice-setup.sh syntax valid" "bash -n '$DOTFILES_ROOT/scripts/setup/fluidvoice-setup.sh'"
    run_test "fluidvoice-config.py syntax valid" "python3 -m py_compile '$DOTFILES_ROOT/scripts/setup/fluidvoice-config.py'"
    run_test "failed LaunchAgent plists removed" "[ ! -e '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.agent-monitor.plist' ] && [ ! -e '$DOTFILES_ROOT/Library/LaunchAgents/com.kubectl-fzf-server.plist' ] && [ ! -e '$DOTFILES_ROOT/Library/LaunchAgents/com.user.ssh-add.plist' ]"
    run_test "setup avoids optional background agents" "! grep -q 'com.dotfiles.ticket-queue\|com.dotfiles.gwt-mayor\|com.dotfiles.changelog-review\|com.dotfiles.insights-review\|com.kubectl-fzf-server\|com.user.ssh-add\|com.dotfiles.agent-monitor' '$DOTFILES_ROOT/scripts/setup.sh'"

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
    local mcp_config="$DOTFILES_ROOT/.mcp.json"
    run_test "Claude Desktop config exists" "[ -f '$desktop_config' ]"

    if [ -f "$desktop_config" ]; then
        run_test "Claude Desktop config is valid JSON" "python3 -c \"import json; json.load(open('$desktop_config'))\""
    fi

    # Check .mcp.json exists
    run_test ".mcp.json exists" "[ -f '$mcp_config' ]"
    if [ -f "$mcp_config" ]; then
        run_test ".mcp.json is valid JSON" "python3 -c \"import json; json.load(open('$mcp_config'))\""
    fi

    if [ -f "$desktop_config" ] && [ -f "$mcp_config" ]; then
        run_test "Desktop MCP matches .mcp.json" "python3 -c \"import json; repo=json.load(open('$mcp_config')).get('mcpServers', {}); desk=json.load(open('$desktop_config')).get('mcpServers', {}); assert desk == repo\""
        run_test ".mcp.json MCP servers use bunx" "python3 -c \"import json; servers=json.load(open('$mcp_config')).get('mcpServers', {}); assert servers and all(server.get('command') == 'bunx' for server in servers.values())\""
        run_test "setup.sh registers .mcp.json stdio servers" "python3 -c \"import json, pathlib, re; servers=set(json.load(open('$mcp_config')).get('mcpServers', {})); setup=pathlib.Path('$DOTFILES_ROOT/scripts/setup.sh').read_text(); configured=set(re.findall(r'claude mcp add --scope user ([a-z0-9-]+) ', setup)); assert servers <= configured\""
    fi

    run_test "setup.sh uses bunx for shared stdio MCP servers" "python3 -c \"import pathlib; text=pathlib.Path('$DOTFILES_ROOT/scripts/setup.sh').read_text(); required=['context7 bunx', 'steampipe bunx', 'playwright bunx', 'drawio bunx']; assert all(item in text for item in required)\""
    run_test "setup.sh keeps deepwiki SSE exception" "grep -q 'claude mcp add --scope user --transport sse deepwiki https://mcp.deepwiki.com/sse' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "sync-mcp-config script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/sync-mcp-config.sh'"
    run_test "sync-mcp-config OpenCode MCP shape valid" "bash '$DOTFILES_ROOT/scripts/test-sync-mcp-config.sh' >/dev/null"

    # deniedMcpServers: blocks unused claude.ai managed integrations to reclaim KV-cache tokens
    local settings="$DOTFILES_ROOT/.claude/settings.json"
    if [ -f "$settings" ]; then
        run_test "settings.json declares deniedMcpServers" "python3 -c \"import json; s=json.load(open('$settings')); assert isinstance(s.get('deniedMcpServers'), list) and len(s['deniedMcpServers']) > 0\""
        run_test "deniedMcpServers includes unused integrations" "python3 -c \"import json; entries=json.load(open('$settings')).get('deniedMcpServers', []); denied={e.get('serverName') if isinstance(e, dict) else e for e in entries}; required={'claude_ai_Notion','claude_ai_Linear','claude_ai_Invideo'}; assert required <= denied, f'missing: {required - denied}'\""
        run_test "deniedMcpServers keeps used integrations unblocked" "python3 -c \"import json; entries=json.load(open('$settings')).get('deniedMcpServers', []); denied={e.get('serverName') if isinstance(e, dict) else e for e in entries}; used={'claude_ai_Atlassian','claude_ai_Gmail','claude_ai_Google_Calendar','claude_ai_Google_Drive'}; assert not (used & denied), f'blocks used: {used & denied}'\""
    fi
}

test_browser() {
    echo -e "${BLUE}--- Browser Automation Tests ---${NC}"

    run_test "agent-browser config removed" "[ ! -e '$DOTFILES_ROOT/.agent-browser/config.json' ]"
    run_test "agent-browser skill source removed" "[ ! -e '$DOTFILES_ROOT/skills/shared/agent-browser/SKILL.md' ]"
    run_test "ccb Fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/ccb.fish' ]"
    run_test "setup.sh configures Playwright MCP" "grep -q 'claude mcp add --scope user playwright bunx @playwright/mcp@latest' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh omits agent-browser" "! grep -q 'agent-browser install' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "Brewfile installs Firefox" "grep -q 'cask \"firefox\"' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "setup.sh installs Firefox GUI app" "grep -q '\"firefox\"' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh invokes Firefox setup" "grep -q 'firefox-setup.sh' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "Firefox setup helper exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh' ]"
    run_test "Firefox setup helper self-test passes" "bash '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh' --self-test"
    run_test "Firefox setup installs userChrome" "grep -q 'install_user_chrome' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh' && grep -q 'userChrome.css' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh'"
    run_test "Firefox setup installs userContent" "grep -q 'install_user_content' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh' && grep -q 'userContent.css' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh'"
    run_test "Firefox setup installs Sidebery CSS" "grep -q 'install_sidebery_css' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh' && grep -q 'sidebery.css' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh'"
    run_test "Firefox capture helper exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox-capture-prefs.py' ]"
    run_test "Firefox capture helper self-test passes" "python3 '$DOTFILES_ROOT/scripts/setup/firefox-capture-prefs.py' --self-test"
    run_test "Firefox capture allow deny sets do not overlap" "python3 -c \"import importlib.util; spec=importlib.util.spec_from_file_location('capture', '$DOTFILES_ROOT/scripts/setup/firefox-capture-prefs.py'); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); overlap=mod.SAFE_EXACT & mod.DENY_EXACT; assert not overlap, overlap\""
    run_test "Firefox setup exposes pref capture" "grep -q -- '--capture-current-prefs' '$DOTFILES_ROOT/scripts/setup/firefox-setup.sh'"
    run_test "Brewfile installs FluidVoice" "grep -q 'cask \"fluidvoice\"' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "setup.sh installs FluidVoice GUI app" "grep -q '\"fluidvoice\"' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup.sh invokes FluidVoice setup" "grep -q 'fluidvoice-setup.sh' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "FluidVoice config source exists" "[ -f '$DOTFILES_ROOT/.config/fluidvoice/config.json' ]"
    run_test "FluidVoice config source is valid JSON" "python3 -c \"import json; json.load(open('$DOTFILES_ROOT/.config/fluidvoice/config.json'))\""
    run_test "FluidVoice setup helper is executable" "[ -x '$DOTFILES_ROOT/scripts/setup/fluidvoice-setup.sh' ]"
    run_test "FluidVoice config helper is executable" "[ -x '$DOTFILES_ROOT/scripts/setup/fluidvoice-config.py' ]"
    run_test "FluidVoice config validates" "python3 '$DOTFILES_ROOT/scripts/setup/fluidvoice-config.py' validate --config '$DOTFILES_ROOT/.config/fluidvoice/config.json'"
    run_test "FluidVoice setup helper self-test passes" "bash '$DOTFILES_ROOT/scripts/setup/fluidvoice-setup.sh' --self-test"
    run_test "FluidVoice config excludes private state" "! grep -E 'ProviderAPIKeys|ProviderAPIKeyIdentifiers|TranscriptionHistoryEntries|CommandModeChatSessions|AnalyticsAnonymousInstallID|PreferredInputDeviceUID|PreferredOutputDeviceUID|ExternalCoreMLArtifactsDirectories|/Users/|sk-' '$DOTFILES_ROOT/.config/fluidvoice/config.json'"
    run_test "FluidVoice setup exposes pref capture" "grep -q -- '--capture-current-prefs' '$DOTFILES_ROOT/scripts/setup/fluidvoice-setup.sh'"
    run_test "Firefox policy source exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox/policies.json' ]"
    run_test "Firefox policy source is valid JSON" "python3 -c \"import json; json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))\""
    run_test "Firefox policy installs Granted extension" "python3 -c \"import json; policies=json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))['policies']; ext=policies['ExtensionSettings']['{b5e0e8de-ebfe-4306-9528-bcc18241a490}']; assert ext['installation_mode'] == 'force_installed'; assert 'granted/latest.xpi' in ext['install_url']\""
    run_test "Firefox policy installs Auto Tab Discard" "python3 -c \"import json; policies=json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))['policies']; ext=policies['ExtensionSettings']['{c2c003ee-bd69-42a2-b0e9-6f34222cb046}']; assert ext['installation_mode'] == 'force_installed'; assert 'auto-tab-discard/latest.xpi' in ext['install_url']\""
    run_test "Firefox policy configures tab discard" "python3 -c \"import json; policies=json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))['policies']; cfg=policies['3rdparty']['Extensions']['{c2c003ee-bd69-42a2-b0e9-6f34222cb046}']; assert cfg['period'] == 3600; assert cfg['pinned'] is True; assert cfg['audio'] is True; assert cfg['form'] is True; assert '*.atlassian.net/*' in ' '.join(cfg['whitelist-url'])\""
    run_test "Firefox policy enables containers" "python3 -c \"import json; prefs=json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))['policies']['Preferences']; assert prefs['privacy.userContext.enabled']['Value'] is True; assert prefs['privacy.userContext.ui.enabled']['Value'] is True\""
    run_test "Firefox policy enables low-memory tab unload" "python3 -c \"import json; prefs=json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))['policies']['Preferences']; assert prefs['browser.tabs.unloadOnLowMemory']['Value'] is True\""
    run_test "Firefox policy defaults to dark theme" "python3 -c \"import json; prefs=json.load(open('$DOTFILES_ROOT/scripts/setup/firefox/policies.json'))['policies']['Preferences']; assert prefs['extensions.activeThemeID']['Value'] == 'firefox-compact-dark@mozilla.org'; assert prefs['layout.css.prefers-color-scheme.content-override']['Value'] == 0\""
    run_test "Firefox user.js source exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox/user.js' ]"
    run_test "Firefox user.js enables containers" "grep -q 'privacy.userContext.enabled' '$DOTFILES_ROOT/scripts/setup/firefox/user.js' && grep -q 'privacy.userContext.ui.enabled' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox user.js enables dark theme" "grep -q 'firefox-compact-dark@mozilla.org' '$DOTFILES_ROOT/scripts/setup/firefox/user.js' && grep -q 'layout.css.prefers-color-scheme.content-override.*, 0' '$DOTFILES_ROOT/scripts/setup/firefox/user.js' && ! grep -q 'firefox-alpenglow@mozilla.org' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox user.js enables userChrome" "grep -q 'toolkit.legacyUserProfileCustomizations.stylesheets' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox user.js enables low-memory tab unload" "grep -q 'browser.tabs.unloadOnLowMemory.*, true' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox user.js enables CSS support prefs" "grep -q 'svg.context-properties.content.enabled' '$DOTFILES_ROOT/scripts/setup/firefox/user.js' && grep -q 'layout.css.backdrop-filter.enabled' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox user.js enables Sidebery themed buttons" "grep -q 'svg.context-properties.content.enabled.*, true' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox capture keeps theme managed" "python3 -c \"import importlib.util; spec=importlib.util.spec_from_file_location('capture', '$DOTFILES_ROOT/scripts/setup/firefox-capture-prefs.py'); mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); assert not mod.is_safe_pref('extensions.activeThemeID', '\\\"firefox-alpenglow@mozilla.org\\\"'); assert not mod.is_safe_pref('browser.theme.toolbar-theme', '1'); assert not mod.is_safe_pref('browser.theme.content-theme', '1')\""
    run_test "Firefox user.js has captured-pref block" "grep -q 'BEGIN captured Firefox preferences' '$DOTFILES_ROOT/scripts/setup/firefox/user.js' && grep -q 'END captured Firefox preferences' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox user.js excludes local paths" "! grep -q '/Users/' '$DOTFILES_ROOT/scripts/setup/firefox/user.js'"
    run_test "Firefox userChrome source exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css' ]"
    run_test "Firefox userChrome hides native tabs" "grep -q '#TabsToolbar' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css' && grep -q 'visibility: collapse' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css'"
    run_test "Firefox userChrome declares dark color scheme" "grep -q 'color-scheme: dark' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css'"
    run_test "Firefox userChrome has minimal theme variables" "grep -q -- '--df-firefox-bg' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css' && grep -q -- '--df-firefox-radius' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css'"
    run_test "Firefox userChrome uses translucent surfaces" "grep -q -- '--df-firefox-glass' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css' && grep -q 'rgba(26, 27, 38, 0.38)' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css'"
    run_test "Firefox userChrome compacts sidebar header" "grep -q '#sidebar-header' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css' && grep -q 'min-height: 28px' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userChrome.css'"
    run_test "Firefox userContent source exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userContent.css' ]"
    run_test "Firefox userContent darkens blank pages" "grep -q 'about:blank' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userContent.css' && grep -q '#1a1b26' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userContent.css'"
    run_test "Firefox userContent imports Sidebery CSS" "grep -q '@import url(\"sidebery.css\")' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/userContent.css'"
    run_test "Firefox Sidebery CSS source exists" "[ -f '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css' ]"
    run_test "Firefox Sidebery CSS targets Sidebery pages" "grep -q 'sidebar/index' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css' && grep -q -- '--s-frame-bg' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css'"
    run_test "Firefox Sidebery CSS makes tabs translucent" "grep -q '.Tab .body' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css' && grep -q 'rgba(36, 40, 59, 0.26)' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css'"
    run_test "Firefox Sidebery CSS declares dark scheme" "grep -q 'color-scheme: dark' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css'"
    run_test "Firefox Sidebery CSS expects native dark mode" "grep -q 'Color scheme > dark' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css'"
    run_test "Firefox Sidebery CSS notes tested version" "grep -q 'Sidebery 5.x' '$DOTFILES_ROOT/scripts/setup/firefox/chrome/sidebery.css'"
    run_test "Granted defaults to Firefox" "grep -q 'DefaultBrowser = \"FIREFOX\"' '$DOTFILES_ROOT/.granted/config'"
    run_test "Granted Firefox profiles include prod" "grep -q '^prod=red:briefcase' '$DOTFILES_ROOT/.granted/firefox-profiles'"
    run_test "Granted Firefox profiles include management" "grep -q '^management=blue:briefcase' '$DOTFILES_ROOT/.granted/firefox-profiles'"
    run_test "gwt-ticket supports --browser-validate" "grep -q 'case --browser-validate' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket persists browser_validate state" "grep -q 'browser_validate:' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    if command -v fish &>/dev/null; then
        run_test "ccb Fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/ccb.fish'"
        run_test "gwt-ticket Fish syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    fi
}

test_tmux() {
    echo -e "${BLUE}--- tmux Tests ---${NC}"
    run_test ".tmux.conf exists at root" "[ -f '$DOTFILES_ROOT/.tmux.conf' ]"
    run_test "tmux scripts directory exists" "[ -d '$DOTFILES_ROOT/scripts/tmux' ]"
    run_test "tmux does not start polling watcher" "! grep -q 'tmux-claude-watcher.sh start' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "setup does not restart polling watcher" "! grep -q 'tmux-claude-watcher.sh' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "tmux omits PowerKit plugin" "! grep -q 'tmux-powerkit\|@powerkit_' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "setup omits PowerKit plugin" "! grep -q 'tmux-powerkit' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "tmux native inactive windows use agent colors" "grep -q '^setw -g window-status-format .*@wname_style' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux native current window uses agent colors" "grep -q '^setw -g window-status-current-format .*@wname_style' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux native status-right avoids shell commands" "grep -q '^set -g status-right .*%H:%M' '$DOTFILES_ROOT/.tmux.conf' && ! grep -q '^set -g status-right .*#(' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux session manager reads agent window style" "grep -q '#{@wname_style}' '$DOTFILES_ROOT/scripts/tmux/tmux-session-manager.sh' && ! grep -q '●◆' '$DOTFILES_ROOT/scripts/tmux/tmux-session-manager.sh'"
    run_test "tmux extended keys use csi-u for Pi" "grep -q '^set -g extended-keys on' '$DOTFILES_ROOT/.tmux.conf' && grep -q '^set -g extended-keys-format csi-u' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux-resurrect plugin configured" \
        "grep -q \"tmux-plugins/tmux-resurrect\" '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux-continuum plugin configured" \
        "grep -q \"tmux-plugins/tmux-continuum\" '$DOTFILES_ROOT/.tmux.conf'"
    run_test "setup installs tmux-resurrect plugin" \
        "grep -q \"tmux-plugins/tmux-resurrect\" '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup installs tmux-continuum plugin" \
        "grep -q \"tmux-plugins/tmux-continuum\" '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "tmux-continuum auto-restore enabled" \
        "grep -q \"@continuum-restore 'on'\" '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux-continuum autosave runs outside status-right" \
        "grep -q \"@continuum-save-interval '0'\" '$DOTFILES_ROOT/.tmux.conf' && grep -q 'tmux-status-finalize.sh' '$DOTFILES_ROOT/.tmux.conf' && [ -x '$DOTFILES_ROOT/scripts/tmux/tmux-continuum-autosave.sh' ]"
    run_test "tmux-resurrect restores Neovim sessions" \
        "grep -q \"@resurrect-processes '.*nvim.*vim\" '$DOTFILES_ROOT/.tmux.conf' && grep -q \"@resurrect-strategy-nvim 'session'\" '$DOTFILES_ROOT/.tmux.conf' && grep -q \"@resurrect-strategy-vim 'session'\" '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux-resurrect captures pane contents" \
        "grep -q \"@resurrect-capture-pane-contents 'on'\" '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux-resurrect avoids auto-restoring Claude CLI" \
        "! grep -q \"@resurrect-processes '.*claude\" '$DOTFILES_ROOT/.tmux.conf'"
    run_test "tmux-continuum remains last plugin" \
        "awk '/^set -g @plugin / { last=\$0 } END { exit(last != \"set -g @plugin '\''tmux-plugins/tmux-continuum'\''\") }' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "setup keeps tmux-continuum last" \
        "awk 'BEGIN { in_array=0 } /local tmux_plugins=\(/ { in_array=1; next } in_array && /^[[:space:]]*\)/ { exit(last !~ /tmux-plugins\\/tmux-continuum/) } in_array && /^[[:space:]]*\".*\"/ { last=\$0 }' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup omits stale tmux-copycat plugin" \
        "! grep -q \"tmux-plugins/tmux-copycat\" '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "setup omits stale tmux-smooth-scroll plugin" \
        "! grep -q \"azorng/tmux-smooth-scroll\" '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "tmux omits unused plugin layer" \
        "! grep -q 'tmux-prefix-highlight\|tmux-sidebar\|tmux-cpu\|laktak/extrakto\|tmux-notify\|tmux-1password\|tmux-fuzzback' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "setup omits unused tmux plugin layer" \
        "! grep -q 'tmux-prefix-highlight\|tmux-sidebar\|tmux-cpu\|laktak/extrakto\|tmux-notify\|tmux-1password\|tmux-fuzzback' '$DOTFILES_ROOT/scripts/setup.sh'"

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
        "grep -q 'tmux new-session -d -s \$session_name -n \$window_name -c \"\$worktree_path\"' '$GWT_TICKET'"
    run_test "gwt-ticket tracks new session creation" \
        "grep -q 'created_new_session' '$GWT_TICKET'"
    run_test "gwt-ticket skips new-window when session just created" \
        "grep -q 'created_new_session.*false' '$GWT_TICKET'"
    run_test "gwt-ticket only creates extra window for existing sessions" \
        "grep -A6 'test.*created_new_session.*false' '$GWT_TICKET' | grep -q 'tmux new-window'"

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

    for hook in cross-provider-bridge.sh log-notification.sh file-modified.sh post-compact-reinject.sh changelog-append.sh changelog-resume.sh changelog-persist.sh; do
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
    for hook in "$DOTFILES_ROOT"/.claude/hooks/lib/*.py; do
        if [ -f "$hook" ]; then
            local name
            name="lib/$(basename "$hook")"
            run_test "Hook $name valid Python" "python3 -c \"import py_compile; py_compile.compile('$hook', doraise=True)\""
        fi
    done

    # Settings.json hook events configured
    local settings="$DOTFILES_ROOT/.claude/settings.json"
    if [ -f "$settings" ]; then
        for event in ConfigChange Notification PostToolUse PostToolUseFailure PreCompact PreToolUse SessionEnd SessionStart Stop SubagentStart SubagentStop UserPromptSubmit WorktreeCreate WorktreeRemove; do
            run_test "Hook event wired: $event" "python3 -c \"import json; d=json.load(open('$settings')); assert '$event' in d.get('hooks', {})\""
        done
    fi

    run_test "SessionStart runs plan-resume" "python3 -c \"import json; d=json.load(open('$settings')); hooks=d['hooks']['SessionStart'][0]['hooks']; assert any('plan-resume.sh' in hook['command'] for hook in hooks)\""
    run_test "SessionStart runs changelog-resume" "python3 -c \"import json; d=json.load(open('$settings')); hooks=d['hooks']['SessionStart'][0]['hooks']; assert any('changelog-resume.sh' in hook['command'] for hook in hooks)\""
    run_test "PreCompact runs plan-persist" "python3 -c \"import json; d=json.load(open('$settings')); hooks=d['hooks']['PreCompact'][0]['hooks']; assert any('plan-persist.sh' in hook['command'] for hook in hooks)\""
    run_test "PreCompact runs changelog-persist" "python3 -c \"import json; d=json.load(open('$settings')); hooks=d['hooks']['PreCompact'][0]['hooks']; assert any('changelog-persist.sh' in hook['command'] for hook in hooks)\""
    run_test "Subagent hooks log notifications" "python3 -c \"import json; d=json.load(open('$settings')); assert any('log-notification.sh' in hook['command'] for hook in d['hooks']['SubagentStart'][0]['hooks']); assert any('log-notification.sh' in hook['command'] for hook in d['hooks']['SubagentStop'][0]['hooks'])\""
    run_test "WorktreeCreate runs worktree-init" "python3 -c \"import json; d=json.load(open('$settings')); hooks=d['hooks']['WorktreeCreate'][0]['hooks']; assert any('worktree-init.sh' in hook['command'] for hook in hooks)\""
    run_test "WorktreeRemove runs worktree-cleanup" "python3 -c \"import json; d=json.load(open('$settings')); hooks=d['hooks']['WorktreeRemove'][0]['hooks']; assert any('worktree-cleanup.sh' in hook['command'] for hook in hooks)\""

    # Functional: use_bun.py blocks npm, allows bun
    local hooks_dir="$DOTFILES_ROOT/.claude/hooks"
    run_test "use_bun.py blocks npm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py blocks yarn" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"yarn add react\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py blocks pnpm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"pnpm install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py blocks npx" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npx create-react-app\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null; [ \$? -eq 2 ]"
    run_test "use_bun.py allows bun" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bun install\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null"
    run_test "use_bun.py allows bunx" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bunx create-react-app\"},\"session_id\":\"t\"}' | python3 '$hooks_dir/use_bun.py' 2>/dev/null"

    # Functional: validate-bash.py - blocklist
    run_test "validate-bash blocks rm -rf /" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /tmp\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null | grep -q '\"decision\": \"block\"'"
    run_test "validate-bash blocks sudo rm" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sudo rm -rf node_modules\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null | grep -q '\"decision\": \"block\"'"
    run_test "validate-bash blocks dd to device" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"dd if=/dev/zero of=/dev/sda\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null | grep -q '\"decision\": \"block\"'"

    # Functional: validate-bash.py - allowlist (devcontainer/worktree)
    run_test "validate-bash allows git status" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: devcontainer up" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"devcontainer up\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: worktree add" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git worktree add ../feat\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: worktree list" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git worktree list\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"
    run_test "validate-bash allowlist: docker compose" "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker compose up -d\"}}' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"

    # Functional: validate-bash.py - malformed input stays non-blocking
    run_test "validate-bash ignores bad JSON without blocking" "echo 'not-json' | python3 '$hooks_dir/validate-bash.py' 2>/dev/null"

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
    run_test "protect-files blocks protected patch target" "python3 -c \"import json; print(json.dumps({'tool_input': {'patchText': '*** Begin Patch\\n*** Update File: /app/package-lock.json\\n*** End Patch'}}))\" | python3 '$hooks_dir/protect-files.py' 2>/dev/null; [ \$? -eq 2 ]"

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

    run_test "changed-files extracts direct and patch paths" "python3 - <<'PY'
import sys
sys.path.insert(0, '$hooks_dir')
from lib.changed_files import changed_paths
paths = changed_paths({
    'filePath': '/tmp/direct.txt',
    'patchText': '*** Begin Patch\n*** Add File: /tmp/add.txt\n*** Update File: /tmp/update.txt\n*** Delete File: /tmp/delete.txt\n*** Move to: /tmp/move.txt\n*** End Patch',
})
assert paths == ['/tmp/direct.txt', '/tmp/add.txt', '/tmp/update.txt', '/tmp/delete.txt', '/tmp/move.txt']
PY
    "

    run_test "auto-format formats JSON from patch payload" "
        tmpjson=\$(mktemp /tmp/hook-test-XXXXXX.json)
        printf '{\"z\":1}' > \"\$tmpjson\"
        python3 -c \"import json, sys; print(json.dumps({'tool_input': {'patchText': f'*** Begin Patch\\n*** Update File: {sys.argv[1]}\\n*** End Patch'}}))\" \"\$tmpjson\" | python3 '$hooks_dir/auto-format.py' 2>/dev/null
        grep -q '^  \"z\": 1$' \"\$tmpjson\"
        rc=\$?
        rm -f \"\$tmpjson\"
        [ \$rc -eq 0 ]
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

    # Functional: changelog hooks
    run_test "changelog-append writes typed entry" "
        tmpdir=\$(mktemp -d /tmp/changelog-test-XXXXXX)
        CLAUDE_PROJECT_DIR=\"\$tmpdir\" bash '$hooks_dir/changelog-append.sh' progress 'Implemented hook parity'
        rc=\$?
        grep -q 'PROGRESS: Implemented hook parity' \"\$tmpdir/.claude/CHANGELOG.md\"
        rm -rf \"\$tmpdir\"
        [ \$rc -eq 0 ]
    "
    run_test "changelog-resume shows recent typed entries" "
        tmpdir=\$(mktemp -d /tmp/changelog-test-XXXXXX)
        mkdir -p \"\$tmpdir/.claude\"
        printf '[2026-01-01T00:00:00Z] PROGRESS: one\\n[2026-01-02T00:00:00Z] DECISION: two\\n' > \"\$tmpdir/.claude/CHANGELOG.md\"
        out=\$(CLAUDE_PROJECT_DIR=\"\$tmpdir\" bash '$hooks_dir/changelog-resume.sh')
        rm -rf \"\$tmpdir\"
        [[ \"\$out\" == *'Session Changelog'* ]] && [[ \"\$out\" == *'DECISION: two'* ]]
    "
    run_test "changelog-persist shows compact-safe entries" "
        tmpdir=\$(mktemp -d /tmp/changelog-test-XXXXXX)
        mkdir -p \"\$tmpdir/.claude\"
        printf '[2026-01-01T00:00:00Z] FAILED: one\\n' > \"\$tmpdir/.claude/CHANGELOG.md\"
        out=\$(CLAUDE_PROJECT_DIR=\"\$tmpdir\" bash '$hooks_dir/changelog-persist.sh')
        rm -rf \"\$tmpdir\"
        [[ \"\$out\" == *'FAILED: one'* ]]
    "
    # Functional: write-like PreToolUse keeps protect-files.py wired
    run_test "hook config: write-like tools include protect-files" "python3 -c \"
import json
d=json.load(open('$DOTFILES_ROOT/.claude/settings.json'))
edit_hooks=[h for h in d['hooks']['PreToolUse'] if h.get('matcher')=='Edit|Write|MultiEdit|ApplyPatch'][0]['hooks']
cmds=[h['command'] for h in edit_hooks]
assert any('protect-files.py' in cmd for cmd in cmds)
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
    run_test "Fish disables CLAUDE_CODE_NO_FLICKER by default" "grep -q 'CLAUDE_CODE_NO_FLICKER 0' '$DOTFILES_ROOT/.config/fish/config.fish'"
    run_test "Fish PATH prefers ~/.local/bin" "grep -q 'fish_add_path --move \$HOME/.local/bin' '$DOTFILES_ROOT/.config/fish/paths.fish'"
    run_test "Fish PATH includes dotfiles scripts bin" "grep -q 'fish_add_path --move \$HOME/dotfiles/scripts/bin' '$DOTFILES_ROOT/.config/fish/paths.fish'"
    run_test "Zsh PATH prefers ~/.local/bin" "grep -q 'export PATH=\"\$HOME/.local/bin:\$HOME/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH\"' '$DOTFILES_ROOT/.zshrc'"
    run_test "Zsh PATH includes dotfiles scripts bin" "grep -q 'export PATH=\"\$HOME/dotfiles/scripts/bin:\$PATH\"' '$DOTFILES_ROOT/.zshrc'"
    run_test "setup.sh verifies Claude wrapper" "grep -q 'Claude wrapper resolves native CLI correctly' '$DOTFILES_ROOT/scripts/setup.sh'"

    # CLAUDE.md documentation
    run_test "CLAUDE.md documents settings section" "grep -q 'Claude Code Settings & Security' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents permission rules" "grep -q 'Permission rules' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents sandbox config" "grep -q 'Sandbox:' '$DOTFILES_ROOT/CLAUDE.md'"
    run_test "CLAUDE.md documents attribution" "grep -q 'Attribution:' '$DOTFILES_ROOT/CLAUDE.md' && grep -q 'commit: \"\"' '$DOTFILES_ROOT/CLAUDE.md'"
}

test_nvim_bridge() {
    echo -e "${BLUE}--- Neovim Agent Bridge Tests ---${NC}"

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
    run_test "OpenCode permissions allow by default" "jq -e '.permission[\"*\"] == \"allow\" and .permission.doom_loop == \"ask\"' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode config has openai provider" "jq -e '.provider.openai' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode config has gpt-5.4 model" "jq -e '.provider.openai.models[\"gpt-5.4\"]' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode Vim tap configured" "grep -q 'tap \"leohenon/tap\"' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "OpenCode Vim formula configured" "grep -q 'brew \"leohenon/tap/ocv\"' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "OpenCode Vim fork cloned by setup" "grep -q 'git@github.com:shaheislam/opencode-vim.git' '$DOTFILES_ROOT/scripts/setup.sh' && grep -q '\$HOME/opencode-vim' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "Legacy anomalyco OpenCode formula removed" "! grep -q 'anomalyco/tap/opencode' '$DOTFILES_ROOT/homebrew/Brewfile'"
    run_test "OpenCode compatibility shim exists" "[ -f '$DOTFILES_ROOT/scripts/bin/opencode' ]"
    run_test "OpenCode compatibility shim executable" "[ -x '$DOTFILES_ROOT/scripts/bin/opencode' ]"
    run_test "OpenCode compatibility shim delegates to ocv" "grep -q 'exec ocv \"\$@\"' '$DOTFILES_ROOT/scripts/bin/opencode'"
    run_test "OpenCode shim disables OpenTUI graphics probe" "grep -q 'OPENTUI_GRAPHICS' '$DOTFILES_ROOT/scripts/bin/opencode'"
    run_test "OpenCode shared server script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/serve.sh' ]"
    run_test "OpenCode shared server script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/serve.sh' ]"
    run_test "OpenCode shared server script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/serve.sh'"
    run_test "OpenCode shared server uses serve" "grep -q 'serve --port' '$DOTFILES_ROOT/scripts/opencode/serve.sh'"
    run_test "OpenCode shared server generates password" "grep -q 'server.password' '$DOTFILES_ROOT/scripts/opencode/serve.sh' && grep -q 'OPENCODE_SERVER_PASSWORD' '$DOTFILES_ROOT/scripts/opencode/serve.sh'"
    run_test "OpenCode LaunchAgent exists" "[ -f '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist' ]"
    run_test "OpenCode LaunchAgent keeps server alive" "grep -q '<string>com.dotfiles.opencode-serve</string>' '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist' && grep -q '<key>KeepAlive</key>' '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist'"
    run_test "OpenCode LaunchAgent logs to state" "grep -q '.local/state/opencode/serve.out.log' '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist'"
    run_test "OpenCode LaunchAgent sets username only" "grep -q 'OPENCODE_SERVER_USERNAME' '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist' && ! grep -q 'OPENCODE_SERVER_PASSWORD' '$DOTFILES_ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist'"
    run_test "OpenCode setup loads shared server" "grep -q 'com.dotfiles.opencode-serve' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "OpenCode setup has dedicated shared server helper" "grep -q '^setup_opencode_shared_server()' '$DOTFILES_ROOT/scripts/setup.sh' && grep -q '^[[:space:]]*setup_opencode_shared_server$' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "OpenCode setup is not gated by fonts/apps phase" "! sed -n '/^phase_9_fonts_and_apps()/,/^phase_10_advanced_features()/p' '$DOTFILES_ROOT/scripts/setup.sh' | grep -q 'com.dotfiles.opencode-serve'"
    run_test "OpenCode generated LaunchAgent ignored by stow" "grep -Fq 'Library/LaunchAgents/.*\.plist' '$DOTFILES_ROOT/.stow-local-ignore' || grep -Fq 'Library/LaunchAgents/com\.dotfiles\.opencode-serve\.plist' '$DOTFILES_ROOT/.stow-local-ignore'"
    run_test "OpenCode oc fish wrapper exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/oc.fish' ]"
    run_test "OpenCode oc fish wrapper syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/oc.fish'"
    run_test "OpenCode service fish wrapper exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish' ]"
    run_test "OpenCode service fish wrapper syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish'"
    run_test "OpenCode service reports pane-owned clients" "grep -q 'case clients' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish' && grep -q 'attaches' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish'"
    run_test "OpenCode service status health check is bounded" "grep -q -- '--max-time' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish'"
    run_test "OpenCode service status probes root endpoint" "grep -q '\$url/' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish' && ! grep -q '\$url/path' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish'"
    run_test "OpenCode service reaps stale pane clients" "grep -q 'case reap' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish' && grep -q 'tmux list-panes' '$DOTFILES_ROOT/.config/fish/functions/opencode-service.fish'"
    run_test "OpenCode oc script exists" "[ -f '$DOTFILES_ROOT/scripts/bin/oc' ]"
    run_test "OpenCode oc script executable" "[ -x '$DOTFILES_ROOT/scripts/bin/oc' ]"
    run_test "OpenCode oc attaches to shared server" "grep -q 'opencode attach' '$DOTFILES_ROOT/.config/fish/functions/oc.fish' && grep -q 'opencode attach' '$DOTFILES_ROOT/scripts/bin/oc'"
    run_test "OpenCode oc health check is bounded" "grep -q -- '--max-time' '$DOTFILES_ROOT/.config/fish/functions/oc.fish' && grep -q -- '--max-time' '$DOTFILES_ROOT/scripts/bin/oc'"
    run_test "OpenCode oc health probes root endpoint" "grep -q '\$url/' '$DOTFILES_ROOT/.config/fish/functions/oc.fish' && grep -q '\${url}/' '$DOTFILES_ROOT/scripts/bin/oc' && ! grep -q '\$url/path' '$DOTFILES_ROOT/.config/fish/functions/oc.fish' && ! grep -q '\${url}/path' '$DOTFILES_ROOT/scripts/bin/oc'"
    run_test "OpenCode oc fails fast after restart failure" "grep -q 'after restart' '$DOTFILES_ROOT/.config/fish/functions/oc.fish' && grep -q 'after restart' '$DOTFILES_ROOT/scripts/bin/oc'"
    run_test "OpenCode oc wrappers read password file" "grep -q 'server.password' '$DOTFILES_ROOT/.config/fish/functions/oc.fish' && grep -q 'server.password' '$DOTFILES_ROOT/scripts/bin/oc'"
    run_test "OpenCode oc script bootstraps unloaded service" "grep -q 'launchctl bootstrap' '$DOTFILES_ROOT/scripts/bin/oc' && grep -q 'materialize_plist' '$DOTFILES_ROOT/scripts/bin/oc'"
    run_test "OpenCode fish oc starts unloaded service" "grep -q 'opencode-service start' '$DOTFILES_ROOT/.config/fish/functions/oc.fish'"
    run_test "OpenCode zsh oc function exists" "grep -q '^function oc()' '$DOTFILES_ROOT/.zshrc' && grep -q 'scripts/bin/oc' '$DOTFILES_ROOT/.zshrc'"
    run_test "OpenCode tmux launcher uses oc wrapper" "grep -q 'scripts/bin/oc' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher owns window color" "grep -q '@wname_style' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && ! grep -q '@opencode_status' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher is pane-local only" "! grep -q 'opencode/tmux-status\|STATUS_FILE' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher prefers pane-local activity" "grep -q 'capture-pane' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && grep -q 'esc interrupt' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher avoids shared status" "! grep -q '@opencode_status\|show-environment -g OPENCODE_STATUS' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher reasserts status color" "grep -q 'set_window_style \"\$status\"' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && ! grep -q 'last_status' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher clears pane style" "grep -q 'set-option -p -u' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && grep -q 'clear_pane_style' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher keeps cleanup trap" "grep -q 'trap cleanup EXIT' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && grep -q 'exec \"\$HOME/dotfiles/scripts/bin/oc\"' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && ! grep -q 'wait \"\$ATTACH_PID\"' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode tmux launcher registers attach ownership" "grep -q 'ATTACH_DIR' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh' && grep -q 'register_attach' '$DOTFILES_ROOT/scripts/opencode/tmux-open.sh'"
    run_test "OpenCode pane cleanup script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/cleanup-pane.sh' ]"
    run_test "OpenCode pane cleanup script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/cleanup-pane.sh' ]"
    run_test "OpenCode pane cleanup script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/cleanup-pane.sh'"
    run_test "OpenCode pane cleanup verifies attach command" "grep -q 'ocv attach' '$DOTFILES_ROOT/scripts/opencode/cleanup-pane.sh' && grep -q 'opencode attach' '$DOTFILES_ROOT/scripts/opencode/cleanup-pane.sh' && grep -q 'scripts/bin/oc' '$DOTFILES_ROOT/scripts/opencode/cleanup-pane.sh'"
    run_test "tmux hooks OpenCode pane cleanup" "grep -q 'pane-exited.*opencode/cleanup-pane.sh' '$DOTFILES_ROOT/.tmux.conf'"
    run_test "OpenCode doctor resolves config-relative plugins" "grep -q 'CONFIG_DIR' '$DOTFILES_ROOT/scripts/opencode/doctor.sh' && grep -q '\$CONFIG_DIR' '$DOTFILES_ROOT/scripts/opencode/doctor.sh'"
    run_test "OpenCode TUI uses transparent theme" "jq -e '.theme == \"transparent\"' '$DOTFILES_ROOT/.config/opencode/tui.json' >/dev/null 2>&1"
    run_test "OpenCode transparent theme exists" "[ -f '$DOTFILES_ROOT/.config/opencode/themes/transparent.json' ]"
    run_test "OpenCode transparent theme avoids panel fill" "jq -e '.theme.background == \"none\" and .theme.backgroundPanel == \"none\" and .theme.backgroundElement == \"none\"' '$DOTFILES_ROOT/.config/opencode/themes/transparent.json' >/dev/null 2>&1"
    run_test "OpenCode TUI enables Vim system clipboard" "jq -e '.vim_system_clipboard_register == true' '$DOTFILES_ROOT/.config/opencode/tui.json' >/dev/null 2>&1"
    run_test "OpenCode TUI keeps insert Enter as newline" "jq -e '.vim_enter_submit == false' '$DOTFILES_ROOT/.config/opencode/tui.json' >/dev/null 2>&1"
    run_test "OpenCode TUI leaves Enter defaults" "jq -e '(.keybinds.input_submit? == null) and (.keybinds.input_newline? == null) and (.keybinds.input_force_submit? == null)' '$DOTFILES_ROOT/.config/opencode/tui.json' >/dev/null 2>&1"
    run_test "OpenCode TUI copy mode avoids variant conflict" "jq -e '.keybinds.copy_mode == \"<leader>v\" and .keybinds.variant_list == \"<leader>V\"' '$DOTFILES_ROOT/.config/opencode/tui.json' >/dev/null 2>&1"

    run_test "OpenCode command directory exists" "[ -d '$DOTFILES_ROOT/.opencode/command' ]"
    run_test "OpenCode doctor command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/doctor.md' ]"
    run_test "OpenCode review command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/review-changes.md' ]"
    run_test "OpenCode fix command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/fix-dotfiles.md' ]"
    run_test "OpenCode caveman command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/caveman.md' ]"
    run_test "OpenCode compact debug command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/debug-issue-compact.md' ]"
    run_test "OpenCode compact review command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/review-changes-compact.md' ]"
    run_test "OpenCode compact fix command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/fix-dotfiles-compact.md' ]"
    run_test "OpenCode fork command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/fork.md' ]"
    run_test "OpenCode fork command documents native fallback" "grep -q 'ctrl+x f' '$DOTFILES_ROOT/.opencode/command/fork.md'"
    run_test "OpenCode fork command inherits active model" "! grep -q '^model:' '$DOTFILES_ROOT/.opencode/command/fork.md'"
    run_test "OpenCode gwtfork command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/gwtfork.md' ]"
    run_test "OpenCode gwtfork delegates to Fish wrapper" "grep -q 'opencode-forkworktree' '$DOTFILES_ROOT/.opencode/command/gwtfork.md'"
    run_test "OpenCode gwtfork uses build agent" "grep -q '^agent: build$' '$DOTFILES_ROOT/.opencode/command/gwtfork.md'"
    run_test "OpenCode gwtfork inherits active model" "! grep -q '^model:' '$DOTFILES_ROOT/.opencode/command/gwtfork.md'"
    run_test "OpenCode gwtfork documents plugin intercept" "grep -q 'run without a model call' '$DOTFILES_ROOT/.opencode/command/gwtfork.md'"
    run_test "OpenCode forkworktree command absent" "[ ! -f '$DOTFILES_ROOT/.opencode/command/forkworktree.md' ]"

    run_test "OpenCode agents directory exists" "[ -d '$DOTFILES_ROOT/.opencode/agents' ]"
    run_test "OpenCode review agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/dotfiles-review.md' ]"
    run_test "OpenCode debug agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/dotfiles-debug.md' ]"
    run_test "OpenCode caveman review agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/dotfiles-review-caveman.md' ]"
    run_test "OpenCode caveman debug agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/dotfiles-debug-caveman.md' ]"
    run_test "OpenCode caveman build agent exists" "[ -f '$DOTFILES_ROOT/.opencode/agents/caveman-build.md' ]"
    run_test "OpenCode style agents exist" "jq -e '.agent.precise and .agent.balanced and .agent.creative and .agent.wild' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode style agents are primary" "jq -e 'all([.agent.precise.mode, .agent.balanced.mode, .agent.creative.mode, .agent.wild.mode][]; . == \"primary\")' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode style agents are model-free" "jq -e 'all([.agent.precise, .agent.balanced, .agent.creative, .agent.wild][]; has(\"model\") | not)' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode style agent temperatures configured" "jq -e '.agent.precise.temperature == 0.1 and .agent.balanced.temperature == 0.35 and .agent.creative.temperature == 0.8 and .agent.wild.temperature == 1' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"

    run_test "OpenCode entire plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/entire.ts' ]"
    run_test "OpenCode harness compat plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts' ]"
    run_test "OpenCode harness compat mirrors protect-files" "grep -q 'protect-files.py' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat logs tool failures" "grep -q 'log-tool-failure.py' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat resumes changelog" "grep -q 'changelog-resume.sh' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat persists changelog" "grep -q 'changelog-persist.sh' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat runs plan-watch" "grep -q 'plan-watch.sh' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat injects JFDI prompt context" "grep -q 'prompt-inject-context.py' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat handles multiedit" "grep -q 'multiedit' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat runs adversarial bridge" "grep -q 'cross-provider-bridge.sh' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat supports bridge env" "grep -q 'OPENCODE_CROSS_PROVIDER_BRIDGE' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat defaults bridge to OpenCode" "grep -q 'OPENCODE_BRIDGE_ORDER || \"opencode\"' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat sets sidecar reviewer model" "grep -q 'CROSS_PROVIDER_OPENCODE_MODEL' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode harness compat keeps tmux color on server disposal" "grep -q 'transient OpenCode server' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts' && grep -q 'wrapper cleanup handles real TUI exit' '$DOTFILES_ROOT/.config/opencode/plugin/harness-compat.ts'"
    run_test "OpenCode fork command plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/fork-command.ts' ]"
    run_test "OpenCode fork command plugin intercepts slash command" "grep -q 'command.execute.before' '$DOTFILES_ROOT/.config/opencode/plugin/fork-command.ts'"
    run_test "OpenCode fork command plugin triggers native fork" "grep -q 'session_fork' '$DOTFILES_ROOT/.config/opencode/plugin/fork-command.ts'"
    run_test "OpenCode fork command plugin handles gwtfork" "grep -q 'GWT_FORK_COMMAND' '$DOTFILES_ROOT/.config/opencode/plugin/fork-command.ts'"
    run_test "OpenCode gwtfork plugin runs wrapper directly" "grep -q 'opencode-forkworktree --session' '$DOTFILES_ROOT/.config/opencode/plugin/fork-command.ts'"
    run_test "OpenCode gwtfork plugin uses TUI toasts" "grep -q 'showToast' '$DOTFILES_ROOT/.config/opencode/plugin/fork-command.ts'"
    run_test "OpenCode ops command plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/ops-command.ts' ]"
    run_test "OpenCode ops command plugin handles doctor" "grep -q 'DOCTOR_COMMAND' '$DOTFILES_ROOT/.config/opencode/plugin/ops-command.ts'"
    run_test "OpenCode ops command plugin handles worktree status" "grep -q 'WORKTREE_STATUS_COMMAND' '$DOTFILES_ROOT/.config/opencode/plugin/ops-command.ts'"
    run_test "OpenCode project env plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/project-env.ts' ]"
    run_test "OpenCode project env plugin sets CLAUDE_PROJECT_DIR" "grep -q 'CLAUDE_PROJECT_DIR' '$DOTFILES_ROOT/.config/opencode/plugin/project-env.ts'"
    run_test "OpenCode project env keeps canonical DOTFILES_ROOT" "grep -q 'dotfilesRoot' '$DOTFILES_ROOT/.config/opencode/plugin/project-env.ts'"
    run_test "OpenCode session env plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts' ]"
    run_test "OpenCode session env exports shell session env" "grep -q 'output.env.OPENCODE_SESSION_ID' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode session env uses shell input session" "grep -q 'input.sessionID' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode session env avoids tmux writes" "! grep -q 'tmux set-\|@wname_style\|@opencode_status\|TMUX_AGENT_TARGET\|TMUX_PANE' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode session env avoids global coupling" "! grep -q 'setTmuxEnv\|setTmuxScoped\|OPENCODE_STATUS' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode session env keeps metadata on server disposal" "grep -q 'transient server instances' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts' && grep -q 'Session metadata is cleared only on deletion' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode session env avoids shared state files" "! grep -q 'opencode.*tmux-status\|writeStatusFile\|statusFile\|statusDir' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode tmux idle status is yellow" "python3 -c \"import pathlib,re; text=pathlib.Path('$DOTFILES_ROOT/scripts/opencode/tmux-open.sh').read_text(); assert re.search(r'idle \\\\| active\\\\)\\\\n\\\\s*printf .*#\\\\[fg=#e0af68\\\\]', text)\""
    run_test "Claude stop hook sets idle yellow" "grep -q '#\[fg=#e0af68\]' '$DOTFILES_ROOT/scripts/tmux/hooks/tmux-agent-stop.sh' && ! grep -q '#\[fg=#9ece6a\]' '$DOTFILES_ROOT/scripts/tmux/hooks/tmux-agent-stop.sh'"
    run_test "OpenCode session env has default export" "grep -q 'export default SessionEnvPlugin' '$DOTFILES_ROOT/.config/opencode/plugin/session-env.ts'"
    run_test "OpenCode SSE recorder plugin exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/sse-recorder.ts' ]"

    run_test "OpenCode model routing config exists" "[ -f '$DOTFILES_ROOT/.opencode/model-routing.json' ]"
    run_test "OpenCode model routing config is valid JSON" "jq empty '$DOTFILES_ROOT/.opencode/model-routing.json'"
    run_test "OpenCode model routing has presets" "jq -e '.presets | length > 0' '$DOTFILES_ROOT/.opencode/model-routing.json' >/dev/null 2>&1"

    run_test "OpenCode route command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/route.md' ]"
    run_test "OpenCode worktree-status command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/worktree-status.md' ]"
    run_test "OpenCode worktree-status inherits active model" "! grep -q '^model:' '$DOTFILES_ROOT/.opencode/command/worktree-status.md'"
    run_test "OpenCode sync-beads command exists" "[ -f '$DOTFILES_ROOT/.opencode/command/sync-beads.md' ]"

    run_test "OpenCode doctor script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/doctor.sh' ]"
    run_test "OpenCode doctor command inherits active model" "! grep -q '^model:' '$DOTFILES_ROOT/.opencode/command/doctor.md'"
    run_test "OpenCode doctor script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/doctor.sh'"
    run_test "OpenCode doctor fish wrapper exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/opencode-doctor.fish' ]"
    run_test "OpenCode doctor fish wrapper syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/opencode-doctor.fish'"
    run_test "OpenCode forkworktree fish wrapper exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish' ]"
    run_test "OpenCode forkworktree fish wrapper syntax valid" "fish -n '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree delegates to gwtt" "grep -q 'gwtt' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree passes fork session" "grep -q -- '--opencode-fork-session' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree supports source dir" "grep -q -- '--source-dir' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree allows dirty source" "! grep -q 'source worktree has uncommitted changes' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree passes handoff metadata" "grep -q -- '--opencode-fork-source' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree runs gwtt foreground" "grep -q -- 'gwtt --foreground' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"
    run_test "OpenCode forkworktree switches tmux target" "grep -q 'tmux switch-client' '$DOTFILES_ROOT/.config/fish/functions/opencode-forkworktree.fish'"

    run_test "gwt-ticket has OpenCode doctor preflight" "grep -q 'opencode/doctor.sh' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket defaults to OpenCode" "grep -q 'set -l use_codex true' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket has OpenCode explicit flag" "grep -q -- 'case --opencode --codex' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket supports OpenCode session fork" "grep -q -- '--opencode-fork-session' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket supports OpenCode fork source metadata" "grep -q -- '--opencode-fork-source' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket writes gwtfork handoff" "grep -q 'gwtfork.local.md' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket records dirty fork context" "grep -q 'Source Dirty Context' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket receipt includes worktree" "grep -q 'worktree: .*log:' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket launches OpenCode fork" "grep -q -- '--session.*--fork' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket has Claude fallback flag" "grep -q -- 'case --claude' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket bridge defaults to OpenCode reviewer" "grep -q 'CROSS_PROVIDER_ORDER opencode' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
    run_test "gwt-ticket records OpenCode bridge harness" "grep -q 'opencode-bridge' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"

    run_test "OpenCode JFDI shutdown script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/jfdi-shutdown-sync.sh' ]"
    run_test "OpenCode JFDI shutdown script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/jfdi-shutdown-sync.sh' ]"
    run_test "OpenCode JFDI shutdown script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/jfdi-shutdown-sync.sh'"
    run_test "OpenCode Entire hook test script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/test-entire-hooks.sh' ]"
    run_test "OpenCode Entire hook test script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/test-entire-hooks.sh' ]"
    run_test "OpenCode Entire hook test script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/test-entire-hooks.sh'"
    run_test "OpenCode Entire hook harness passes" "'$DOTFILES_ROOT/scripts/opencode/test-entire-hooks.sh' >/dev/null"
    run_test "OpenCode harness compat test script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/test-harness-compat.sh' ]"
    run_test "OpenCode harness compat test script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/test-harness-compat.sh' ]"
    run_test "OpenCode harness compat test script syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/test-harness-compat.sh'"
    run_test "OpenCode harness compat harness passes" "'$DOTFILES_ROOT/scripts/opencode/test-harness-compat.sh' >/dev/null"
    run_test "OpenCode SSE recorder harness exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/test-sse-recorder.ts' ]"
    run_test "OpenCode SSE recorder harness executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/test-sse-recorder.ts' ]"
    run_test "OpenCode SSE recorder harness passes" "bun '$DOTFILES_ROOT/scripts/opencode/test-sse-recorder.ts' >/dev/null"
    run_test "OpenCode diffview helper exists" "[ -x '$DOTFILES_ROOT/scripts/opencode/diffview-latest.sh' ]"
    run_test "OpenCode Neovim opener harness exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/test-nvim-open.sh' ]"
    run_test "OpenCode Neovim opener harness executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/test-nvim-open.sh' ]"
    run_test "OpenCode Neovim opener harness syntax valid" "bash -n '$DOTFILES_ROOT/scripts/opencode/test-nvim-open.sh'"
    run_test "OpenCode Neovim opener harness passes" "'$DOTFILES_ROOT/scripts/opencode/test-nvim-open.sh' >/dev/null"
    run_test "OpenCode Neovim health script exists" "[ -f '$DOTFILES_ROOT/scripts/opencode/test-nvim-health.sh' ]"
    run_test "OpenCode Neovim health script executable" "[ -x '$DOTFILES_ROOT/scripts/opencode/test-nvim-health.sh' ]"
    run_test "OpenCode Neovim health checks pass" "'$DOTFILES_ROOT/scripts/opencode/test-nvim-health.sh' >/dev/null"

    run_test "OpenCode plugin list configured" "jq -e '.plugin | length > 0' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode DCP plugin configured" "jq -e '.plugin[] | select(. == \"@tarquinen/opencode-dcp@latest\")' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode omits PTY and VibeGuard plugins" "! jq -e '.plugin[] | select(test(\"pty|vibeguard\"))' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode harness compat plugin configured" "jq -e '.plugin[] | select(. == \"./plugin/harness-compat.ts\")' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode session env plugin configured" "jq -e '.plugin[] | select(. == \"./plugin/session-env.ts\")' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode Claude subscription plugin configured" "jq -e '.plugin[] | select(. == \"./plugin/opencode-with-claude.ts\")' '$DOTFILES_ROOT/.config/opencode/opencode.json' >/dev/null 2>&1"
    run_test "OpenCode Claude subscription wrapper exists" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/opencode-with-claude.ts' ]"
    run_test "OpenCode Claude wrapper seeds Meridian profile" "grep -q 'MERIDIAN_PROFILES' '$DOTFILES_ROOT/.config/opencode/plugin/opencode-with-claude.ts'"
    run_test "OpenCode Claude wrapper memoizes proxy plugin" "grep -q 'sharedPluginPromise' '$DOTFILES_ROOT/.config/opencode/plugin/opencode-with-claude.ts'"
    run_test "OpenCode Claude subscription package resolver configured" "grep -q 'import(packageName)' '$DOTFILES_ROOT/.config/opencode/plugin/opencode-with-claude.ts'"
    run_test "OpenCode Claude subscription install is reproducible" "grep -q 'opencode-with-claude@latest' '$DOTFILES_ROOT/scripts/setup.sh'"
    run_test "OpenCode Neovim opener plugin configured" "[ -f '$DOTFILES_ROOT/.config/opencode/plugin/nvim-open.ts' ]"
    run_test "OpenCode DCP configs exist" "[ -f '$DOTFILES_ROOT/.opencode/dcp.jsonc' ] && [ -f '$DOTFILES_ROOT/.config/opencode/dcp.jsonc' ]"
    run_test "OpenCode VibeGuard config removed" "[ ! -e '$DOTFILES_ROOT/.opencode/vibeguard.config.json' ]"
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
    run_test "Plist files use plist diff driver" "git -C '$DOTFILES_ROOT' check-attr diff -- Library/LaunchAgents/com.dotfiles.opencode-serve.plist | grep -q 'plist'"

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
gemini) test_gemini ;;
pi) test_pi ;;
setup-syntax) test_setup_syntax ;;
brewfile) test_brewfile ;;
mcp) test_mcp ;;
browser) test_browser ;;
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
    test_gemini
    test_pi
    test_setup_syntax
    test_brewfile
    test_mcp
    test_browser
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
