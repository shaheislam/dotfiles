---
title: Notifications
description: Configure notification channels for agent completion and stuck detection
---

## Overview

aimux notifies you when agents complete their tasks or get stuck. Notifications are sent through configurable channels, and events are deduplicated so you only get one notification per event.

## Configuration

In `~/.aimux/config.toml`:

```toml
[notifications]
channels = ["bell", "osc", "native"]
webhook_url = ""
```

## Channels

### bell

Sends the terminal bell character (`\a`). Most terminals respond by:

- Flashing the tab or window title
- Playing a system alert sound
- Bouncing the Dock icon (macOS)

This is the most universally supported notification method.

### osc

Sends OSC (Operating System Command) escape sequences for terminals that support them:

- **OSC 9** -- Used by iTerm2 and WezTerm: `\033]9;<message>\007`
- **OSC 99** -- Used by Kitty: `\033]99;i=aimux:d=0;<message>\033\\`

These display an in-terminal notification popup with the message text.

### native

Uses the operating system's native notification system:

**macOS:**
1. `terminal-notifier` (if installed) -- supports grouping, click actions, and custom icons
   ```bash
   terminal-notifier -title "aimux" -message "Agent complete" -group aimux
   ```
2. `osascript` (fallback) -- built-in macOS notification
   ```bash
   osascript -e 'display notification "Agent complete" with title "aimux"'
   ```

**Linux:**
- `notify-send` (requires `libnotify`)
  ```bash
  notify-send "aimux" "Agent complete"
  ```

Install `terminal-notifier` on macOS for the best experience:

```bash
brew install terminal-notifier
```

### webhook

Sends an HTTP POST request to a configured URL. The payload format is compatible with Slack, Discord (via webhook proxy), and most webhook receivers:

```json
{
  "text": "[aimux] Agent completed: feature-auth"
}
```

Configure the URL:

```toml
[notifications]
webhook_url = "https://hooks.slack.com/services/T00/B00/xxx"
```

Or via environment variable:

```bash
export AIMUX_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxx"
```

The webhook request is sent asynchronously (backgrounded) so it does not block the caller.

## Notification events

### Daemon notifications

The daemon sends notifications for two events:

| Event | Trigger | Message |
|-------|---------|---------|
| Completion | Agent state changes to `done` | `Agent complete: <window_name>` |
| Stuck | Agent idle for `stuck_timeout` seconds | `Agent stuck: <window_name> (<seconds>s idle)` |

Both events are deduplicated using flag files in `/tmp/`:
- `/tmp/aimux-notified-<pane_key>` -- prevents duplicate completion notifications
- `/tmp/aimux-stuck-<pane_key>` -- prevents duplicate stuck notifications

Flag files are cleaned up when the agent process exits the pane.

### Witness notifications

The witness sends notifications when:

| Event | Message |
|-------|---------|
| Task completed | `Agent completed: <workspace>` |
| Task failed (max retries) | `Agent failed (stuck): <workspace>` |

Witness notifications use the `aimux notify --all` command, sending via bell, osc, and native channels.

## Manual notifications

Use `aimux notify` to send notifications from scripts:

```bash
# All default channels
aimux notify "Build complete"

# Specific channels
aimux notify --native "Tests passed"
aimux notify --webhook "Deployment successful"
aimux notify --bell --osc "Quick alert"

# Custom title
aimux notify --native --title "CI Pipeline" "All checks green"
```

## Slack integration

### Setup

1. Create a Slack incoming webhook at [api.slack.com/messaging/webhooks](https://api.slack.com/messaging/webhooks)
2. Copy the webhook URL
3. Add to config:

```toml
[notifications]
channels = ["native", "webhook"]
webhook_url = "https://hooks.slack.com/services/T00/B00/xxx"
```

### Channel formatting

Slack displays the notification as:

> [aimux] Agent completed: feature-auth

## Discord integration

Discord requires a Slack-compatible webhook format. Use the `/slack` suffix:

```toml
[notifications]
webhook_url = "https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN/slack"
```

## Example configurations

### Desktop-only (no webhook)

```toml
[notifications]
channels = ["bell", "osc", "native"]
```

### Slack + Desktop

```toml
[notifications]
channels = ["native", "webhook"]
webhook_url = "https://hooks.slack.com/services/T00/B00/xxx"
```

### Bell only (headless/CI)

```toml
[notifications]
channels = ["bell"]
```

### All channels

```toml
[notifications]
channels = ["bell", "osc", "native", "webhook"]
webhook_url = "https://hooks.slack.com/services/T00/B00/xxx"
```
