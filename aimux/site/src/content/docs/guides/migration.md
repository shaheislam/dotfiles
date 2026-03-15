---
title: Migration from gwt-* Functions
description: Migrate from dotfiles Fish functions to aimux
---

## Overview

aimux replaces the Fish-only `gwt-*` functions from the dotfiles repo with a portable bash CLI. This guide maps old commands to new ones and covers what changed.

## Command mapping

| Fish Function | aimux Equivalent | Notes |
|--------------|-----------------|-------|
| `gwt-dev <branch>` / `gwtd` | `aimux new <branch>` | Same worktree + tmux window creation |
| `gwt-claude <branch>` / `gwtc` | `aimux new <branch>` then `aimux run` | Split into workspace creation and agent launch |
| `gwt-parallel <branches...>` | Loop with `aimux new` | Script a loop; parallel tmux windows are created |
| `gwt-status` / `gwts` | `aimux status` | Table output with agent state colors |
| `gwt-cleanup` / `gwtclean` | `aimux kill <branch>` | Explicit per-branch cleanup |
| `gwt-ticket <ticket>` / `gwtt` | `aimux run <ticket> [prompt]` | Autonomous execution with provider system |
| `gwt-ticket --codex` | `aimux run --provider codex <ticket>` | Provider flag replaces `--codex` |
| `gwt-ticket --bridge` | Not yet ported | Bridge review loop is planned |
| `gwt-doctor` / `gwtdoc` | `aimux doctor` | Same health check concept |
| `gwt-queue add` | `aimux queue add` | Queue management |
| `gwt-queue list` | `aimux queue list` | Queue listing |

## What changed

### Provider system

The old `gwt-ticket` hardcoded Claude and Codex support with `--codex` and `--bridge` flags. aimux uses a pluggable provider system:

```bash
# Old:
gwtt --codex PROJ-123

# New:
aimux run --provider codex PROJ-123
```

Custom providers can be added as shell scripts in `~/.aimux/providers/`. See the [Custom Providers](/guides/custom-providers/) guide.

### Configuration

The old system used Fish universal variables and scattered config. aimux centralizes configuration in a single TOML file:

```bash
# Old: Fish universal variables
set -U GWT_POLL_INTERVAL 10

# New: ~/.aimux/config.toml
# [general]
# poll_interval = 10
```

Or environment variables:

```bash
export AIMUX_POLL_INTERVAL=10
```

### Shell independence

The `gwt-*` functions required Fish shell. aimux is pure bash and works from any shell (Fish, Zsh, Bash). Completions are provided for all three.

### State persistence

The old system had no persistent state -- workspace information was ephemeral. aimux writes JSON state files to `~/.aimux/state/` so workspaces survive daemon restarts and terminal reconnects.

### Daemon

The old `tmux-claude-watcher.sh` was a bash polling loop. aimux provides both:

- `aimux daemon start` -- bash daemon (backward compatible)
- `aimuxd` -- Go binary with proper signal handling, PID file locking, and queue dispatch

### Parallel execution

```bash
# Old: gwt-parallel
gwt-parallel feature-auth feature-search feature-settings

# New: loop with aimux new
for branch in feature-auth feature-search feature-settings
    aimux new $branch
end
```

## What was dropped

| Feature | Reason |
|---------|--------|
| `--bridge` (Codex-Claude review loop) | Planned for future release; complex multi-agent pattern |
| `--sub` (subscription profiles) | Specific to Claude subscription management; use `claude-sub` directly |
| `gwt-parallel` bulk mode | Use a shell loop with `aimux new` instead |
| Devcontainer auto-login bind mounts | Use `--mount ~/.claude` with `aimux new -m` |
| `codex-accounts` / `codex-rotate` | Orthogonal to aimux; keep using the Fish functions directly |

## Migration steps

### 1. Install aimux

```bash
brew tap shaheislam/aimux
brew install aimux
```

### 2. Verify setup

```bash
aimux doctor
```

### 3. Create config (optional)

```bash
mkdir -p ~/.aimux
cp "$(brew --prefix)/share/aimux/default.toml" ~/.aimux/config.toml
```

### 4. Start using aimux

Replace `gwt-*` usage with aimux equivalents. The most common translations:

```bash
# Creating workspaces
gwtd feature-auth     ->  aimux new feature-auth

# Running tickets
gwtt PROJ-123          ->  aimux run PROJ-123 "Description"
gwtt --codex PROJ-123  ->  aimux run --provider codex PROJ-123 "Description"

# Checking status
gwts                   ->  aimux status

# Cleanup
gwtclean feature-auth  ->  aimux kill feature-auth

# Health check
gwtdoc                 ->  aimux doctor
```

### 5. Stop the old watcher

If running the legacy `tmux-claude-watcher.sh`:

```bash
# Check if it's running
ps aux | grep tmux-claude-watcher

# Kill it
kill $(cat /tmp/tmux-claude-watcher.pid)

# Start the aimux daemon instead
aimux daemon start
```

## Running both

aimux and the `gwt-*` Fish functions can coexist. They both use git worktrees and tmux, so workspaces created by one are visible to the other.

The daemon is the only potential conflict -- run either `aimux daemon start` or `tmux-claude-watcher.sh`, not both simultaneously. Both poll tmux panes and set window colors, so running both would cause flickering and redundant notifications.

## Rollback

If you need to go back to the old system:

```bash
# Stop aimux daemon
aimux daemon stop

# Stop queue dispatcher
aimux queue stop

# The gwt-* Fish functions still work
gwtt PROJ-123
```

aimux does not modify or remove the `gwt-*` functions. Migration is fully reversible.
