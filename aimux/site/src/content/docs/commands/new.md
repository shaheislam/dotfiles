---
title: aimux new
description: Create a workspace -- git worktree + tmux window
---

## Usage

```bash
aimux new [options] <branch>
```

## Description

Creates an isolated workspace consisting of a git worktree and tmux window. If the branch already exists (locally or on `origin`), it is checked out into the worktree. If the branch does not exist, a new branch is created automatically.

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--new` | `-n` | Force create a new branch (even if a branch with the same name exists remotely) |
| `--no-devcon` | | Skip devcontainer setup entirely |
| `--exec` | `-e` | Enter the container shell after starting devcontainer |
| `--mount DIR` | `-m` | Additional directory to mount into devcontainer (repeatable) |
| `--features LIST` | `-F` | Comma-separated devcontainer features to enable |
| `--rebuild` | `-r` | Remove and rebuild the devcontainer from scratch |
| `--fast` | `-f` | Skip devcontainer lifecycle hooks for faster startup |
| `--repo DIR` | | Use specified git repo directory instead of detecting from cwd |
| `--help` | `-h` | Show help |

## Examples

```bash
# Create workspace from existing branch
aimux new feature-auth

# Create new branch explicitly
aimux new -n experiment-v2

# Create workspace pointing at a different repo
aimux new --repo ~/projects/backend fix-api

# Skip devcontainer (just worktree + tmux window)
aimux new --no-devcon quick-fix

# Mount credentials into devcontainer
aimux new -m ~/.claude feature-auth

# Rebuild devcontainer with additional features
aimux new --rebuild --features "ghcr.io/devcontainers/features/node:1" feature-auth
```

## What happens

1. Validates you are in a git repository (or uses `--repo`)
2. Determines the worktree path: `../<repo-name>-<branch>/`
3. Creates the git worktree:
   - If the branch exists locally or on origin, checks it out
   - Otherwise, creates a new branch from the current HEAD
4. Trusts `mise` configuration if `.mise.toml` or `.tool-versions` exists in the worktree
5. Creates a tmux window named `<branch>` in the current session (if inside tmux)
6. Starts devcontainer if `devcon` is available and `--no-devcon` is not set
7. Writes a state file to `~/.aimux/state/<repo>-<branch>.json`
8. Starts tmux pipe-pane logging to `~/.aimux/logs/<repo>-<branch>.log`

## Notes

- Worktree path follows the pattern `../<repo-name>-<branch-name>/`
- If a worktree already exists at the target path, aimux reuses it instead of failing
- The tmux window is only created if you are inside a tmux session
- If `devcon` is not installed, devcontainer setup is silently skipped (no error)
- State files enable `aimux status` to discover and track workspaces
