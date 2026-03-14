# aimux

**The AI Agent Multiplexer** -- terminal-agnostic agent orchestration for tmux.

Manage multiple AI coding agents (Claude Code, Codex, Ollama, etc.) across isolated workspaces with real-time state monitoring, notifications, queue dispatch, and autonomous ticket execution.

## Why aimux?

| Feature | cmux | aimux |
|---------|------|-------|
| Terminal support | Ghostty only | Any terminal emulator |
| Platform | macOS only | macOS + Linux |
| Agent monitoring | Notification rings | 4-state lifecycle (working/idle/done/stuck) |
| Provider support | Claude only | Pluggable: Claude, Codex, Ollama, custom |
| Orchestration | None | Worktree + devcontainer isolation |
| Session persistence | None | tmux detach/attach + JSON state files |
| Autonomous execution | None | Provider-agnostic retry loops |
| Queue system | None | Priority queue with concurrent dispatch |
| Configuration | Hardcoded | TOML config + env var overrides |
| Notifications | Native macOS + OSC | Terminal bell + OSC + native + webhook |
| Daemon | Bash polling | Go binary with signal handling + flock |

## Quick Start

```bash
# Install via Homebrew
brew tap shaheislam/aimux
brew install aimux

# Verify setup
aimux doctor

# Add tmux status bar integration (optional)
echo 'source-file /usr/local/share/aimux/aimux.tmux.conf' >> ~/.tmux.conf
```

### Create a workspace

```bash
aimux new feature-auth     # creates git worktree + tmux window
```

### Execute a ticket autonomously

```bash
aimux run PROJ-123 "Fix the authentication bug in login flow"
aimux run --provider codex TASK-456 "Refactor utils"
```

### Monitor agents

```bash
aimux status               # table of all workspaces with agent state
aimux daemon start         # background monitoring + OS notifications
aimux log -f feature-auth  # follow workspace logs
```

### Queue tickets

```bash
aimux queue add PROJ-789 "Add unit tests"
aimux queue add --priority 0 HOTFIX-001 "Fix prod outage"
aimux queue start          # start dispatching queued tickets
aimux queue status         # show queue state
```

### Cleanup

```bash
aimux kill feature-auth    # removes worktree, container, branch, tmux window
```

## Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `aimux new <branch>` | | Create workspace (worktree + tmux window) |
| `aimux status` | `st` | Show all workspaces with agent state |
| `aimux run <ticket> [msg]` | | Execute ticket autonomously |
| `aimux attach [name]` | `a` | Attach to workspace (fzf picker if no name) |
| `aimux kill <name>` | `k` | Kill workspace + cleanup worktree |
| `aimux doctor` | | Health check for dependencies and daemons |
| `aimux daemon <cmd>` | | Agent state monitoring daemon (start/stop/status) |
| `aimux queue <cmd>` | `q` | Ticket queue management (add/list/start/stop/status) |
| `aimux log [workspace]` | `l` | View agent output logs (-f to follow) |
| `aimux notify <msg>` | `n` | Send multi-channel notification |

## Provider System

aimux uses a pluggable provider system. Three providers ship built-in:

| Provider | Command | Use Case |
|----------|---------|----------|
| `claude` (default) | `claude --effort max` | Claude Code agent |
| `codex` | `codex --full-auto` | OpenAI Codex CLI |
| `ollama` | `ollama run` | Self-hosted local models |

Select a provider per-run or set the default in config:

```bash
aimux run --provider codex PROJ-123 "Fix the bug"
```

Custom providers are shell scripts placed in `~/.aimux/providers/`. See `docs/providers.md` for the API.

## Agent States

The daemon monitors tmux panes and color-codes windows in your status bar:

| State | Color | Meaning |
|-------|-------|---------|
| Working | Red | Agent is actively generating output |
| Waiting | Yellow | Agent is idle, awaiting input |
| Done | Green | Agent completed its task |
| Stuck | Magenta | No output change for >5 minutes |

Detection uses terminal content analysis -- no agent-specific integration needed.

## Configuration

Settings in `~/.aimux/config.toml`:

```toml
[general]
poll_interval = 10          # seconds between daemon poll cycles
stuck_timeout = 300         # seconds before marking agent "stuck"
default_provider = "claude" # claude, codex, ollama, or custom

[notifications]
channels = ["bell", "osc", "native"]
webhook_url = ""            # Slack/Discord webhook URL

[queue]
max_concurrent = 3          # max simultaneous ticket executions
cooldown = 60               # seconds between queue dispatches

[providers.claude]
command = "claude"
args = ["--effort", "max"]
```

All config values can be overridden with environment variables:

| Variable | Description |
|----------|-------------|
| `AIMUX_HOME` | Config directory (default: `~/.aimux`) |
| `AIMUX_POLL_INTERVAL` | Daemon poll interval in seconds |
| `AIMUX_STUCK_TIMEOUT` | Seconds before marking stuck |
| `AIMUX_DEFAULT_PROVIDER` | Default provider name |
| `AIMUX_WEBHOOK_URL` | Webhook URL for notifications |
| `AIMUX_QUEUE_MAX_CONCURRENT` | Max concurrent queue dispatches |

See `docs/configuration.md` for the full reference.

## Requirements

| Dependency | Required | Purpose |
|-----------|----------|---------|
| tmux | Yes | Terminal multiplexing |
| git | Yes | Worktree management |
| bash 4+ | Yes | CLI runtime |
| Go 1.22+ | Build only | Daemon binary |
| fzf | Recommended | Interactive workspace picker |
| jq | Recommended | JSON parsing |
| docker | Optional | Devcontainer support |

## Install from Source

```bash
git clone https://github.com/shaheislam/aimux.git
cd aimux
make build                     # build Go daemon
make install                   # install to /usr/local
make install PREFIX=~/.local   # or install to ~/.local
```

## Testing

```bash
make test          # run all tests (BATS + Go)
make test-bash     # run BATS tests only
make test-go       # run Go tests only
make lint          # shellcheck + go vet
```

## Architecture

aimux is a two-layer system: a bash CLI dispatcher for user interaction and a Go daemon for background monitoring.

```
aimux/
  bin/aimux                 # CLI entry point (bash dispatcher)
  lib/aimux/
    _common.sh              # Shared utilities (colors, git, state)
    _config.sh              # TOML config parser + env overrides
    _provider.sh            # Provider plugin loader
    _witness.sh             # Agent lifecycle witness
    providers/              # Built-in provider plugins
      claude.sh
      codex.sh
      ollama.sh
    new.sh                  # Workspace creation
    status.sh               # Status table display
    run.sh                  # Autonomous ticket execution
    kill.sh                 # Workspace cleanup
    log.sh                  # Log viewer
    queue.sh                # Queue management
    daemon.sh               # Agent state monitoring
    doctor.sh               # Health check
    attach.sh               # Session attachment
    notify.sh               # Multi-channel notifications
    help.sh                 # Help text
  cmd/aimuxd/               # Go daemon entry point
  internal/
    config/                 # Go config (TOML + env overrides)
    state/                  # Workspace + agent state management
    queue/                  # Priority queue + dispatcher
    daemon/                 # Daemon loop + signal handling
  config/
    default.toml            # Default configuration
    aimux.tmux.conf         # tmux status bar integration
  templates/launch/         # Agent launch script templates
  completions/              # Fish, Bash, Zsh completions
  Formula/aimux.rb          # Homebrew formula
  tests/
    test_cli.bats           # CLI smoke tests
    unit/                   # Unit tests for shell libraries
    integration/            # Integration tests with git + tmux
  docs/
    architecture.md         # System design
    providers.md            # Provider plugin API
    configuration.md        # Config reference
    migration.md            # Migration from gwt-* functions
```

See `docs/architecture.md` for data flow diagrams and design decisions.

## Migration from gwt-* Functions

If you are coming from the dotfiles `gwt-*` Fish functions, see `docs/migration.md` for a command mapping table and migration guide.

Key mappings:
- `gwt-dev` / `gwtd` -> `aimux new`
- `gwt-ticket` / `gwtt` -> `aimux run`
- `gwt-status` / `gwts` -> `aimux status`
- `gwt-cleanup` / `gwtclean` -> `aimux kill`
- `gwt-doctor` / `gwtdoc` -> `aimux doctor`

## License

MIT
