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
    if eval "$cmd" >/dev/null 2>&1; then
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
run_test "Tailscale mode is off (opt-in required)" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['gateway']['tailscale']['mode'] == 'off'\""
run_test "Nodes tool NOT denied (needed for bun/Node.js)" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert 'nodes' not in c['tools']['deny']\""
run_test "Tool profile is coding" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['tools']['profile'] == 'coding'\""
run_test "Exec approvals require=true" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['tools']['exec']['approvals']['require'] == True\""
run_test "Exec approvals skillAutoAllow=false" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['tools']['exec']['approvals']['skillAutoAllow'] == False\""
run_test "Exec approvals empty allowlist" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['tools']['exec']['approvals']['defaultAllowlist'] == []\""
run_test "Skills watcher enabled" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['skills']['load']['watch'] == True\""
run_test "Auto-updater disabled by default" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['update']['auto']['enabled'] == False\""
run_test "Auto-updater channel is stable" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['update']['auto']['channel'] == 'stable'\""
run_test "Secrets mode is env" \
    "python3 -c \"import json; c=json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')); assert c['secrets']['mode'] == 'env'\""

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
run_test "openclaw.fish has secrets subcommand" \
    "grep -q 'case secrets' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw.fish has approvals subcommand" \
    "grep -q 'case approvals' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw.fish has node subcommand" \
    "grep -q 'case node' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw.fish has update subcommand" \
    "grep -q 'case update' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw.fish has skills subcommand" \
    "grep -q 'case skills' '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"

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
run_test "notify.sh has failure logging" \
    "grep -q '_oc_log' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "notify.sh supports strict mode" \
    "grep -q 'OPENCLAW_NOTIFY_STRICT' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "openclaw-notify.fish has failure logging" \
    "grep -q '_oc_fish_log' '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish'"
run_test "openclaw-notify.fish supports strict mode" \
    "grep -q 'OPENCLAW_NOTIFY_STRICT' '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish'"
run_test "notify.sh documents non-Fish rationale" \
    "grep -q 'non-Fish contexts' '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"
run_test "setup.sh generates exec-approvals.json" \
    "grep -q 'exec-approvals.json' '$DOTFILES_ROOT/scripts/setup.sh'"
run_test "setup.sh sets exec-approvals permissions to 600" \
    "grep -q 'chmod 600.*exec-approvals' '$DOTFILES_ROOT/scripts/setup.sh'"

# --- Sandbox profile tests ---
echo -e "\n${BLUE}--- Sandbox Profile ---${NC}"
run_test "sandbox-profile.sh exists" \
    "[ -f '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh' ]"
run_test "sandbox-profile.sh is executable" \
    "[ -x '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh' ]"
run_test "sandbox-profile.sh valid bash syntax" \
    "bash -n '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has devcontainer profile" \
    "grep -q 'devcontainer)' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has default profile" \
    "grep -q 'default)' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has refcount logic" \
    "grep -q 'sandbox-refcount' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh saves original values" \
    "grep -q 'sandbox-prev.json' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh enforces permissions" \
    "grep -q 'chmod 600' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has logging" \
    "grep -q '_log' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh restores from saved values" \
    "grep -q 'PREV_FILE' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has mkdir-based lock" \
    "grep -q 'sandbox-lock' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has atomic write" \
    "grep -q '_atomic_write_config' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has stale lock detection" \
    "grep -q 'stale lock' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh handles no-op default" \
    "grep -q 'no active relaxation' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh unlocks on exit" \
    "grep -q \"trap '_unlock' EXIT\" '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh has fsync for durability" \
    "grep -q 'os.fsync' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh saturates refcount at 0" \
    "grep -q 'saturat' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh detects corruption (refcount=0 + saved state)" \
    "grep -q 'possible corruption' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "sandbox-profile.sh logs corrupt refcount value" \
    "grep -q 'corrupt refcount file' '$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh'"
run_test "gwt-ticket gates sandbox behind devcon" \
    "grep -q 'use_devcon' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish' && grep -A3 'use_devcon' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish' | grep -q 'sandbox_script'"
run_test "gwt-ticket wires sandbox devcontainer" \
    "grep -q 'sandbox_script.*devcontainer' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
run_test "gwt-ticket reverts sandbox on devcon failure" \
    "grep -q 'sandbox_script.*default' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish'"
run_test "gwt-ticket sandbox call is inside use_devcon guard" \
    "awk '/if .use_devcon/{found=1} found && /sandbox_script.*devcontainer/{match=1} /end/{if(found && !match) found=0}' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish' | grep -q '' || grep -B5 'sandbox_script.*devcontainer' '$DOTFILES_ROOT/.config/fish/functions/gwt-ticket.fish' | grep -q 'use_devcon'"
run_test "worktree-witness restores sandbox default" \
    "grep -q 'sandbox_script.*default' '$DOTFILES_ROOT/scripts/worktree-witness.sh'"

# --- Sandbox profile functional tests ---
# These exercise the actual script against a temp config to verify refcount
# lifecycle, concurrency, underflow, and sidecar cleanup.
echo -e "\n${BLUE}--- Sandbox Profile (functional) ---${NC}"
if command -v jq &>/dev/null; then
    SANDBOX_SCRIPT="$DOTFILES_ROOT/scripts/openclaw/sandbox-profile.sh"
    _sandbox_setup() {
        local td
        td=$(mktemp -d)
        mkdir -p "$td"
        # Minimal config with custom initial values (not "none") to verify save/restore
        cat >"$td/openclaw.json" <<'TESTEOF'
{"agents":{"defaults":{"sandbox":{"workspaceAccess":"ro","docker":{"network":"host"}}}}}
TESTEOF
        chmod 600 "$td/openclaw.json"
        echo "$td"
    }
    _sandbox_teardown() {
        rm -rf "$1"
    }

    # Test: single relax → restore roundtrip preserves original values
    run_test "functional: relax+restore preserves original values" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        ws=$(jq -r ".agents.defaults.sandbox.workspaceAccess" "$td/openclaw.json")
        net=$(jq -r ".agents.defaults.sandbox.docker.network" "$td/openclaw.json")
        _sandbox_teardown "$td"
        [ "$ws" = "ro" ] && [ "$net" = "host" ]
    '

    # Test: refcount increments on multiple relax calls
    run_test "functional: refcount increments correctly" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        count=$(cat "$td/.sandbox-refcount" 2>/dev/null)
        _sandbox_teardown "$td"
        [ "$count" = "2" ]
    '

    # Test: partial restore (refcount 2→1) keeps config relaxed
    run_test "functional: partial restore keeps config relaxed" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        ws=$(jq -r ".agents.defaults.sandbox.workspaceAccess" "$td/openclaw.json")
        count=$(cat "$td/.sandbox-refcount" 2>/dev/null)
        _sandbox_teardown "$td"
        [ "$ws" = "rw" ] && [ "$count" = "1" ]
    '

    # Test: full restore (refcount 2→1→0) restores original values and cleans up
    run_test "functional: full restore cleans sidecar files" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        ws=$(jq -r ".agents.defaults.sandbox.workspaceAccess" "$td/openclaw.json")
        _sandbox_teardown "$td"
        [ "$ws" = "ro" ] && [ ! -f "$td/.sandbox-refcount" ] && [ ! -f "$td/.sandbox-prev.json" ]
    '

    # Test: default with no prior relax is a no-op
    run_test "functional: default without relax is no-op" '
        td=$(_sandbox_setup)
        output=$(OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default 2>&1)
        ws=$(jq -r ".agents.defaults.sandbox.workspaceAccess" "$td/openclaw.json")
        _sandbox_teardown "$td"
        echo "$output" | grep -q "no active relaxation" && [ "$ws" = "ro" ]
    '

    # Test: extra default calls (underflow) are no-ops, don't corrupt config
    run_test "functional: underflow (extra defaults) is safe" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" default >/dev/null 2>&1
        ws=$(jq -r ".agents.defaults.sandbox.workspaceAccess" "$td/openclaw.json")
        _sandbox_teardown "$td"
        [ "$ws" = "ro" ] && [ ! -f "$td/.sandbox-refcount" ]
    '

    # Test: config has 600 permissions after operations
    run_test "functional: config permissions are 600 after write" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        perms=$(stat -c "%a" "$td/openclaw.json" 2>/dev/null || stat -f "%Lp" "$td/openclaw.json")
        _sandbox_teardown "$td"
        [ "$perms" = "600" ]
    '

    # Test: lock dir is cleaned up after operations
    run_test "functional: no stale lock after operation" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        _sandbox_teardown "$td"
        [ ! -d "$td/.sandbox-lock" ]
    '

    # Test: show works and reports refcount
    run_test "functional: show reports refcount" '
        td=$(_sandbox_setup)
        OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" devcontainer >/dev/null 2>&1
        output=$(OPENCLAW_CONFIG="$td/openclaw.json" bash "$SANDBOX_SCRIPT" show 2>&1)
        _sandbox_teardown "$td"
        echo "$output" | grep -q "refcount=1"
    '
else
    echo -e "${YELLOW}  SKIP${NC} jq not installed (skipping sandbox functional tests)"
fi

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

# --- Config validator (jq) ---
echo -e "\n${BLUE}--- Config Validator ---${NC}"
if command -v jq &>/dev/null; then
    run_test "jq validates base config" \
        "jq empty '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'"
    run_test "jq: gateway.bind exists" \
        "jq -e '.gateway.bind' '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'"
    run_test "jq: auth.mode exists" \
        "jq -e '.gateway.auth.mode' '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'"
    run_test "jq: sandbox config exists" \
        "jq -e '.agents.defaults.sandbox' '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'"
    run_test "jq: no funnel in tailscale mode" \
        "[ \"\$(jq -r '.gateway.tailscale.mode' '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json')\" != 'funnel' ]"
else
    echo -e "${YELLOW}  SKIP${NC} jq not installed (skipping jq validator tests)"
fi

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
