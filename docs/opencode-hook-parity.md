# OpenCode Hook Parity Matrix

Short map of the Claude Code hook flows we care about and the current OpenCode equivalent in this repo.

| Claude flow | OpenCode equivalent | Status | Notes |
|---|---|---|---|
| Session start context | `.opencode/plugins/claude-compat.ts` -> `fix-hookify-imports.sh`, `plugin-chmod-fix.sh`, `bd prime`, `work-detect.sh`, `lsp-status.sh`, `plan-resume.sh`, tmux start, dream count | Full | Reuses existing Claude-side scripts where possible. |
| User prompt submit | `.opencode/plugins/claude-compat.ts` on `message.part.updated` -> `nvim-bridge.sh`, tmux prompt hook | Full | Fires once per user message text part. |
| PreToolUse Bash guard | `.opencode/plugins/claude-compat.ts` -> `use_bun.py`, `validate-bash.py`, `ci-precommit.sh` | Full | Blocks npm-family commands and dangerous bash. |
| PreToolUse Edit/Write guard | `.opencode/plugins/claude-compat.ts` -> `settings-edit-redirect.py` | Full | Prevents direct writes to `~/.claude/settings*.json`. |
| PostToolUse Read context | `.opencode/plugins/claude-compat.ts` -> `deepwiki-context.py` | Full | Injects transient system context after reads. |
| PostToolUse Edit/Write helpers | `.opencode/plugins/claude-compat.ts` -> `auto-format.py`, `file-modified.sh`, `ci-lint-on-save.sh` | Full | Reuses Claude post-edit helpers. |
| PreCompact plan persistence | `.opencode/plugins/claude-compat.ts` -> `plan-persist.sh` | Full | Wired through `experimental.session.compacting`. |
| Notification logging | `.opencode/plugins/claude-compat.ts` on `tui.toast.show` -> `log-notification.sh`, `tmux-agent-notify.sh` | Full | Maps OpenCode to Claude-style notification side effects. |
| Session end report | `.opencode/plugins/claude-compat.ts` shutdown -> `scripts/harness/session-report.sh --json` | Full | Runs synchronously on shutdown. |
| Obsidian session synthesis | `.opencode/plugins/claude-compat.ts` shutdown -> `scripts/obsidian/session-synthesize.sh --cwd <project>` | Full | Produces session note output when substantive context exists. |
| JFDI sync/extract | `.opencode/plugins/claude-compat.ts` shutdown -> `scripts/opencode/jfdi-shutdown-sync.sh` | Full | Supports sync, extract, Obsidian refresh, and env-based opt-out. |
| Weekly JFDI synthesis | `scripts/opencode/jfdi-shutdown-sync.sh` -> `weekly-synthesis.ts --week <ISO week>` | Full | Runs at most once per week via a stamp file. |
| Entire session lifecycle | `.opencode/plugins/entire.ts` -> `session-start`, `turn-start`, `turn-end`, `compaction`, `session-end` | Full | Uses sync hook calls for exit-sensitive events. |
| Entire todo parity | `.opencode/plugins/entire.ts` on `todo.updated` and `todowrite` -> `post-todo` | Full | Covers both evented and tool-driven todo updates. |
| Entire task parity | `.opencode/plugins/entire.ts` on `task` tool + `command.executed` -> `pre-task`, `post-task` | Full | Includes subagent metadata when available. |
| Worktree create hook | `.opencode/plugins/entire.ts` on `worktree.ready` -> `worktree-create` | Full | Includes worktree name and branch. |
| Worktree remove hook | `.opencode/plugins/entire.ts` on `worktree.failed` -> `worktree-remove` | Partial | Best-effort cleanup parity only; OpenCode does not expose a true worktree-deleted event. |
| Mid-session OpenAI account failover | `.opencode/plugins/openai-rotate.ts` | Full | Harnessed and smoke-tested; rotates saved accounts and retries prompts. |
| Live OpenCode session smoke coverage | `scripts/opencode/test-live-rotation.sh` | Partial | Validates real session continuation after auth switch, but OpenCode's internal 429 retry behavior still limits a raw provider-error parity test. |
| Cross-provider stop bridge | No OpenCode equivalent yet | Gap | Claude stop payload is more specific than current OpenCode events. |
| Worktree remove success parity | No exact OpenCode event | Gap | We only have `worktree.failed`, not a successful remove/delete lifecycle event. |

## Validation

Current parity checks live in:

- `scripts/opencode/test-claude-compat.sh`
- `scripts/opencode/test-entire-hooks.sh`
- `scripts/opencode/test-rotation.sh`
- `scripts/opencode/test-live-rotation.sh`
- `scripts/test-filter.sh opencode`
- `scripts/opencode/doctor.sh`
