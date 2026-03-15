---
title: aimux kill
description: Destroy a workspace and clean up all resources
---

## Usage

```bash
aimux kill [--force] <branch-or-path>
```

**Alias:** `aimux k`

## Description

Removes a workspace completely: stops containers, kills the tmux window, removes the git worktree, deletes the local branch, removes state and log files, and stops any running witness process.

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Kill even if the worktree has uncommitted changes |
| `--help` | `-h` | Show help |

## Examples

```bash
# Kill a workspace by branch name
aimux kill feature-auth

# Kill by worktree path
aimux kill /Users/me/projects/myapp-feature-auth

# Force kill with uncommitted changes
aimux kill --force experiment-v2
```

## What happens

1. **Validates** the target is not a protected branch (`main`, `master`, `develop`, `staging`, `production`)
2. **Checks** for uncommitted changes in the worktree -- fails with an error unless `--force` is used
3. **Stops devcontainer** if Docker is running and a matching container exists
4. **Removes devcontainer** instance and workspace directories under `~/.devcontainer/`
5. **Kills tmux window** matching the branch name in the current session
6. **Removes git worktree** (falls back to `rm -rf` if `git worktree remove` fails)
7. **Deletes the local branch** with `git branch -D`
8. **Prunes** stale git worktree references
9. **Stops witness** process if one is running for this workspace
10. **Removes state file** from `~/.aimux/state/`
11. **Removes log file** from `~/.aimux/logs/`

## Protected branches

The following branches cannot be killed:

- `main`
- `master`
- `develop`
- `staging`
- `production`

Attempting to kill a protected branch results in an error:

```
error: Cannot kill protected branch: main
```

## Uncommitted changes

If the worktree has uncommitted changes, aimux refuses to kill it:

```
error: Worktree has 3 uncommitted files. Use --force to override.
```

Use `--force` to override this safety check.

## Notes

- The target can be either a branch name or a full worktree path
- Branch resolution uses the convention `../<repo-name>-<branch>/`
- If the tmux window does not exist, that step is silently skipped
- If the git branch was already deleted, that step is silently skipped
- The kill command is idempotent -- running it twice on the same target is safe
