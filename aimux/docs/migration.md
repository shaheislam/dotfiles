# Migration from dotfiles gwt-* Functions

aimux replaces the Fish-only `gwt-*` functions from the dotfiles repo with a portable bash CLI. This guide maps old commands to new ones and covers what changed.

## Command Mapping

| Fish Function | aimux Equivalent | Notes |
|--------------|-----------------|-------|
| `gwt-dev <branch>` / `gwtd` | `aimux new <branch>` | Same worktree + tmux window creation |
| `gwt-claude <branch>` / `gwtc` | `aimux new <branch>` then `aimux run` | Split into workspace creation and agent launch |
| `gwt-parallel <branches...>` | `for b in branches; aimux new $b; done` | Script a loop; parallel tmux windows are created |
| `gwt-status` / `gwts` | `aimux status` | Table output with agent state colors |
| `gwt-cleanup` / `gwtclean` | `aimux kill <branch>` | Explicit per-branch cleanup (no bulk mode yet) |
| `gwt-ticket <ticket>` / `gwtt` | `aimux run <ticket> [prompt]` | Autonomous execution with provider system |
| `gwt-ticket --codex` | `aimux run --provider codex <ticket>` | Provider flag replaces --codex |
| `gwt-ticket --bridge` | Not yet ported | Bridge review loop is planned |
| `gwt-doctor` / `gwtdoc` | `aimux doctor` | Same health check concept |
| `gwt-queue add` | `aimux queue add` | Queue management |
| `gwt-queue list` | `aimux queue list` | Queue listing |

## What Changed

### Provider System

The old `gwt-ticket` hardcoded Claude and Codex support with `--codex` and `--bridge` flags. aimux uses a pluggable provider system:

```bash
# Old:
gwtt --codex PROJ-123

# New:
aimux run --provider codex PROJ-123
```

Custom providers can be added as shell scripts in `~/.aimux/providers/`.

### Configuration

The old system used Fish universal variables and scattered config. aimux centralizes configuration in a single TOML file:

```bash
# Old: Fish universal variables
set -U GWT_POLL_INTERVAL 10

# New: ~/.aimux/config.toml
[general]
poll_interval = 10
```

Or environment variables:

```bash
export AIMUX_POLL_INTERVAL=10
```

### Shell Independence

The `gwt-*` functions required Fish shell. aimux is pure bash and works from any shell (Fish, Zsh, Bash). Completions are provided for all three.

### State Persistence

The old system had no persistent state -- workspace information was ephemeral. aimux writes JSON state files to `~/.aimux/state/` so workspaces survive daemon restarts and terminal reconnects.

### Daemon

The old `tmux-claude-watcher.sh` was a bash polling loop. aimux provides both:
- `aimux daemon start` -- bash daemon (backward compatible)
- `aimuxd` -- Go binary with proper signal handling, PID file locking, and queue dispatch

## What Was Dropped

| Feature | Reason |
|---------|--------|
| `--bridge` (Codex-Claude review loop) | Planned for future release; complex multi-agent pattern |
| `--sub` (subscription profiles) | Specific to Claude subscription management; use `claude-sub` directly |
| `gwt-parallel` bulk mode | Use a shell loop with `aimux new` instead |
| Devcontainer auto-login bind mounts | Use `--mount ~/.claude` with `aimux new -m` |
| `codex-accounts` / `codex-rotate` | Orthogonal to aimux; keep using the Fish functions directly |

## Migration Steps

1. Install aimux:
   ```bash
   brew tap shaheislam/aimux
   brew install aimux
   ```

2. Verify setup:
   ```bash
   aimux doctor
   ```

3. Create config (optional):
   ```bash
   mkdir -p ~/.aimux
   cp "$(brew --prefix)/share/aimux/default.toml" ~/.aimux/config.toml
   ```

4. Start using aimux commands instead of gwt-* functions.

5. The old Fish functions continue to work alongside aimux -- there is no conflict. Migrate at your own pace.

## Running Both

aimux and the gwt-* Fish functions can coexist. They both use git worktrees and tmux, so workspaces created by one are visible to the other. The daemon is the only potential conflict -- run either `aimux daemon start` or `tmux-claude-watcher.sh`, not both simultaneously.
