---
title: Configuration Reference
description: Complete reference for all aimux configuration options
---

aimux reads configuration from `~/.aimux/config.toml`. All values have sensible defaults. Copy the shipped default config to get started:

```bash
mkdir -p ~/.aimux
cp config/default.toml ~/.aimux/config.toml
# or if installed via Homebrew:
cp "$(brew --prefix)/share/aimux/default.toml" ~/.aimux/config.toml
```

## Complete TOML reference

### [general]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `poll_interval` | int | `10` | Seconds between daemon/witness poll cycles |
| `stuck_timeout` | int | `300` | Seconds of no output change before marking agent "stuck" |
| `default_provider` | string | `"claude"` | Default AI provider for `aimux run` |
| `log_file` | string | `~/.aimux/aimuxd.log` | Daemon log file path |

### [notifications]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `channels` | array | `["bell", "osc", "native"]` | Active notification channels |
| `webhook_url` | string | `""` | Webhook URL for Slack/Discord integration (empty = disabled) |

Available channels:

| Channel | Description |
|---------|-------------|
| `bell` | Terminal bell character (`\a`) |
| `osc` | OSC 9 (iTerm2, WezTerm) and OSC 99 (Kitty) escape sequences |
| `native` | OS notifications -- macOS `osascript` or `terminal-notifier`, Linux `notify-send` |
| `webhook` | HTTP POST to configured URL with `{"text":"[aimux] message"}` payload |

### [queue]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `max_concurrent` | int | `3` | Maximum simultaneous ticket executions dispatched by the queue |
| `cooldown` | int | `60` | Seconds to wait between dispatching queue entries |

### [providers.\<name\>]

Provider-specific configuration. See [Providers](/configuration/providers/) for the full API.

| Key | Type | Description |
|-----|------|-------------|
| `command` | string | Binary name or path to the agent executable |
| `args` | array | Default arguments passed to the command |
| `detect_patterns` | array | Process name patterns for TTY detection |
| `working_pattern` | string | Regex pattern indicating active generation |
| `done_patterns` | array | Fixed strings indicating task completion |

## Default configuration file

```toml
[general]
poll_interval = 10
stuck_timeout = 300
default_provider = "claude"

[notifications]
channels = ["bell", "osc", "native"]
webhook_url = ""

[queue]
max_concurrent = 3
cooldown = 60

[providers.claude]
command = "claude"
args = ["--effort", "max"]
detect_patterns = ["claude"]
working_pattern = "... \\("
done_patterns = ["COMPLETE", "_DONE", "TICKET_TASK_COMPLETE"]

[providers.codex]
command = "codex"
args = ["--full-auto"]
detect_patterns = ["codex"]
working_pattern = ""
done_patterns = ["COMPLETE"]

[providers.ollama]
command = "ollama"
args = ["run"]
detect_patterns = ["ollama"]
working_pattern = ""
done_patterns = [">>>"]
```

## Environment variable overrides

Every config key can be overridden with an `AIMUX_` prefixed environment variable. The mapping strips the `general.` prefix for top-level keys and converts dots and lowercase to underscores and uppercase:

| Config Key | Environment Variable |
|-----------|---------------------|
| `general.poll_interval` | `AIMUX_POLL_INTERVAL` |
| `general.stuck_timeout` | `AIMUX_STUCK_TIMEOUT` |
| `general.default_provider` | `AIMUX_DEFAULT_PROVIDER` |
| `general.log_file` | `AIMUX_LOG_FILE` |
| `notifications.webhook_url` | `AIMUX_WEBHOOK_URL` |
| `notifications.channels` | `AIMUX_NOTIFICATION_CHANNELS` |
| `queue.max_concurrent` | `AIMUX_QUEUE_MAX_CONCURRENT` |
| `queue.cooldown` | `AIMUX_QUEUE_COOLDOWN` |
| `providers.claude.command` | `AIMUX_PROVIDERS_CLAUDE_COMMAND` |

Additionally:

| Variable | Description | Default |
|----------|-------------|---------|
| `AIMUX_HOME` | Configuration and state directory | `~/.aimux` |

## Config hierarchy

Resolution order (later wins):

1. **Compiled defaults** -- hardcoded in `internal/config/config.go`
2. **Shipped defaults** -- `config/default.toml` in the aimux installation
3. **User config** -- `~/.aimux/config.toml`
4. **Environment variables** -- `AIMUX_*` prefixed variables

Both the bash CLI and Go daemon read the same `~/.aimux/config.toml` file. The bash scripts use a built-in line-by-line TOML parser (`lib/aimux/_config.sh`); the Go daemon uses `BurntSushi/toml`.

## Example configurations

### Minimal (fast polling, Slack webhook)

```toml
[general]
poll_interval = 5

[notifications]
channels = ["native", "webhook"]
webhook_url = "https://hooks.slack.com/services/T00/B00/xxx"
```

### Multi-agent team (high concurrency)

```toml
[general]
poll_interval = 5
stuck_timeout = 600

[queue]
max_concurrent = 6
cooldown = 30

[providers.claude]
command = "claude"
args = ["--effort", "max"]
```

### Self-hosted only (Ollama default)

```toml
[general]
default_provider = "ollama"
poll_interval = 15
stuck_timeout = 120

[notifications]
channels = ["bell"]

[providers.ollama]
command = "ollama"
args = ["run", "qwen2.5-coder:32b"]
```

### Codex with account rotation

```toml
[general]
default_provider = "codex"

[providers.codex]
command = "codex-rotate"
args = ["--full-auto"]
```

## File system layout

```
~/.aimux/
  config.toml           User configuration (overrides defaults)
  aimux.log             CLI activity log
  aimuxd.log            Daemon log
  state/
    repo-feature-auth.json    Per-workspace state files
    repo-feature-auth.witness.pid
  queue.json            Ticket execution queue
  logs/
    repo-feature-auth.log     Per-workspace agent output logs
  providers/
    my-agent.sh         User-defined custom providers
```
