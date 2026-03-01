---
paths:
  - ".mcp.json"
  - "Library/**"
  - "scripts/setup.sh"
---

# MCP Server Integration

## CRITICAL: Configuration Parity Rule
- ALWAYS ensure MCP servers are configured in BOTH Claude Desktop AND Claude Code CLI
- ALWAYS maintain parity between both configurations
- ALWAYS update both simultaneously when adding/removing MCP servers

## Configuration Locations
1. **Claude Desktop**: `~/dotfiles/Library/Application Support/Claude/claude_desktop_config.json` (stow symlink)
2. **Claude Code CLI**: `claude mcp add` commands in `scripts/setup.sh` (Phase 4)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

## Adding New MCP Servers
1. Add to Claude Desktop config (`claude_desktop_config.json`)
2. Add to setup script via `claude mcp add` command
3. Verify: restart Claude Desktop, run `claude mcp list`
4. Test MCP server functionality in both environments

## Verify Parity
`claude mcp list` and `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers | keys'`
