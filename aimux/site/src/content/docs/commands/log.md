---
title: aimux log
description: View agent output logs
---

## Usage

```bash
aimux log [options] [workspace]
```

**Alias:** `aimux l`

## Description

View logs from agent execution. Logs are captured via `tmux pipe-pane` when workspaces are created, storing all terminal output to `~/.aimux/logs/<workspace>.log`.

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--follow` | `-f` | Follow log output in real-time (like `tail -f`) |
| `--all` | `-a` | Show logs from all workspaces |
| `--clear` | | Clear log file(s) instead of displaying them |
| `--help` | `-h` | Show help |

## Examples

```bash
# View recent output from a specific workspace
aimux log my-workspace

# Follow output in real-time
aimux log my-workspace --follow

# View logs from all workspaces
aimux log --all

# Follow all workspace logs simultaneously
aimux log --all --follow

# Clear a specific workspace log
aimux log my-workspace --clear

# Clear all logs
aimux log --all --clear

# Auto-detect workspace from current directory
cd ~/projects/myapp-feature-auth
aimux log
```

## What happens

### Single workspace

Without `--all`, aimux displays the last 100 lines of the workspace's log file.

If no workspace name is given, aimux attempts to detect it from the current directory by combining the repo name and branch name (e.g., `myapp-feature-auth`).

With `--follow`, it uses `tail -f` for real-time streaming.

### All workspaces

With `--all`, aimux iterates over all log files in `~/.aimux/logs/` and displays the last 50 lines of each, separated by headers:

```
=== myapp-auth-001 ===
[agent output...]

=== myapp-feat-002 ===
[agent output...]
```

With `--all --follow`, it uses `tail -f` on all log files simultaneously, interleaving output.

### Partial name matching

If the exact log file is not found, aimux searches for a partial match:

```bash
# These all work if the log file is "myapp-auth-001.log"
aimux log myapp-auth-001
aimux log auth-001
aimux log auth
```

### Clear mode

With `--clear`, log files are deleted instead of displayed:

```bash
aimux log my-workspace --clear   # Delete one log
aimux log --all --clear          # Delete all logs
```

Clearing requires either a workspace name or `--all`.

## Log file location

Logs are stored in `~/.aimux/logs/`:

```
~/.aimux/logs/
  myapp-auth-001.log
  myapp-feat-002.log
  myapp-test-003.log
```

Each log file contains the raw terminal output captured from the workspace's tmux pane via `tmux pipe-pane`.

## Notes

- Log capture starts when `aimux new` creates a workspace
- Logs persist after `aimux kill` removes a workspace (unless `kill` explicitly cleans them up)
- The `--follow` flag blocks until interrupted with Ctrl-C
- Log files can grow large during extended agent runs -- use `--clear` periodically
- Partial name matching returns the first match found
