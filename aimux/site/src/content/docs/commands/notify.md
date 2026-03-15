---
title: aimux notify
description: Send multi-channel notifications
---

## Usage

```bash
aimux notify [options] <message>
```

**Alias:** `aimux n`

## Description

Sends a notification through one or more channels. Used internally by the daemon and witness, but available as a standalone command for scripting and custom workflows.

## Options

| Flag | Description |
|------|-------------|
| `--bell` | Send terminal bell character (`\a`) |
| `--osc` | Send OSC 9 (iTerm2, WezTerm) and OSC 99 (Kitty) escape sequences |
| `--native` | Send OS-native notification (macOS `osascript` / Linux `notify-send`) |
| `--webhook` | Send HTTP POST to configured webhook URL |
| `--all` | Send via bell, osc, and native channels (equivalent to `--bell --osc --native`) |
| `--title TITLE` / `-t TITLE` | Set notification title (default: `aimux`) |
| `--help` / `-h` | Show help |

## Examples

```bash
# Send via all default channels
aimux notify "Build complete"

# Desktop notification only
aimux notify --native "Tests passed"

# Custom title
aimux notify --native --title "CI" "Deployment successful"

# Terminal bell only (silent for scripts)
aimux notify --bell "Done"

# Webhook for Slack
aimux notify --webhook "Agent completed PROJ-123"

# All channels at once
aimux notify --all "Task finished"
```

## Channels

### bell

Sends the terminal bell character (`\a`). Most terminals will flash the tab or play a sound.

### osc

Sends two escape sequences:

- **OSC 9** -- notification protocol used by iTerm2 and WezTerm: `\033]9;<message>\007`
- **OSC 99** -- notification protocol used by Kitty: `\033]99;i=aimux:d=0;<message>\033\\`

### native

Platform-specific OS notifications:

- **macOS**: Uses `terminal-notifier` if installed (supports grouping via `--group aimux`), falls back to `osascript` display notification
- **Linux**: Uses `notify-send` if available

### webhook

Sends an HTTP POST request to the URL configured in `AIMUX_WEBHOOK_URL` or `~/.aimux/config.toml`:

```bash
curl -s -X POST "$url" \
  -H "Content-Type: application/json" \
  -d '{"text":"[aimux] Build complete"}'
```

The webhook request is sent in the background to avoid blocking. The payload format is compatible with Slack, Discord (via webhook proxy), and most webhook receivers.

## Default behavior

If no channel flags are specified, aimux sends via `bell`, `osc`, and `native` -- equivalent to `--all` without `--webhook`.

## Configuration

Webhook URL in `~/.aimux/config.toml`:

```toml
[notifications]
channels = ["bell", "osc", "native"]
webhook_url = "https://hooks.slack.com/services/T00/B00/xxx"
```

Or via environment variable:

```bash
export AIMUX_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxx"
```

## Notes

- The `--webhook` channel is a no-op if no webhook URL is configured
- The webhook POST is sent asynchronously (backgrounded) so it does not block the caller
- The daemon and witness use the notification system internally with deduplication (each event is notified once)
- The title defaults to `aimux` but can be overridden for custom integrations
