---
title: aimux daemon
description: Agent state monitoring daemon with provider detection
---

## Usage

```bash
aimux daemon <command>
```

## Description

Background daemon that polls all tmux panes, detects AI agent processes, analyzes their output to determine state, color-codes tmux windows, and sends notifications on completion or stuck detection.

## Commands

### daemon start

Start the background daemon process.

```bash
aimux daemon start
```

The daemon:
- Runs as a background process with PID stored in `/tmp/aimux-daemon.pid`
- Polls all tmux panes every `poll_interval` seconds (default: 10)
- Uses the provider plugin system to detect agent processes on each pane's TTY
- Captures the last 20 lines of terminal output per pane
- Analyzes content with `detect_state` to determine: `working`, `idle`, `done`, or `stuck`
- Tracks content changes via MD5 hashing for stuck detection
- Sets tmux window color via `@wname_style` option
- Sends deduplicated notifications on completion or stuck events

### daemon stop

Stop the running daemon.

```bash
aimux daemon stop
```

Sends SIGTERM and removes the PID file.

### daemon status

Check whether the daemon is running.

```bash
aimux daemon status
```

Outputs `running (PID: <pid>)` or `stopped`.

### daemon poll

Run a single poll cycle manually (useful for debugging).

```bash
aimux daemon poll
```

Executes one poll iteration inline (not backgrounded), checking all tmux panes.

## State detection

The daemon determines agent state through a pipeline:

1. **Process detection**: For each tmux pane, checks the pane's TTY for known agent processes using `provider_detect()`
2. **Content capture**: Captures the last 20 lines of terminal output with `tmux capture-pane`
3. **Provider analysis**: Passes captured content to `provider_detect_state()` which returns `working`, `idle`, or `done`
4. **Stuck detection**: If content has not changed for `stuck_timeout` seconds (default: 300) and state is not `done`, overrides state to `stuck`

## Window color coding

The daemon sets tmux window colors using the Tokyo Night palette:

| State | Color | Hex |
|-------|-------|-----|
| Working | Red | `#f7768e` |
| Idle/Waiting | Yellow | `#e0af68` |
| Done | Green | `#9ece6a` |
| Stuck | Magenta | `#bb9af7` |

Colors are applied via `tmux set-window-option @wname_style`. When no agent is detected on a pane, the color is cleared.

## Notifications

The daemon sends notifications on two events:

- **Completion**: When an agent's state changes to `done`
- **Stuck**: When an agent's output has not changed for `stuck_timeout` seconds

Notifications are deduplicated using flag files in `/tmp/aimux-notified-<pane>` and `/tmp/aimux-stuck-<pane>`. Each event is only notified once per pane lifecycle.

Notification channels:
- **macOS**: `osascript` display notification (or `terminal-notifier` if available)
- **Linux**: `notify-send`
- **Terminal bell**: `\a` character

## Configuration

```toml
[general]
poll_interval = 10     # Seconds between poll cycles
stuck_timeout = 300    # Seconds before marking as stuck
```

Environment variable overrides:

```bash
export AIMUX_POLL_INTERVAL=5
export AIMUX_STUCK_TIMEOUT=600
```

## Go daemon (aimuxd)

If the Go binary `aimuxd` is installed, it provides an enhanced daemon with:

- Proper signal handling (SIGTERM, SIGINT)
- PID file locking with flock to prevent duplicate daemons
- Integrated queue dispatch
- Structured logging

The bash daemon (`aimux daemon start`) is the default and requires no extra dependencies.

## Notes

- The daemon requires tmux to be running
- Provider detection uses both the plugin `detect()` function and a fallback process name scan
- Only panes with detected agent processes are monitored (others are skipped)
- Content hashing resets when content changes, so brief output updates reset the stuck timer
- The daemon cleans up tracking state when an agent process exits a pane
