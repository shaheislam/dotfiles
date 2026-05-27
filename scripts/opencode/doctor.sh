#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="$ROOT/.config/opencode/opencode.json"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"
AUTH_FILE="$HOME/.local/share/opencode/auth.json"
COMMAND_DIR="$ROOT/.opencode/command"
AGENT_DIR="$ROOT/.opencode/agents"
PLUGIN_DIR="$ROOT/.config/opencode/plugin"
FISH_FUNC="$ROOT/.config/fish/functions/opencode-doctor.fish"
OC_FISH_FUNC="$ROOT/.config/fish/functions/oc.fish"
OC_SCRIPT="$ROOT/scripts/bin/oc"
SERVE_SCRIPT="$ROOT/scripts/opencode/serve.sh"
SERVE_PLIST="$ROOT/Library/LaunchAgents/com.dotfiles.opencode-serve.plist"
SERVE_LABEL="com.dotfiles.opencode-serve"
SERVE_URL="http://127.0.0.1:${OPENCODE_PORT:-4096}"
SERVE_PASSWORD_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/opencode/server.password"

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

resolve_plugin_path() {
    local plugin="$1"

    case "$plugin" in
    file://*) printf '%s\n' "${plugin#file://}" ;;
    /*) printf '%s\n' "$plugin" ;;
    ./*) printf '%s\n' "$CONFIG_DIR/${plugin#./}" ;;
    *) return 1 ;;
    esac
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

if command -v ocv >/dev/null 2>&1; then
    ocv_version="$(ocv --version 2>/dev/null || true)"
    if [ -n "$ocv_version" ]; then
        print_result PASS "ocv binary" "$(command -v ocv) ($ocv_version)"
    else
        print_result PASS "ocv binary" "$(command -v ocv)"
    fi
else
    print_result FAIL "ocv binary" "Install with: brew install leohenon/tap/ocv"
fi

if [ -x "$SERVE_SCRIPT" ]; then
    print_result PASS "serve script" "$SERVE_SCRIPT"
else
    print_result FAIL "serve script" "Missing or not executable: $SERVE_SCRIPT"
fi

if [ -f "$SERVE_PLIST" ]; then
    print_result PASS "LaunchAgent" "$SERVE_PLIST"
else
    print_result FAIL "LaunchAgent" "Missing $SERVE_PLIST"
fi

if [ -s "$SERVE_PASSWORD_FILE" ]; then
    print_result PASS "server password" "$SERVE_PASSWORD_FILE"
else
    print_result WARN "server password" "Will be generated on first service start: $SERVE_PASSWORD_FILE"
fi

if launchctl list 2>/dev/null | grep -q "$SERVE_LABEL"; then
    print_result PASS "shared server agent" "$SERVE_LABEL loaded"
else
    print_result WARN "shared server agent" "Not loaded; run setup.sh or launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$SERVE_LABEL.plist"
fi

curl_auth=()
if [ -n "${OPENCODE_SERVER_PASSWORD:-}" ]; then
    curl_auth=(-u "${OPENCODE_SERVER_USERNAME:-opencode}:$OPENCODE_SERVER_PASSWORD")
elif [ -s "$SERVE_PASSWORD_FILE" ]; then
    curl_auth=(-u "${OPENCODE_SERVER_USERNAME:-opencode}:$(tr -d '\n' <"$SERVE_PASSWORD_FILE")")
fi

if curl -fsS --max-time 1 "${curl_auth[@]}" "$SERVE_URL/path" >/dev/null 2>&1; then
    print_result PASS "shared server" "$SERVE_URL"
else
    print_result WARN "shared server" "$SERVE_URL is not responding"
fi

if [ -f "$OC_FISH_FUNC" ]; then
    print_result PASS "oc fish wrapper" "$OC_FISH_FUNC"
else
    print_result WARN "oc fish wrapper" "Missing .config/fish/functions/oc.fish"
fi

if [ -x "$OC_SCRIPT" ]; then
    print_result PASS "oc script" "$OC_SCRIPT"
else
    print_result WARN "oc script" "Missing or not executable: $OC_SCRIPT"
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
    has_openai_model="$(jq -r '.provider.openai.models | has("gpt-5.4")' "$CONFIG_FILE" 2>/dev/null || true)"

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
        print_result PASS "OpenAI codex model" "gpt-5.4 configured"
    else
        print_result FAIL "OpenAI codex model" "Missing gpt-5.4 model config"
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
    profile = claims.get('https://api.openai.com/profile', {})
    print(profile.get('email') or claims.get('email') or 'unknown')
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")"
        print_result PASS "active account" "$email"
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

    # Check npm plugin cache and local file plugins
    npm_cache="$HOME/.cache/opencode/node_modules"
    for pkg in $(jq -r '.plugin // [] | .[]' "$CONFIG_FILE" 2>/dev/null); do
        if plugin_path="$(resolve_plugin_path "$pkg")"; then
            plugin_label="$(basename "$plugin_path")"
            if [ -f "$plugin_path" ]; then
                print_result PASS "file plugin: $plugin_label" "$plugin_path"
            else
                print_result WARN "file plugin: $plugin_label" "Missing $plugin_path"
            fi
            continue
        fi

        # Strip @latest or version tags for cache lookup
        pkg_name="$(echo "$pkg" | sed 's/@latest$//' | sed 's/@[0-9].*$//')"
        if [ -d "$npm_cache/$pkg_name" ]; then
            print_result PASS "cached: $pkg_name" "Installed"
        else
            print_result WARN "cached: $pkg_name" "Not cached (will install on next run)"
        fi
    done

    if [ -f "$PLUGIN_DIR/opencode-with-claude.ts" ]; then
        claude_plugin="$HOME/.bun/install/global/node_modules/opencode-with-claude/dist/index.js"
        if [ -f "$claude_plugin" ]; then
            print_result PASS "Claude subscription plugin" "Bun global install available"
        else
            print_result WARN "Claude subscription plugin" "Run: bun add -g opencode-with-claude@latest"
        fi
    fi
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
    print_result PASS "global plugins" "$plugin_count files in .config/opencode/plugin"
else
    print_result WARN "global plugins" "No files in .config/opencode/plugin"
fi

if [ -f "$PLUGIN_DIR/entire.ts" ]; then
    print_result PASS "entire plugin" "$PLUGIN_DIR/entire.ts"
else
    print_result WARN "entire plugin" "Missing .config/opencode/plugin/entire.ts"
fi

if [ -f "$PLUGIN_DIR/claude-compat.ts" ]; then
    print_result PASS "compat plugin" "$PLUGIN_DIR/claude-compat.ts"
else
    print_result WARN "compat plugin" "Missing .config/opencode/plugin/claude-compat.ts"
fi

if [ -f "$PLUGIN_DIR/project-env.ts" ]; then
    print_result PASS "env plugin" "$PLUGIN_DIR/project-env.ts"
else
    print_result WARN "env plugin" "Missing .config/opencode/plugin/project-env.ts"
fi

if [ -f "$PLUGIN_DIR/tmux-status.ts" ]; then
    print_result PASS "tmux plugin" "$PLUGIN_DIR/tmux-status.ts"
else
    print_result WARN "tmux plugin" "Missing .config/opencode/plugin/tmux-status.ts"
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
ENTIRE_HOOKS_TEST="$ROOT/scripts/opencode/test-entire-hooks.sh"
JFDI_SYNC_SCRIPT="$ROOT/scripts/opencode/jfdi-shutdown-sync.sh"

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

if [ -x "$ENTIRE_HOOKS_TEST" ]; then
    print_result PASS "entire harness" "$ENTIRE_HOOKS_TEST"
    if [ "${1:-}" != "--quick" ]; then
        if "$ENTIRE_HOOKS_TEST" >/dev/null 2>&1; then
            print_result PASS "entire recovery" "Simulation passed"
        else
            print_result WARN "entire recovery" "Simulation failed"
        fi
    fi
else
    print_result WARN "entire harness" "Missing scripts/opencode/test-entire-hooks.sh"
fi

if [ -x "$JFDI_SYNC_SCRIPT" ]; then
    print_result PASS "jfdi sync hook" "$JFDI_SYNC_SCRIPT"
else
    print_result WARN "jfdi sync hook" "Missing scripts/opencode/jfdi-shutdown-sync.sh"
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
