#!/usr/bin/env bash
# sync-mcp-config.sh — Sync .mcp.json to agent-specific MCP configs
#
# Superset-sh pattern: .mcp.json as single source of truth, with
# agent-specific configs generated/symlinked from it.
#
# Supported agents:
#   - Claude Code: reads .mcp.json natively (no action needed)
#   - Cursor: .cursor/mcp.json (symlink to ../.mcp.json)
#   - Codex: .codex/config.toml [mcp_servers.*] section
#   - OpenCode: opencode.json remote servers section
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

# --- Cursor: symlink .cursor/mcp.json → ../.mcp.json ---
cursor_dir="$REPO_ROOT/.cursor"
cursor_mcp="$cursor_dir/mcp.json"

if $DRY_RUN; then
    echo "[cursor] Would create symlink: .cursor/mcp.json -> ../.mcp.json"
else
    mkdir -p "$cursor_dir"
    if [ -L "$cursor_mcp" ]; then
        rm "$cursor_mcp"
    elif [ -f "$cursor_mcp" ]; then
        echo "[cursor] WARNING: .cursor/mcp.json exists and is not a symlink (preserving)"
    fi
    if [ ! -e "$cursor_mcp" ]; then
        ln -s "../.mcp.json" "$cursor_mcp"
        echo "[cursor] Created: .cursor/mcp.json -> ../.mcp.json"
        synced=$((synced + 1))
    fi
fi

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

# --- OpenCode: generate opencode.json if not exists ---
opencode_config="$REPO_ROOT/opencode.json"

if [ ! -f "$opencode_config" ]; then
    # Generate OpenCode config from .mcp.json
    opencode_json=$(jq '{
        mcpServers: .mcpServers | to_entries | map({
            key: .key,
            value: {
                type: "local",
                command: .value.command,
                args: .value.args
            }
        }) | from_entries
    }' "$MCP_FILE" 2>/dev/null || true)

    if [ -n "$opencode_json" ]; then
        if $DRY_RUN; then
            echo "[opencode] Would create opencode.json"
        else
            echo "$opencode_json" >"$opencode_config"
            echo "[opencode] Created opencode.json with MCP servers"
            synced=$((synced + 1))
        fi
    fi
else
    echo "[opencode] opencode.json exists (skipping — edit manually if needed)"
fi

echo ""
echo "Synced $synced agent MCP config(s) from .mcp.json"
