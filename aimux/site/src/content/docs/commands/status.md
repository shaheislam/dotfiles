---
title: aimux status
description: Show all workspaces with agent state
---

## Usage

```bash
aimux status [options]
```

**Alias:** `aimux st`

## Description

Displays a table of all tracked workspaces with their branch, container status, agent state, and provider. Combines data from persistent state files and live git/tmux queries.

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--json` | `-j` | Output machine-readable JSON instead of the table |
| `--all` | `-a` | Include workspaces from state files even if they are outside the current repository |
| `--help` | `-h` | Show help |

## Examples

```bash
# Table view of all workspaces
aimux status

# JSON output for scripting
aimux status --json

# Include all tracked workspaces across repos
aimux status --all

# Pipe JSON to jq for filtering
aimux status --json | jq '.[] | select(.status == "running")'
```

## Table output

```
WORKTREE                                 BRANCH                    CONTAINER    AGENT      PROVIDER
──────────────────────────────────────── ───────────────────────── ──────────── ────────── ──────────
*/Users/me/projects/myapp                main                      -            -          -
 /Users/me/projects/myapp-auth-001       auth-001                  running      working    claude
 /Users/me/projects/myapp-feat-002       feat-002                  -            idle       codex
 /Users/me/projects/myapp-test-003       test-003                  stopped      done       claude
```

Column descriptions:

| Column | Description |
|--------|-------------|
| `WORKTREE` | Path to the git worktree. `*` marks the current worktree. Long paths are truncated. |
| `BRANCH` | Git branch name |
| `CONTAINER` | Devcontainer status: `running`, `stopped`, or `-` (no container) |
| `AGENT` | Agent lifecycle state: `working`, `waiting`, `done`, `stuck`, `failed`, or `-` |
| `PROVIDER` | AI provider name (`claude`, `codex`, `ollama`, etc.) or `-` |

## Agent state colors

| State | Color | Meaning |
|-------|-------|---------|
| `working` / `active` / `running` | Red | Agent is actively generating output |
| `waiting` / `idle` | Yellow | Agent is idle, awaiting input |
| `done` / `completed` | Green | Agent completed its task |
| `stuck` | Magenta | No output change for >5 minutes |
| `failed` | Red | Agent failed after max retries |

## JSON output

When `--json` is passed, the output is a JSON array:

```json
[
  {
    "name": "myapp-auth-001",
    "branch": "auth-001",
    "worktree": "/Users/me/projects/myapp-auth-001",
    "status": "working",
    "provider": "claude",
    "ticket": "AUTH-001",
    "container": "running",
    "source": "state"
  }
]
```

The `source` field indicates where the data came from:
- `state` -- from a persisted state file in `~/.aimux/state/`
- `live` -- discovered from live git worktree queries

## How state is determined

1. **State files** are read first from `~/.aimux/state/*.json` (preferred source)
2. **Live git worktree** data supplements state files with worktrees not yet tracked
3. **Container status** is checked via `docker ps` for matching container names
4. **Agent state from tmux** is read from tmux window option `@wname_style` (set by the daemon)
5. State file values take precedence over live-detected values

## Notes

- The current worktree (matching your working directory) is marked with `*`
- Worktree paths longer than 38 characters are truncated with a leading `...`
- Container detection requires Docker to be running
- Live agent state detection requires being inside tmux
