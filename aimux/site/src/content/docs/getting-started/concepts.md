---
title: Core Concepts
description: How aimux organizes workspaces, agents, and state
---

## Workspaces

A workspace is the unit of isolation in aimux. Each workspace consists of:

- **Git worktree** -- a full working copy of your repo on a separate branch
- **tmux window** -- a terminal session for the workspace
- **State file** -- JSON tracking workspace status, agent state, and metadata

Workspaces are created with `aimux new` and destroyed with `aimux kill`. The worktree path follows the convention `../<repo-name>-<branch-name>/`, so a workspace for branch `feature-auth` in the `myapp` repo lives at `../myapp-feature-auth/`.

## Providers

A provider is an AI coding agent. aimux ships with three built-in providers:

| Provider | Command | Description |
|----------|---------|-------------|
| `claude` | `claude --effort max` | Claude Code (Anthropic) |
| `codex` | `codex --full-auto` | Codex CLI (OpenAI) |
| `ollama` | `ollama run` | Local models via Ollama |

Providers are bash plugins. Each implements three functions:

- **`launch_cmd`** -- returns the shell command to start the agent
- **`detect`** -- checks if the agent process is running on a given TTY
- **`detect_state`** -- analyzes terminal output to determine working/idle/done state

Custom providers are placed in `~/.aimux/providers/`. User-defined providers take precedence over built-in ones with the same name. See the [Custom Providers](/guides/custom-providers/) guide for details.

## The Daemon

The daemon (`aimux daemon start`) is a background process that:

1. Polls all tmux panes every `poll_interval` seconds (default: 10)
2. Detects which provider is running in each pane
3. Captures terminal output and analyzes it via the provider's `detect_state` function
4. Color-codes tmux windows by state using Tokyo Night colors
5. Tracks output changes for stuck detection via content hashing
6. Sends notifications on completion or stuck events (deduplicated)

Two daemon implementations exist:

- **Bash daemon** -- built into the CLI (`aimux daemon start`), no extra dependencies
- **Go daemon** (`aimuxd`) -- proper signal handling, PID file locking with flock, and integrated queue dispatch

## The Witness

When you use `aimux run`, a witness process is spawned that monitors a single workspace:

1. Monitors the agent's tmux pane at the configured `poll_interval`
2. Captures the last 30 lines of terminal output
3. Detects agent state via the provider's detection patterns
4. Tracks content changes via MD5 hashing for stuck detection
5. If no output changes for `stuck_timeout` seconds (default: 300), marks the agent as stuck
6. On stuck: sends Ctrl-C, waits 2 seconds, re-executes the launch script
7. After `max_retries` (default: 3) failed restart attempts, marks the task as failed
8. On completion: updates state file, sends notifications via all configured channels

The witness stores its PID in `~/.aimux/state/<workspace>.witness.pid` and cleans up on exit.

## The Queue

The queue system enables batch execution:

1. Add tickets with `aimux queue add`
2. Each entry has a ticket key, prompt, provider, and priority (1-10, higher = first)
3. Start the dispatcher with `aimux queue start`
4. The dispatcher runs as a background process, polling the queue
5. It launches tickets via `aimux run` when capacity is available
6. Respects `max_concurrent` (default: 3) and `cooldown` (default: 60s) settings
7. Monitors state files to detect completed or failed runs

Queue state is persisted in `~/.aimux/queue.json` with entries progressing through: `queued` -> `dispatching` -> `running` -> `completed`/`failed`.

## State Files

All state is stored as JSON in `~/.aimux/state/`:

```json
{
  "status": "running",
  "branch": "feature-auth",
  "worktree": "/Users/me/projects/app-feature-auth",
  "repo": "/Users/me/projects/app",
  "provider": "claude",
  "ticket": "AUTH-001",
  "prompt": "Implement OAuth2 login flow",
  "tmux_target": "main:3.0",
  "started_at": "2026-03-14T10:00:05Z",
  "max_retries": "3",
  "attempts": "0",
  "idle_seconds": "12"
}
```

Key design properties:

- **Atomic writes** -- state is written to a temp file and atomically renamed to prevent corruption
- **Decoupled readers** -- the CLI reads state files for `aimux status`, the daemon writes during polling, and the witness writes during monitoring. They operate independently.
- **Crash recovery** -- state files persist across daemon restarts, terminal disconnects, and SSH reconnects. The daemon and witness pick up where they left off.

## Architecture

aimux is a two-layer system:

```
User -> bin/aimux (bash CLI dispatcher) -> lib/aimux/*.sh (subcommand scripts)
                                        -> aimuxd (Go daemon, optional)

lib/aimux/
  _common.sh     Shared utilities, colors, state management
  _config.sh     TOML parser + env var overrides
  _provider.sh   Provider plugin loader
  _witness.sh    Per-workspace lifecycle monitor
  providers/     Built-in provider plugins (claude, codex, ollama)
```

Both the bash CLI and Go daemon read the same `~/.aimux/config.toml` file. The bash scripts use a built-in line-by-line TOML parser; the Go daemon uses `BurntSushi/toml`.

## Configuration Hierarchy

Configuration is resolved in this order (later wins):

1. Compiled defaults
2. Shipped defaults (`config/default.toml`)
3. User config (`~/.aimux/config.toml`)
4. Environment variables (`AIMUX_*`)

See the [Configuration Reference](/configuration/reference/) for all settings and their environment variable overrides.
