# Neovim-Claude Code Bridge

Event-driven bridge that gives Claude Code awareness of your Neovim editor state. Neovim writes diagnostics, focus, git hunks, and test results to a shared state file; Claude Code reads it before each prompt.

## Architecture

```
Neovim (writer)                        Claude Code (reader)
  DiagnosticChanged ──┐
  CursorHold ─────────┤
  BufEnter ───────────┼──▶ /tmp/nvim-claude-bridge/<hash>/state.json
  GitSignsUpdate ─────┤
  User:NeotestResult ─┘         ▲
                                │
                     UserPromptSubmit hook reads
                     injects as systemMessage
```

**State file**: `/tmp/nvim-claude-bridge/<project_hash>/state.json`
- Project hash = first 8 chars of SHA-256 of `vim.fn.getcwd()`
- Atomic writes via `os.rename()` on same filesystem (`/tmp`)
- TTL-based staleness: sections older than 5 minutes are skipped by the hook
- Cleanup on `VimLeavePre`

## Events

| Event | Debounce | Section | Source |
|-------|----------|---------|--------|
| `DiagnosticChanged` | 500ms | `diagnostics` | All LSP servers |
| `BufEnter` / `CursorHold` | 200ms | `focus` | Current buffer + cursor |
| `User:GitSignsUpdate` | 2s | `git_hunks` | `vim.b.gitsigns_status_dict` |
| `User:NeotestResult` | immediate | `tests` | neotest results API |

## State Schema

```json
{
  "project": "/path/to/project",
  "nvim_pid": 12345,
  "diagnostics": {
    "timestamp": 1708300000,
    "errors": [{"file": "src/main.py", "line": 42, "message": "...", "source": "Pyright"}],
    "warnings": [...],
    "error_count": 1,
    "warning_count": 0
  },
  "focus": {
    "timestamp": 1708300000,
    "file": "src/main.py",
    "line": 42,
    "filetype": "python"
  },
  "git_hunks": {
    "timestamp": 1708300000,
    "summary": "+15 ~3 -2",
    "files_changed": ["src/main.py"]
  },
  "tests": {
    "timestamp": 1708300000,
    "status": "fail",
    "failed": [{"name": "test_login", "file": "tests/test_auth.py", "message": "..."}],
    "passed_count": 47,
    "failed_count": 1
  }
}
```

## Files

| File | Location | Purpose |
|------|----------|---------|
| `claude-bridge.lua` | `~/neovim/lua/config/` | Neovim module (writer) |
| `nvim-bridge.sh` | `.claude/hooks/` | Claude Code hook (reader) |
| `cc-bridge.fish` | `.config/fish/functions/` | Fish management command |

## Setup

1. The Neovim module loads automatically via `autocmds.lua`
2. The hook is wired in `.claude/settings.json` under `UserPromptSubmit`
3. No configuration needed -- both sides auto-detect the project

## Fish Commands

```bash
cc-bridge status    # Show active bridges and section freshness
cc-bridge cat       # Pretty-print current state.json
cc-bridge clean     # Remove stale bridge dirs (dead PIDs)
cc-bridge help      # Usage info
```

## Design Decisions

1. **UserPromptSubmit** (not SessionStart) -- state is injected fresh before every prompt
2. **Per-section timestamps** -- stale sections (>5 min) are omitted
3. **Diagnostics capped** -- max 10 errors + 5 warnings to prevent bloat
4. **Focus is lightweight** -- file + line + filetype, no buffer contents
5. **No daemon** -- autocommands write, hook reads, zero processes to manage
6. **Git hunks from gitsigns** -- reads `vim.b.gitsigns_status_dict`, no shell out
7. **Neotest via User event** -- bridge fires `User:NeotestResult` after test runs

## Troubleshooting

**No state file appearing**:
- Check Neovim loaded the module: `:lua print(vim.inspect(require("config.claude-bridge")))`
- Check directory exists: `ls /tmp/nvim-claude-bridge/`

**Hook not injecting context**:
- Verify wiring: `jq '.hooks.UserPromptSubmit' .claude/settings.json`
- Test manually: `CLAUDE_PROJECT_DIR=$(pwd) bash .claude/hooks/nvim-bridge.sh`
- Check `jq` is installed: `command -v jq`

**Stale data persisting**:
- Run `cc-bridge clean` to remove dead PID dirs
- Neovim cleans up on normal exit (`VimLeavePre`), but crash may leave stale files

## Testing

```bash
scripts/test-filter.sh nvim-bridge
```
