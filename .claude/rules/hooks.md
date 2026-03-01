---
paths:
  - ".claude/hooks/**"
  - ".claude/settings.json"
---

# Claude Code Hooks

Lifecycle hooks for deterministic control over Claude Code behavior. See `docs/claude-code-hooks.md` for complete reference.

## Hook Events Configured (`.claude/settings.json`)

| Event | Hooks | Purpose |
|-------|-------|---------|
| **SessionStart** | `fix-hookify-imports.sh`, `bd prime`, `lsp-status.sh` | Plugin fixes, Beads memory, LSP context |
| **PreToolUse** (Bash) | `use_bun.py`, `validate-bash.py` | Bun enforcement, dangerous command blocking |
| **PostToolUse** (Read) | `deepwiki-context.py` | Language-aware DeepWiki repo suggestions |
| **PreCompact** | `bd sync` | Beads memory sync before compaction |
| **Notification** | `macos_notification.py`, `log-notification.sh` | Desktop alerts, audit logging |
| **UserPromptSubmit** | `checkpoint-pre-prompt.sh`, `nvim-bridge.sh` | Checkpoint capture, Neovim editor context |
| **SubagentStart** | `subagent-lifecycle.sh` | Log agent spawn events |
| **SubagentStop** | `subagent-lifecycle.sh` | Log agent completion events |
| **Stop** | `checkpoint-capture.sh`, `cross-provider-bridge.sh` | Checkpoint capture, cross-provider review |

## Hook Types
- **Command**: shell scripts (most common)
- **Prompt**: LLM yes/no decision
- **Agent**: multi-turn with tools

## Adding New Hooks
1. Create script in `.claude/hooks/` (make executable)
2. Wire in `.claude/settings.json` under appropriate event
3. Add tests in `scripts/test-hooks.sh`
4. Update `docs/claude-code-hooks.md`

## Testing
`scripts/test-filter.sh hooks` (44 tests: permissions, syntax, wiring, functional)
