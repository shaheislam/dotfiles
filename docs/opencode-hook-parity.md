# OpenCode Hook Parity Matrix

Short map of the Claude Code hook flows we care about and the current OpenCode equivalent in this repo.

| Claude flow | OpenCode equivalent | Status | Notes |
|---|---|---|---|
| Session start context | `.config/opencode/plugin/claude-compat.ts` -> `fix-hookify-imports.sh`, `plugin-chmod-fix.sh`, `bd prime`, `work-detect.sh`, `lsp-status.sh`, `plan-resume.sh`, `changelog-resume.sh`, tmux start, dream count | Full | Reuses existing Claude-side scripts where possible. |
| User prompt submit | `.config/opencode/plugin/claude-compat.ts` on `message.part.updated` -> `nvim-bridge.sh`, `prompt-inject-context.py`, `plan-watch.sh`, tmux prompt hook | Full | Fires once per user message text part. JFDI context is injected only when the hook returns relevant memory context. |
| PreToolUse Bash guard | `.config/opencode/plugin/claude-compat.ts` -> `use_bun.py`, `validate-bash.py`, `ci-precommit.sh` | Full | Blocks npm-family commands and dangerous bash. |
| PreToolUse Edit/Write/MultiEdit/ApplyPatch guard | `.config/opencode/plugin/claude-compat.ts` -> `settings-edit-redirect.py`, `protect-files.py` | Full | Prevents direct writes and patch edits to Claude settings, secrets, npm lockfiles, git internals, and generated dependency files. |
| PostToolUse Read context | `.config/opencode/plugin/claude-compat.ts` -> `deepwiki-context.py`, `plan-watch.sh` | Full | Injects transient system context after reads and watches plan freshness. |
| PostToolUse Edit/Write/MultiEdit/ApplyPatch helpers | `.config/opencode/plugin/claude-compat.ts` -> `auto-format.py`, `file-modified.sh`, `ci-lint-on-save.sh`, `plan-watch.sh` | Full | Reuses Claude post-edit helpers for all OpenCode write-like tools, including patch payloads. |
| File created or edited opens in Neovim | `.config/opencode/plugin/nvim-open.ts` -> `scripts/nvim-open-file.sh` | Full | Runs only inside tmux, parses direct file args and patch payloads, skips noisy/generated paths, and avoids interrupting Neovim insert mode. Covered by `scripts/opencode/test-nvim-open.sh`. |
| Tool failure logging | `.config/opencode/plugin/claude-compat.ts` -> `log-tool-failure.py` | Full | Handles `tool.execute.error` plus best-effort event aliases and writes Claude-style failure JSONL logs. |
| PreCompact context persistence | `.config/opencode/plugin/claude-compat.ts` -> `bd prime`, `plan-persist.sh`, `changelog-persist.sh` | Full | Wired through `experimental.session.compacting`. `bd prime` is best-effort for bootstrap environments. |
| Notification logging | `.config/opencode/plugin/claude-compat.ts` on `tui.toast.show` -> `log-notification.sh`, `macos_notification.py`, `tmux-agent-notify.sh` | Full | Maps OpenCode toast events to Claude-style notification side effects. |
| Session end report | `.config/opencode/plugin/claude-compat.ts` shutdown -> `scripts/harness/session-report.sh --json` | Full | Runs synchronously on shutdown. |
| Obsidian session synthesis | `.config/opencode/plugin/claude-compat.ts` shutdown -> `scripts/obsidian/session-synthesize.sh --cwd <project>` | Full | Produces session note output when substantive context exists. |
| JFDI sync/extract | `.config/opencode/plugin/claude-compat.ts` shutdown -> `scripts/opencode/jfdi-shutdown-sync.sh` | Full | Supports sync, extract, Obsidian refresh, and env-based opt-out. |
| Weekly JFDI synthesis | `scripts/opencode/jfdi-shutdown-sync.sh` -> `weekly-synthesis.ts --week <ISO week>` | Full | Runs at most once per week via a stamp file. |
| Entire session lifecycle | `.config/opencode/plugin/entire.ts` -> `session-start`, `turn-start`, `turn-end`, `compaction`, `session-end` | Full | Uses sync hook calls for exit-sensitive events. |
| Entire todo parity | No OpenCode equivalent yet | Gap | `entire.ts` currently does not handle `todo.updated` or `todowrite`. |
| Entire task parity | No OpenCode equivalent yet | Gap | `entire.ts` currently does not handle task/subagent events or `command.executed`. |
| Worktree create hook | `gwt-ticket` setup plus tmux window layout | Partial | OpenCode does not expose Claude-style `WorktreeCreate`; the orchestrator handles worktree setup before OpenCode starts. |
| Worktree cleanup on close | `.tmux.conf` bindings and `tmux-worktree-on-exit.fish` -> `scripts/tmux/tmux-worktree-cleanup.sh` | Full | Cleanup is intentionally tied to tmux window close or last-pane exit, not OpenCode process exit. Dirty worktrees are not removed. |
| Mid-session OpenAI account failover | `.config/opencode/plugin/openai-rotate.ts` | Full | Harnessed and smoke-tested; rotates saved accounts and retries prompts. |
| Live OpenCode session smoke coverage | `scripts/opencode/test-live-rotation.sh` | Partial | Validates real session continuation after auth switch, but OpenCode's internal 429 retry behavior still limits a raw provider-error parity test. |
| Cross-provider adversarial bridge | `.config/opencode/plugin/claude-compat.ts` on idle -> `cross-provider-bridge.sh` | Partial | Runs when `CROSS_PROVIDER_BRIDGE=1` or `OPENCODE_CROSS_PROVIDER_BRIDGE=1`, captures the latest assistant text, defaults to an OpenCode sidecar reviewer model, and injects concerns into the next system context. OpenAI executors default to `anthropic/claude-opus-4-6`; Anthropic executors default to `openai/gpt-5.5`. This is advisory context, not a Claude-style blocking Stop decision. |
| Subagent lifecycle hooks | No OpenCode equivalent yet | Gap | Claude `SubagentStart` and `SubagentStop` events have no direct OpenCode event mapping here. |

## Cleanup Semantics

OpenCode shutdown runs reporting, synthesis, JFDI, dream, and tmux status hooks. It does not remove worktrees.

Worktree cleanup remains tmux-owned:

- Prefix `X` runs `scripts/tmux/tmux-worktree-cleanup.sh` for the current window and then kills the window.
- Prefix `x` kills a pane and triggers cleanup only when it was the last pane.
- `tmux-worktree-on-exit.fish` triggers the same cleanup when the final shell exits in a worktree window.
- `tmux-worktree-cleanup.sh` refuses to remove protected windows or dirty worktrees.

## Validation

Current parity checks live in:

- `scripts/opencode/test-claude-compat.sh`
- `scripts/opencode/test-entire-hooks.sh`
- `scripts/opencode/test-nvim-open.sh`
- `scripts/opencode/test-rotation.sh`
- `scripts/opencode/test-live-rotation.sh`
- `scripts/test-filter.sh opencode`
- `scripts/opencode/doctor.sh`
