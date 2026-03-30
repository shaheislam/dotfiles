#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="$ROOT/.config/opencode/opencode.json"
AUTH_FILE="$HOME/.local/share/opencode/auth.json"
COMMAND_DIR="$ROOT/.opencode/command"
AGENT_DIR="$ROOT/.opencode/agents"
PLUGIN_DIR="$ROOT/.opencode/plugins"
FISH_FUNC="$ROOT/.config/fish/functions/opencode-doctor.fish"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

print_result() {
    local level="$1"
    local label="$2"
    local detail="$3"

    case "$level" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac

    printf '%-4s %-26s %s\n' "$level" "$label" "$detail"
}

count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type f | wc -l | tr -d ' '
    else
        echo 0
    fi
}

echo "OpenCode Doctor"
echo "Repo:   $ROOT"
echo "Config: $CONFIG_FILE"
echo

if command -v opencode >/dev/null 2>&1; then
    print_result PASS "opencode binary" "$(command -v opencode)"
else
    print_result FAIL "opencode binary" "OpenCode is not installed or not on PATH"
fi

if [ -f "$CONFIG_FILE" ] && jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    print_result PASS "config JSON" "Valid opencode.json"
else
    print_result FAIL "config JSON" "Missing or invalid $CONFIG_FILE"
fi

if [ -f "$CONFIG_FILE" ]; then
    default_model="$(jq -r '.model // ""' "$CONFIG_FILE" 2>/dev/null || true)"
    small_model="$(jq -r '.small_model // ""' "$CONFIG_FILE" 2>/dev/null || true)"
    permissions="$(jq -r '.permission | if type == "string" then . else "custom" end' "$CONFIG_FILE" 2>/dev/null || true)"
    configured_providers="$(jq -r '.provider | keys | join(", ")' "$CONFIG_FILE" 2>/dev/null || true)"
    has_openai_provider="$(jq -r 'has("provider") and (.provider | has("openai"))' "$CONFIG_FILE" 2>/dev/null || true)"
    has_openai_model="$(jq -r '.provider.openai.models | has("gpt-5.1-codex")' "$CONFIG_FILE" 2>/dev/null || true)"

    [ -n "$default_model" ] && print_result PASS "default model" "$default_model"
    [ -n "$small_model" ] && print_result PASS "small model" "$small_model"

    if [ "$permissions" = "allow" ]; then
        print_result PASS "permissions" "Blanket allow"
    else
        print_result WARN "permissions" "Not blanket allow ($permissions)"
    fi

    if [ -n "$configured_providers" ]; then
        print_result PASS "configured providers" "$configured_providers"
    else
        print_result WARN "configured providers" "No providers configured"
    fi

    if [ "$has_openai_provider" = "true" ]; then
        print_result PASS "OpenAI provider" "Configured in opencode.json"
    else
        print_result FAIL "OpenAI provider" "Missing from opencode.json"
    fi

    if [ "$has_openai_model" = "true" ]; then
        print_result PASS "OpenAI codex model" "gpt-5.1-codex configured"
    else
        print_result FAIL "OpenAI codex model" "Missing gpt-5.1-codex model config"
    fi
fi

if [ -f "$AUTH_FILE" ] && jq empty "$AUTH_FILE" >/dev/null 2>&1; then
    auth_providers="$(jq -r 'keys | join(", ")' "$AUTH_FILE" 2>/dev/null || true)"
    print_result PASS "auth file" "$AUTH_FILE"
    if echo "$auth_providers" | grep -qi 'openai'; then
        print_result PASS "OpenAI auth" "$auth_providers"
    else
        print_result WARN "OpenAI auth" "Missing OpenAI credential ($auth_providers)"
    fi
else
    print_result WARN "auth file" "Missing or invalid $AUTH_FILE"
fi

# Account profiles
ACCOUNTS_DIR="$HOME/.opencode/accounts"
ACCOUNTS_FILE="$ACCOUNTS_DIR/.accounts"
if [ -f "$ACCOUNTS_FILE" ]; then
    acct_count="$(wc -l <"$ACCOUNTS_FILE" | tr -d ' ')"
    print_result PASS "account profiles" "$acct_count profiles in $ACCOUNTS_DIR"
else
    print_result WARN "account profiles" "No profiles (use opencode-accounts add <name>)"
fi

# Current account email (decode JWT)
if [ -f "$AUTH_FILE" ]; then
    access_token="$(jq -r '.openai.access // empty' "$AUTH_FILE" 2>/dev/null || true)"
    if [ -n "$access_token" ]; then
        email="$(python3 -c "
import json, base64
try:
    payload = '$access_token'.split('.')[1]
    payload += '=' * (-len(payload) % 4)
    claims = json.loads(base64.urlsafe_b64decode(payload))
    print(claims.get('email', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")"
        print_result PASS "active account" "$email"
    fi
fi

# Usage check (skip if --quick flag)
USAGE_CHECK="$ROOT/scripts/opencode/usage-check.sh"
if [ "${1:-}" != "--quick" ] && [ -x "$USAGE_CHECK" ]; then
    if "$USAGE_CHECK" --quiet 2>/dev/null; then
        print_result PASS "OpenAI usage" "Available"
    else
        usage_exit=$?
        case "$usage_exit" in
        1) print_result WARN "OpenAI usage" "Rate limited" ;;
        2) print_result WARN "OpenAI usage" "Auth invalid or expired" ;;
        *) print_result WARN "OpenAI usage" "Check failed (exit $usage_exit)" ;;
        esac
    fi
fi

# npm plugins configured in opencode.json
if [ -f "$CONFIG_FILE" ]; then
    plugin_list="$(jq -r '.plugin // [] | join(", ")' "$CONFIG_FILE" 2>/dev/null || true)"
    if [ -n "$plugin_list" ]; then
        plugin_npm_count="$(jq '.plugin // [] | length' "$CONFIG_FILE" 2>/dev/null || echo 0)"
        print_result PASS "npm plugins" "$plugin_npm_count configured: $plugin_list"
    else
        print_result WARN "npm plugins" "No npm plugins in opencode.json"
    fi

    # Check npm plugin cache
    npm_cache="$HOME/.cache/opencode/node_modules"
    for pkg in $(jq -r '.plugin // [] | .[]' "$CONFIG_FILE" 2>/dev/null); do
        # Strip @latest or version tags for cache lookup
        pkg_name="$(echo "$pkg" | sed 's/@latest$//' | sed 's/@[0-9].*$//')"
        if [ -d "$npm_cache/$pkg_name" ]; then
            print_result PASS "cached: $pkg_name" "Installed"
        else
            print_result WARN "cached: $pkg_name" "Not cached (will install on next run)"
        fi
    done
fi

# DCP config
if [ -f "$ROOT/.opencode/dcp.jsonc" ]; then
    print_result PASS "DCP config" ".opencode/dcp.jsonc"
else
    print_result WARN "DCP config" "Missing .opencode/dcp.jsonc"
fi

# VibeGuard config
if [ -f "$ROOT/.opencode/vibeguard.config.json" ]; then
    vg_enabled="$(jq -r '.enabled // false' "$ROOT/.opencode/vibeguard.config.json" 2>/dev/null || echo false)"
    if [ "$vg_enabled" = "true" ]; then
        print_result PASS "VibeGuard" "Enabled"
    else
        print_result WARN "VibeGuard" "Disabled in config"
    fi
else
    print_result WARN "VibeGuard" "Missing vibeguard.config.json"
fi

command_count="$(count_files "$COMMAND_DIR")"
if [ "$command_count" -gt 0 ]; then
    print_result PASS "project commands" "$command_count files in .opencode/command"
else
    print_result WARN "project commands" "No files in .opencode/command"
fi

agent_count="$(count_files "$AGENT_DIR")"
if [ "$agent_count" -gt 0 ]; then
    print_result PASS "project agents" "$agent_count files in .opencode/agents"
else
    print_result WARN "project agents" "No files in .opencode/agents"
fi

plugin_count="$(count_files "$PLUGIN_DIR")"
if [ "$plugin_count" -gt 0 ]; then
    print_result PASS "project plugins" "$plugin_count files in .opencode/plugins"
else
    print_result WARN "project plugins" "No files in .opencode/plugins"
fi

if [ -f "$PLUGIN_DIR/entire.ts" ]; then
    print_result PASS "entire plugin" "$PLUGIN_DIR/entire.ts"
else
    print_result WARN "entire plugin" "Missing .opencode/plugins/entire.ts"
fi

if [ -f "$PLUGIN_DIR/claude-compat.ts" ]; then
    print_result PASS "compat plugin" "$PLUGIN_DIR/claude-compat.ts"
else
    print_result WARN "compat plugin" "Missing .opencode/plugins/claude-compat.ts"
fi

if [ -f "$PLUGIN_DIR/openai-rotate.ts" ]; then
    print_result PASS "rotate plugin" "$PLUGIN_DIR/openai-rotate.ts"
else
    print_result WARN "rotate plugin" "Missing .opencode/plugins/openai-rotate.ts"
fi

if [ -f "$PLUGIN_DIR/project-env.ts" ]; then
    print_result PASS "env plugin" "$PLUGIN_DIR/project-env.ts"
else
    print_result WARN "env plugin" "Missing .opencode/plugins/project-env.ts"
fi

if [ -f "$PLUGIN_DIR/tmux-status.ts" ]; then
    print_result PASS "tmux plugin" "$PLUGIN_DIR/tmux-status.ts"
else
    print_result WARN "tmux plugin" "Missing .opencode/plugins/tmux-status.ts"
fi

ROUTING_FILE="$ROOT/.opencode/model-routing.json"
if [ -f "$ROUTING_FILE" ] && jq empty "$ROUTING_FILE" >/dev/null 2>&1; then
    preset_count="$(jq '.presets | length' "$ROUTING_FILE" 2>/dev/null || echo 0)"
    print_result PASS "model routing" "$preset_count presets in model-routing.json"
else
    print_result WARN "model routing" "Missing or invalid model-routing.json"
fi

if [ -f "$FISH_FUNC" ]; then
    print_result PASS "fish wrapper" "$FISH_FUNC"
else
    print_result WARN "fish wrapper" "Missing opencode-doctor.fish"
fi

CLAUDE_COMPAT_TEST="$ROOT/scripts/opencode/test-claude-compat.sh"
ROTATION_TEST="$ROOT/scripts/opencode/test-rotation.sh"

if [ -x "$CLAUDE_COMPAT_TEST" ]; then
    print_result PASS "compat harness" "$CLAUDE_COMPAT_TEST"
    if [ "${1:-}" != "--quick" ]; then
        if "$CLAUDE_COMPAT_TEST" >/dev/null 2>&1; then
            print_result PASS "compat recovery" "Simulation passed"
        else
            print_result WARN "compat recovery" "Simulation failed"
        fi
    fi
else
    print_result WARN "compat harness" "Missing scripts/opencode/test-claude-compat.sh"
fi

if [ -x "$ROTATION_TEST" ]; then
    print_result PASS "rotation harness" "$ROTATION_TEST"
    if [ "${1:-}" != "--quick" ]; then
        if "$ROTATION_TEST" >/dev/null 2>&1; then
            print_result PASS "rotation recovery" "Simulation passed"
        else
            print_result WARN "rotation recovery" "Simulation failed"
        fi
    fi
else
    print_result WARN "rotation harness" "Missing scripts/opencode/test-rotation.sh"
fi

if command -v tmux >/dev/null 2>&1; then
    print_result PASS "tmux" "$(command -v tmux)"
else
    print_result WARN "tmux" "tmux not found on PATH"
fi

# gwt-ticket integration
if command -v fish >/dev/null 2>&1; then
    gwtt_func="$ROOT/.config/fish/functions/gwt-ticket.fish"
    if [ -f "$gwtt_func" ] && grep -q 'opencode/doctor.sh' "$gwtt_func" 2>/dev/null; then
        print_result PASS "gwtt preflight" "Doctor wired into gwt-ticket --codex"
    else
        print_result WARN "gwtt preflight" "Doctor not wired into gwt-ticket"
    fi
fi

echo
echo "Summary: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
