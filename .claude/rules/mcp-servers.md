---
paths:
  - ".mcp.json"
  - "Library/**"
  - "scripts/setup.sh"
---

# MCP Server Integration

## CRITICAL: Configuration Parity Rule
- ALWAYS treat `.mcp.json` as the shared stdio source of truth for repo-managed MCP servers
- ALWAYS ensure those stdio servers are mirrored in BOTH Claude Desktop config AND Claude Code CLI setup commands
- ALWAYS update all three surfaces together when adding/removing shared stdio MCP servers
- Document any intentional exceptions explicitly (for example, `deepwiki` is CLI-only SSE today)

## Configuration Locations
1. **Shared stdio source**: `~/dotfiles/.mcp.json`
2. **Claude Desktop**: `~/dotfiles/Library/Application Support/Claude/claude_desktop_config.json` (stow symlink)
3. **Claude Code CLI**: `claude mcp add` commands in `scripts/setup.sh` (Phase 4)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

## Adding New MCP Servers
1. Add shared stdio servers to `.mcp.json`
2. Mirror them into Claude Desktop config (`claude_desktop_config.json`)
3. Mirror them into setup script via `claude mcp add` commands
4. Verify: restart Claude Desktop, run `claude mcp list`
5. Test MCP server functionality in both environments

## Current Exception
- `deepwiki` remains outside `.mcp.json` because the current sync flow only models stdio servers. Keep it documented as a Claude CLI SSE-only server until the sync tooling learns remote transports.

## Blocking Unused claude.ai Managed Integrations

Claude Code auto-loads claude.ai managed MCP server definitions (Atlassian, Gmail, Linear, Notion, Invideo, Google_Calendar, Google_Drive) into every session's KV cache. Each server definition costs ~1000+ tokens; unused ones displace room for actual work.

**Fix**: `.claude/settings.json` declares a `deniedMcpServers` array. Pattern-matches against server `name`, `command`, or `url` (per `docs/claude-code-cli-reference.md`).

Currently denied (verified unused in this workflow):
- `claude_ai_Notion` — beads (`bd`) is used for task tracking instead
- `claude_ai_Linear` — beads (`bd`) is used for task tracking instead
- `claude_ai_Invideo` — video generation is not part of this workflow

Kept enabled (actively used via skills):
- `claude_ai_Atlassian` — `/jira`, `/confluence` skills
- `claude_ai_Gmail`, `claude_ai_Google_Calendar`, `claude_ai_Google_Drive` — `/morning-brief` skill

To add more denials: edit `.claude/settings.json` via `jq` (never Edit — triggers bug #37029):

```bash
jq '.deniedMcpServers += ["claude_ai_NewIntegration"]' .claude/settings.json > /tmp/_settings.tmp \
  && mv /tmp/_settings.tmp .claude/settings.json
```

Verify savings: restart Claude Code, run `/context`, check the System tools line drop.

## Verify Parity
Run:

```bash
scripts/test-filter.sh mcp
claude mcp list
jq '.mcpServers | keys' .mcp.json
jq '.mcpServers | keys' "Library/Application Support/Claude/claude_desktop_config.json"
jq '.deniedMcpServers' .claude/settings.json
```
