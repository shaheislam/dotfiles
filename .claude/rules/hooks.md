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
| **SessionStart** | `fix-hookify-imports.sh`, `entire ... session-start`, tmux start hook, `plugin-chmod-fix.sh`, `bd prime`, `work-detect.sh`, `lsp-status.sh`, `plan-resume.sh`, `changelog-resume.sh`, `dream/count-session.sh` | Startup repair, resume context, session memory, telemetry |
| **SessionStart** (`compact`) | `post-compact-reinject.sh` | Re-inject critical reminders after compaction |
| **PreToolUse** (Bash) | `use_bun.py`, `validate-bash.py`, `ci-precommit.sh` | Bun enforcement, dangerous command blocking, lightweight checks |
| **PreToolUse** (Task) | `entire ... pre-task` | Checkpoint/task lifecycle integration |
| **PreToolUse** (Edit\|Write) | `settings-edit-redirect.py` | Redirect settings.json edits to Bash+jq ([#37029](https://github.com/anthropics/claude-code/issues/37029)) |
| **PostToolUse** (Read) | `deepwiki-context.py` | Language-aware DeepWiki repo suggestions |
| **PostToolUse** (Task / TodoWrite) | `entire ... post-task`, `entire ... post-todo` | Task lifecycle persistence |
| **PostToolUse** (Edit\|Write) | `auto-format.py`, `file-modified.sh`, `ci-lint-on-save.sh` | Format, edit logging, on-save linting |
| **PostToolUse** (all) | `plan-watch.sh` | Detects plan drift after tool activity |
| **PreCompact** | `bd prime`, `plan-persist.sh`, `changelog-persist.sh` | Preserve working memory before compaction |
| **Notification** | `macos_notification.py`, `log-notification.sh`, tmux notify hook | Desktop alerts and audit logging |
| **UserPromptSubmit** | `nvim-bridge.sh`, `entire ... user-prompt-submit`, tmux prompt hook, `jfdi/prompt-inject-context.py` | Editor bridge, checkpointing, prompt context injection |
| **SubagentStart / SubagentStop** | `log-notification.sh` | Log subagent lifecycle events |
| **Stop** | `cross-provider-bridge.sh`, `entire ... stop`, tmux stop hook, Obsidian synthesis, `jfdi/session-end-extract.py`, `dream-hook.sh` | Cross-provider review, end-of-response extraction, memory sync |
| **SessionEnd** | `entire ... session-end`, tmux end hook, session report, Obsidian synthesis | Final session reporting |
| **WorktreeCreate / WorktreeRemove** | `worktree-init.sh`, `worktree-cleanup.sh` | Worktree lifecycle automation |

## Hook Types
- **Command**: shell scripts (most common)
- **Prompt**: LLM yes/no decision
- **Agent**: multi-turn with tools

## Adding New Hooks
1. Create script in `.claude/hooks/` (make executable)
2. Wire in `.claude/settings.json` under appropriate event
3. Add or update checks in `scripts/test-filter.sh hooks`
4. Update `docs/claude-code-hooks.md`

## Testing
`scripts/test-filter.sh hooks` for executability, syntax, wiring, and functional smoke coverage.
