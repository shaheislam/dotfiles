# aimux

**The AI Agent Multiplexer** — terminal-agnostic agent orchestration for tmux.

Manage multiple AI coding agents (Claude Code, Codex, etc.) across isolated workspaces with real-time state monitoring, notifications, and autonomous ticket execution.

## Why aimux?

| Feature | cmux | aimux |
|---------|------|-------|
| Terminal support | Ghostty only | Any terminal |
| Platform | macOS only | macOS + Linux |
| Agent monitoring | Notification rings | 4-state lifecycle (working/idle/done/stuck) |
| Orchestration | None | Worktree + devcontainer isolation |
| Session persistence | None | tmux detach/attach + restore |
| Autonomous execution | None | Retry loops + checkpoints |
| Notifications | Native macOS + OSC | Terminal bell + OSC + native + webhook |

## Quick Start

```bash
# Install
brew tap shaheislam/aimux
brew install aimux

# Verify setup
aimux doctor

# Add tmux integration (optional)
echo 'source-file /usr/local/share/aimux/aimux.tmux.conf' >> ~/.tmux.conf
```

### Create a workspace

```bash
aimux new feature-auth     # creates git worktree + tmux window
```

### Monitor agents

```bash
aimux status               # table of all workspaces with agent state
aimux daemon start         # background monitoring + OS notifications
```

### Execute a ticket autonomously

```bash
aimux run PROJ-123 "Fix the authentication bug in login flow"
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
| `aimux notify <msg>` | `n` | Send multi-channel notification |
| `aimux queue <cmd>` | `q` | Ticket queue management |

## Agent States

aimux daemon monitors tmux panes and color-codes windows in your status bar:

| State | Color | Meaning |
|-------|-------|---------|
| Working | Red | Agent is actively generating output |
| Waiting | Yellow | Agent is idle, awaiting input |
| Done | Green | Agent completed its task |
| Stuck | Magenta | No output for >5 minutes while working |

Detection uses terminal content analysis — no agent-specific integration needed.

## Configuration

Settings in `~/.aimux/config.yaml` (created on first use):

```yaml
notifications:
  native: true       # OS notifications on agent completion
  sound: true        # terminal bell
  webhook: ""        # Slack/Discord webhook URL

agent:
  poll_interval: 10  # seconds between state checks
  stuck_timeout: 300 # seconds before marking stuck
```

Environment variables:
- `AIMUX_HOME` — config directory (default: `~/.aimux`)
- `AIMUX_POLL_INTERVAL` — daemon poll interval in seconds
- `AIMUX_WEBHOOK_URL` — webhook URL for notifications

## Requirements

| Dependency | Required | Purpose |
|-----------|----------|---------|
| tmux | Yes | Terminal multiplexing |
| git | Yes | Worktree management |
| bash 4+ | Yes | CLI runtime |
| fzf | Recommended | Interactive selection |
| jq | Recommended | JSON parsing |
| docker | Optional | Devcontainer support |

## Install from source

```bash
git clone https://github.com/shaheislam/aimux.git
cd aimux
make install           # installs to /usr/local
# or
make install PREFIX=~/.local  # installs to ~/.local
```

## Architecture

aimux is a thin CLI dispatcher over battle-tested shell scripts. Each subcommand is a standalone bash script in `lib/aimux/`.

```
aimux
├── bin/aimux              # CLI entry point
├── lib/aimux/             # Subcommand implementations
│   ├── _common.sh         # Shared utilities (colors, git helpers)
│   ├── new.sh             # Workspace creation
│   ├── status.sh          # Status display
│   ├── run.sh             # Autonomous execution
│   ├── kill.sh            # Workspace cleanup
│   ├── doctor.sh          # Health check
│   ├── daemon.sh          # Agent state monitoring
│   ├── notify.sh          # Multi-channel notifications
│   ├── attach.sh          # Session attachment
│   ├── queue.sh           # Queue management
│   └── help.sh            # Help text
├── config/
│   └── aimux.tmux.conf    # tmux config snippet
├── completions/           # Fish, Bash, Zsh completions
└── Formula/
    └── aimux.rb           # Homebrew formula
```

## License

MIT
