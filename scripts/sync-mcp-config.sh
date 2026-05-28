#!/usr/bin/env bash
# sync-mcp-config.sh — Sync .mcp.json to agent-specific MCP configs
#
# Superset-sh pattern: .mcp.json as single source of truth, with
# agent-specific configs generated/symlinked from it.
#
# Supported agents:
#   - Claude Code: reads .mcp.json natively (no action needed)
#   - Codex: .codex/config.toml [mcp_servers.*] section
#   - OpenCode: .config/opencode/opencode.json or project opencode.json mcp section
#
# Usage:
#   sync-mcp-config.sh [--dry-run] [repo-root]

set -euo pipefail

DRY_RUN=false
REPO_ROOT=""

for arg in "$@"; do
    case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) REPO_ROOT="$arg" ;;
    esac
done

if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

MCP_FILE="$REPO_ROOT/.mcp.json"

if [ ! -f "$MCP_FILE" ]; then
    echo "No .mcp.json found at $REPO_ROOT"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required"
    exit 1
fi

synced=0

# --- Codex: replace [mcp_servers.*] sections in .codex/config.toml ---
codex_config="$REPO_ROOT/.codex/config.toml"

if [ -f "$codex_config" ]; then
    # Generate TOML [mcp_servers.*] from .mcp.json
    mcp_toml=$(jq -r '.mcpServers | to_entries[] |
        "\n[mcp_servers.\(.key)]\ntype = \"stdio\"\ncommand = \"\(.value.command)\"\nargs = [\(.value.args | map("\"" + . + "\"") | join(", "))]"' "$MCP_FILE" 2>/dev/null || true)

    if [ -n "$mcp_toml" ]; then
        # Strip any existing MCP block (between marker and EOF or next non-MCP section)
        marker="# --- MCP Servers (synced from .mcp.json) ---"
        if grep -q "$marker" "$codex_config" 2>/dev/null; then
            # Remove from marker line to end of file, then re-append
            marker_line=$(grep -n "$marker" "$codex_config" | head -1 | cut -d: -f1)
            cleaned=$(head -n $((marker_line - 1)) "$codex_config")
            # Remove trailing blank lines
            cleaned=$(printf '%s' "$cleaned" | awk 'NF{p=1} p' | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) if(a[i]!=""){for(j=1;j<=i;j++) print a[j]; break}}')
        else
            cleaned=$(cat "$codex_config")
        fi

        if $DRY_RUN; then
            echo "[codex] Would write MCP servers to config.toml"
        else
            {
                echo "$cleaned"
                echo ""
                echo "$marker"
                echo "$mcp_toml"
            } >"$codex_config"
            echo "[codex] Synced MCP servers to config.toml"
            synced=$((synced + 1))
        fi
    fi
fi

# --- OpenCode: merge .mcp.json into the mcp config section ---
if [ -f "$REPO_ROOT/.config/opencode/opencode.json" ]; then
    opencode_config="$REPO_ROOT/.config/opencode/opencode.json"
else
    opencode_config="$REPO_ROOT/opencode.json"
fi

opencode_mcp=$(jq '.mcpServers | to_entries | map({
    key: .key,
    value: {
        type: "local",
        command: ([.value.command] + (.value.args // [])),
        enabled: true
    }
}) | from_entries' "$MCP_FILE" 2>/dev/null || true)

if [ -n "$opencode_mcp" ]; then
    if $DRY_RUN; then
        echo "[opencode] Would sync MCP servers to ${opencode_config#"$REPO_ROOT"/}"
    else
        mkdir -p "$(dirname "$opencode_config")"
        tmp_file=$(mktemp)
        if [ -f "$opencode_config" ]; then
            jq --argjson mcp "$opencode_mcp" '.mcp = ((.mcp // {}) + $mcp)' "$opencode_config" >"$tmp_file"
        else
            jq -n --argjson mcp "$opencode_mcp" '{"$schema":"https://opencode.ai/config.json", mcp: $mcp}' >"$tmp_file"
        fi
        mv "$tmp_file" "$opencode_config"
        echo "[opencode] Synced MCP servers to ${opencode_config#"$REPO_ROOT"/}"
        synced=$((synced + 1))
    fi
fi

echo ""
echo "Synced $synced agent MCP config(s) from .mcp.json"
