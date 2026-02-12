#!/usr/bin/env bash
# OpenClaw integration tests
# Run standalone: ./scripts/openclaw/test-openclaw.sh
# Run via filter: ./scripts/test-filter.sh openclaw

set -euo pipefail

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

run_test() {
    local name="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}  PASS${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}  FAIL${NC} $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo -e "${BLUE}=== OpenClaw Integration Tests ===${NC}"

# --- Configuration template tests ---
echo -e "\n${BLUE}--- Configuration Template ---${NC}"
run_test "Base config template exists" \
    "[ -f '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json' ]"
run_test "Base config is valid JSON" \
    "python3 -c \"import json; json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'))\""
run_test "Gateway binds to loopback" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['gateway']['bind'] == 'loopback'\""
run_test "Gateway auth is token mode" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['gateway']['auth']['mode'] == 'token'\""
run_test "Sandbox mode is non-main" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['agents']['defaults']['sandbox']['mode'] == 'non-main'\""
run_test "Sandbox has no network" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['agents']['defaults']['sandbox']['docker']['network'] == 'none'\""
run_test "Sandbox has no workspace access" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['agents']['defaults']['sandbox']['workspaceAccess'] == 'none'\""
run_test "Browser tool denied" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert 'browser' in c['tools']['deny']\""
run_test "Canvas tool denied" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert 'canvas' in c['tools']['deny']\""
run_test "Cron tool denied" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert 'cron' in c['tools']['deny']\""
run_test "Elevated execution disabled" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['tools']['elevated']['allowFrom'] == []\""
run_test "DM pairing for Telegram" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['channels']['telegram']['dmPolicy'] == 'pairing'\""
run_test "DM pairing for Discord" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['channels']['discord']['dmPolicy'] == 'pairing'\""
run_test "DM pairing for Slack" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['channels']['slack']['dmPolicy'] == 'pairing'\""
run_test "DM pairing for WhatsApp" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['channels']['whatsapp']['dmPolicy'] == 'pairing'\""
run_test "DM pairing for Signal" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['channels']['signal']['dmPolicy'] == 'pairing'\""
run_test "Sensitive log redaction enabled" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['logging']['redactSensitive'] == 'tools'\""
run_test "Plugin allowlist is empty" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['plugins']['allow'] == []\""
run_test "Tailscale mode is serve (not funnel)" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['gateway']['tailscale']['mode'] == 'serve'\""
run_test "Tool profile is coding" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['tools']['profile'] == 'coding'\""

# --- Fish function tests ---
echo -e "\n${BLUE}--- Fish Functions ---${NC}"
run_test "openclaw.fish exists" \
    "[ -f '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish' ]"
run_test "openclaw-notify.fish exists" \
    "[ -f '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish' ]"
run_test "openclaw.fish valid Fish syntax" \
    "fish -n '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw-notify.fish valid Fish syntax" \
    "fish -n '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish'"
run_test "openclaw.fish has help subcommand" \
    "grep -q 'case help' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw.fish has start subcommand" \
    "grep -q 'case start' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw.fish has audit subcommand" \
    "grep -q 'case audit' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw-notify.fish has urgency support" \
    "grep -q 'urgency' '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish'"
run_test "openclaw-notify.fish has fallback notification" \
    "grep -q 'terminal-notifier' '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish'"

# --- Script tests ---
echo -e "\n${BLUE}--- Scripts ---${NC}"
run_test "notify.sh exists" \
    "[ -f '$DOTFILES_ROOT/scripts/openclaw/notify.sh' ]"
run_test "notify.sh valid bash syntax" \
    "bash -n '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "notify.sh has oc_notify function" \
    "grep -q 'oc_notify()' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "notify.sh has oc_notify_ticket function" \
    "grep -q 'oc_notify_ticket()' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "notify.sh checks for openclaw binary" \
    "grep -q 'command -v openclaw' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "notify.sh checks gateway status" \
    "grep -q 'gateway status' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"

# --- Documentation tests ---
echo -e "\n${BLUE}--- Documentation ---${NC}"
run_test "Setup plan exists" \
    "[ -f '$DOTFILES_ROOT/docs/openclaw-setup.md' ]"
run_test "Plan has security section" \
    "grep -q 'Security Hardening' '$DOTFILES_ROOT/docs/openclaw-setup.md'"
run_test "Plan has implementation phases" \
    "grep -q 'Implementation Phases' '$DOTFILES_ROOT/docs/openclaw-setup.md'"
run_test "Plan has security checklist" \
    "grep -q 'Security Checklist' '$DOTFILES_ROOT/docs/openclaw-setup.md'"

# --- Security policy tests ---
echo -e "\n${BLUE}--- Security Policy ---${NC}"
run_test "No API keys in config template" \
    "! grep -qE '(sk-|xoxb-|xapp-|ABCDEF)' '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'"
run_test "No real tokens in Fish functions" \
    "! grep -qE '(sk-|xoxb-|xapp-)' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "No real tokens in notify script" \
    "! grep -qE '(sk-|xoxb-|xapp-)' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"

# --- Summary ---
echo ""
echo "─────────────────────────────────────"
echo -e "${BLUE}Results: ${TESTS_PASSED}/${TESTS_RUN} passed${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}  $TESTS_FAILED test(s) failed${NC}"
    exit 1
else
    echo -e "${GREEN}  All tests passed${NC}"
fi
