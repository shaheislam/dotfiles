# Claude Code Changelog Audit — Recommendations

> Audit date: 2026-03-06 | Claude Code v2.1.70 | Changelog: v2.1.47 through v2.1.70

## Changes Applied

### 1. Fixed duplicate `bd prime` in SessionStart
The `bd prime` command was called twice in SessionStart hooks, wasting startup time.

### 2. Added `WorktreeCreate` hook (`worktree-init.sh`)
Auto-initializes beads (`bd prime`) and checkpoints (`entire enable`) in new worktrees.
This covers native `--worktree` flag and agent `isolation: worktree` — not just `gwt-*` functions.

### 3. Added `WorktreeRemove` hook (`worktree-cleanup.sh`)
Syncs beads before worktree removal to prevent memory loss.

### 4. Added `ConfigChange` hook (`config-change.sh`)
Logs configuration changes for audit trail. Fires on settings.json, skills, or policy changes.

### 5. Added `includeGitInstructions: false` to settings
Saves ~500 tokens/turn by suppressing built-in git instructions. Your CLAUDE.md already has comprehensive git workflow guidance.

### 6. Enhanced status line with `worktree` field
Shows active worktree name (e.g., `dotfiles/changelog` instead of just `dotfiles`).

### 7. Added `background: true` to `dotfiles-doctor` agent
Health checks now run in background by default, not blocking the main conversation.

## Recommendations Requiring Your Decision

### A. Effort Level: `max` (deepest reasoning)
**Current**: `CLAUDE_CODE_EFFORT_LEVEL=max` in fish config. The env var supports `low|medium|high|max|auto`. `max` is Opus 4.6 only and session-scoped (doesn't persist to settings). `--effort max` is passed as a CLI flag on all claude launch commands (gwt-ticket, gwt-parallel).

**Note**: The `effortLevel` settings key only accepts `low`, `medium`, `high` — NOT `max`. The env var and `/effort` command both support `max`.

**Known display behavior**: Claude Code normalizes `max` → `high` in both the status bar UI and the internal `CLAUDE_CODE_EFFORT_LEVEL` env var. However, `max` IS active — verifiable by the model ID suffix `[1m]` (1M context window, only available at max effort). The `--effort max` CLI flag and `CLAUDE_CODE_EFFORT_LEVEL=max` env var both work; the normalization is purely cosmetic.

**Trade-off**: `max` = deepest reasoning, no token constraint, highest cost. `high` is cheaper. `medium` default + ultrathink on demand = saves tokens on simple tasks.

**To change**: In `.config/fish/config.fish`, change `CLAUDE_CODE_EFFORT_LEVEL` to `high`, `medium`, or `low`.

### B. Agent `isolation: worktree` for risky agents
Agents like `refactorer`, `security-reviewer` could benefit from worktree isolation to prevent accidental changes to the main workspace. Add `isolation: worktree` to their frontmatter.

### C. `ENABLE_CLAUDEAI_MCP_SERVERS=false`
If you don't use claude.ai MCP servers (Notion, Invideo, etc.), setting this reduces startup time by skipping their discovery. Add to `env` in settings.json or Fish config.

### D. LSP `startupTimeout` configuration
With 9 LSP servers, some may benefit from custom timeouts. Create `.lsp.json` at project root:
```json
{
  "servers": {
    "bash-language-server": { "startupTimeout": 10000 },
    "lua-language-server": { "startupTimeout": 15000 }
  }
}
```

### E. HTTP hooks for notifications
Since v2.1.63, hooks support HTTP POST instead of shell commands. Could be more efficient for the macOS notification hook if you have a local webhook receiver.

### F. `${CLAUDE_SKILL_DIR}` in skills
Skills can now reference their own directory with `${CLAUDE_SKILL_DIR}`. Useful if skills need to reference local templates or data files.

### G. Custom `/simplify` skill vs built-in
v2.1.63 added `/simplify` as a bundled command. Check if your custom `simplify` skill adds value beyond the built-in, or if it can be removed to reduce skill token overhead.

## New Features Worth Knowing

| Feature | Version | Description |
|---------|---------|-------------|
| `Ctrl+F` | v2.1.49 | Kill background agents (two-press) |
| `Ctrl+U` on `!` | v2.1.69 | Exit bash mode from empty prompt |
| `/reload-plugins` | v2.1.69 | Activate plugin changes without restart |
| `/remote-control <name>` | v2.1.69 | Named remote control sessions |
| `claude agents` CLI | v2.1.50 | List all configured agents |
| `--worktree` (`-w`) | v2.1.49 | Native worktree isolation (built-in) |
| Auto-memory (`/memory`) | v2.1.59 | Claude auto-saves useful context |
| Voice STT (20 languages) | v2.1.69 | Expanded voice input support |
| `ultrathink` keyword | v2.1.68 | Trigger high effort for next turn |
