# Configuration

aimux reads configuration from `~/.aimux/config.toml`. All values have sensible defaults. Copy the shipped default config to get started:

```bash
mkdir -p ~/.aimux
cp "$(brew --prefix)/share/aimux/default.toml" ~/.aimux/config.toml
# or from source:
cp config/default.toml ~/.aimux/config.toml
```

## Complete Reference

### [general]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `poll_interval` | int | `10` | Seconds between daemon poll cycles |
| `stuck_timeout` | int | `300` | Seconds of no output change before marking agent "stuck" |
| `default_provider` | string | `"claude"` | Default AI provider for `aimux run` |
| `log_file` | string | `~/.aimux/aimuxd.log` | Daemon log file path |

### [notifications]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `channels` | array | `["bell", "osc", "native"]` | Active notification channels |
| `webhook_url` | string | `""` | Webhook URL for Slack/Discord (empty = disabled) |

Available channels:
- `bell` -- terminal bell character
- `osc` -- OSC 9 (iTerm2, WezTerm) and OSC 99 (kitty) escape sequences
- `native` -- OS notifications (macOS `osascript` / Linux `notify-send`)
- `webhook` -- HTTP POST to configured URL

### [queue]

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `max_concurrent` | int | `3` | Maximum concurrent ticket executions |
| `cooldown` | int | `60` | Seconds between dispatching queue entries |

### [providers.<name>]

Provider-specific configuration. See `docs/providers.md` for the full provider API.

| Key | Type | Description |
|-----|------|-------------|
| `command` | string | Binary name or path |
| `args` | array | Default arguments |
| `detect_patterns` | array | Process name patterns for TTY detection |
| `working_pattern` | string | Regex pattern indicating active generation |
| `done_patterns` | array | Fixed strings indicating task completion |

## Environment Variable Overrides

Every config key can be overridden with an `AIMUX_` prefixed environment variable. The mapping strips the `general.` prefix for top-level keys and converts dots and lowercase to underscores and uppercase.

| Config Key | Environment Variable |
|-----------|---------------------|
| `general.poll_interval` | `AIMUX_POLL_INTERVAL` |
| `general.stuck_timeout` | `AIMUX_STUCK_TIMEOUT` |
| `general.default_provider` | `AIMUX_DEFAULT_PROVIDER` |
| `general.log_file` | `AIMUX_LOG_FILE` |
| `notifications.webhook_url` | `AIMUX_WEBHOOK_URL` |
| `notifications.channels` | `AIMUX_NOTIFICATION_CHANNELS` (comma-separated) |
| `queue.max_concurrent` | `AIMUX_QUEUE_MAX_CONCURRENT` |
| `queue.cooldown` | `AIMUX_QUEUE_COOLDOWN` |

Additionally:
- `AIMUX_HOME` -- config directory (default: `~/.aimux`)

## Example Configurations

### Minimal (fast polling, webhook)

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

### Self-hosted only (ollama default)

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

## Config Hierarchy

Resolution order (later wins):

1. Compiled defaults (`internal/config/config.go`)
2. Shipped defaults (`config/default.toml`)
3. User config (`~/.aimux/config.toml`)
4. Environment variables (`AIMUX_*`)

Both the bash CLI and Go daemon read the same `~/.aimux/config.toml` file. The bash scripts use a built-in line-by-line TOML parser (`lib/aimux/_config.sh`); the Go daemon uses `BurntSushi/toml`.
