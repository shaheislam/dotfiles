#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
SYNC_SCRIPT="$DOTFILES_ROOT/scripts/sync-mcp-config.sh"

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

write_mcp_config() {
    local target=$1
    cat >"$target/.mcp.json" <<'JSON'
{
  "mcpServers": {
    "playwright": {
      "command": "bunx",
      "args": ["-y", "@playwright/mcp@latest"]
    },
    "context7": {
      "command": "bunx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
JSON
}

global_repo="$tmp_root/global-config"
mkdir -p "$global_repo/.config/opencode"
write_mcp_config "$global_repo"
cat >"$global_repo/.config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.5"
}
JSON

"$SYNC_SCRIPT" "$global_repo" >/dev/null

test ! -f "$global_repo/opencode.json"
jq -e '.model == "openai/gpt-5.5"' "$global_repo/.config/opencode/opencode.json" >/dev/null
jq -e '.mcp.playwright.type == "local"' "$global_repo/.config/opencode/opencode.json" >/dev/null
jq -e '.mcp.playwright.enabled == true' "$global_repo/.config/opencode/opencode.json" >/dev/null
jq -e '.mcp.playwright.command == ["bunx", "-y", "@playwright/mcp@latest"]' "$global_repo/.config/opencode/opencode.json" >/dev/null
jq -e 'has("mcpServers") | not' "$global_repo/.config/opencode/opencode.json" >/dev/null

project_repo="$tmp_root/project-config"
mkdir -p "$project_repo"
write_mcp_config "$project_repo"

"$SYNC_SCRIPT" "$project_repo" >/dev/null

test -f "$project_repo/opencode.json"
jq -e '."$schema" == "https://opencode.ai/config.json"' "$project_repo/opencode.json" >/dev/null
jq -e '.mcp.context7.command == ["bunx", "-y", "@upstash/context7-mcp"]' "$project_repo/opencode.json" >/dev/null
jq -e 'has("mcpServers") | not' "$project_repo/opencode.json" >/dev/null

echo "PASS sync-mcp-config OpenCode MCP sync"
