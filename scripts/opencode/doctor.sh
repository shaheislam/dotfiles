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
