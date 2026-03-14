# aimux — AI Agent Multiplexer

> Design Document | 2026-03-14

## Problem Statement

Developers running multiple AI coding agents (Claude Code, Codex, Cursor, etc.) in parallel need to:
1. Monitor agent state across sessions (working / idle / done / stuck)
2. Orchestrate isolated environments per task (worktrees + containers)
3. Manage session lifecycle (create, monitor, cleanup)
4. Get notifications when agents need attention
5. Execute tickets autonomously with retry loops and checkpoints

**cmux** (manaflow-ai) solves #4 as a native macOS terminal with notification rings and a sidebar. But it's Ghostty-locked, macOS-only, has no orchestration, no session persistence, and no agent lifecycle management.

**aimux** solves all five — as a terminal-agnostic CLI tool that runs on any terminal, any OS, over SSH.

## Competitive Positioning

| Capability | cmux | aimux | tmux alone |
|---|---|---|---|
| Terminal support | Ghostty only | Any terminal | Any terminal |
| Platform | macOS only | macOS, Linux, WSL | Cross-platform |
| Agent state monitoring | No | 4-state color-coded | No |
| Worktree orchestration | No | Auto-create + cleanup | No |
| Session persistence | No | Detach/attach + restore | Detach/attach |
| Autonomous execution | No | ralph-loop + checkpoints | No |
| Notifications | Native macOS + OSC | Terminal + native + webhook | No |
| Built-in browser | Yes (scriptable) | No (delegates to MCP) | No |
| Multi-provider support | Terminal-agnostic | Claude, Codex, Ollama | N/A |
| Installation | brew cask (GUI app) | brew (CLI tool) | brew |

## Core USPs

1. **Terminal-agnostic**: Works in Ghostty, WezTerm, iTerm2, Alacritty, kitty, even SSH sessions
2. **Agent lifecycle orchestration**: Create → monitor → notify → cleanup, not just display
3. **Autonomous ticket execution**: Give it a ticket, it creates a worktree, runs an agent, retries on failure
4. **Worktree isolation**: Each task gets its own git worktree + optional devcontainer
5. **Cross-platform**: Anywhere tmux runs (macOS, Linux, WSL, remote servers)
6. **Composable**: Unix philosophy — small tools that pipe together

## Architecture

### Phase 1: CLI Tool (MVP)

```
aimux (shell wrapper)
├── aimux new <name>           # Create workspace (worktree + tmux window)
├── aimux status               # Show all workspaces with agent state
├── aimux run <ticket> [prompt] # Autonomous ticket execution
├── aimux attach <name>        # Attach to workspace
├── aimux kill <name>          # Kill workspace + cleanup worktree
├── aimux doctor               # Health check
├── aimux queue                # Ticket queue management
└── aimux notify <msg>         # Send notification (terminal + native)
```

**Implementation**: Thin shell script (`/usr/local/bin/aimux`) that dispatches to underlying Fish/Bash functions. Each subcommand maps to an existing function:

| aimux command | Existing function | Status |
|---|---|---|
| `aimux new` | `gwt-dev` + tmux window | Exists, needs wrapping |
| `aimux status` | `gwt-status` | Exists, needs wrapping |
| `aimux run` | `gwt-ticket` | Exists, needs wrapping |
| `aimux attach` | tmux attach-session | Trivial |
| `aimux kill` | tmux-worktree-cleanup.sh | Exists, needs wrapping |
| `aimux doctor` | `gwt-doctor` | Exists, needs wrapping |
| `aimux queue` | `gwt-queue` | Exists, needs wrapping |
| `aimux notify` | tmux-notify + OSC 9 | Needs creation |

### Phase 2: State Daemon

Background daemon (`aimux daemon`) that:
- Polls tmux panes for agent state (replaces tmux-claude-watcher.sh)
- Emits native OS notifications (macOS Notification Center, Linux notify-send)
- Exposes Unix socket API for programmatic queries
- Persists state to `~/.aimux/state.json`

### Phase 3: TUI Dashboard

Interactive terminal dashboard (`aimux dashboard`) showing:
- All workspaces with real-time agent state
- Log tailing per workspace
- Quick actions (kill, attach, restart)
- Built with a TUI framework (bash dialog or ncurses, later potentially Go Bubble Tea)

## Component Design

### CLI Dispatcher (`bin/aimux`)

```bash
#!/usr/bin/env bash
# aimux - AI Agent Multiplexer
# Terminal-agnostic agent orchestration for tmux

set -euo pipefail
AIMUX_VERSION="0.1.0"
AIMUX_HOME="${AIMUX_HOME:-$HOME/.aimux}"
AIMUX_LIB="${AIMUX_LIB:-$(dirname "$(readlink -f "$0")")/../lib/aimux}"

case "${1:-help}" in
  new)      shift; source "$AIMUX_LIB/new.sh" "$@" ;;
  status)   shift; source "$AIMUX_LIB/status.sh" "$@" ;;
  run)      shift; source "$AIMUX_LIB/run.sh" "$@" ;;
  attach)   shift; source "$AIMUX_LIB/attach.sh" "$@" ;;
  kill)     shift; source "$AIMUX_LIB/kill.sh" "$@" ;;
  doctor)   shift; source "$AIMUX_LIB/doctor.sh" "$@" ;;
  queue)    shift; source "$AIMUX_LIB/queue.sh" "$@" ;;
  notify)   shift; source "$AIMUX_LIB/notify.sh" "$@" ;;
  daemon)   shift; source "$AIMUX_LIB/daemon.sh" "$@" ;;
  version)  echo "aimux $AIMUX_VERSION" ;;
  help|*)   source "$AIMUX_LIB/help.sh" ;;
esac
```

### Workspace Model

Each aimux workspace consists of:
```
~/.aimux/workspaces/<name>/
├── state.json          # Agent state, timestamps, iteration count
├── config.json         # Workspace config (repo, branch, provider)
└── logs/               # Agent output logs (rotated)
```

Backed by:
- A git worktree at `../<repo>-<branch>/`
- A tmux window named `aimux:<name>`
- Optionally a devcontainer instance

### Agent State Machine

```
IDLE ──► WORKING ──► DONE
  ▲         │          │
  │         ▼          │
  └──── WAITING ◄─────┘
           │
           ▼
         STUCK (>5min no output)
```

Detection (polling tmux pane content):
- **WORKING**: Spinner characters detected (`… (`, `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`)
- **WAITING**: Input prompt visible (no spinner, cursor at prompt)
- **DONE**: Completion markers (`COMPLETE`, `_DONE`, exit code 0)
- **STUCK**: No output change for >5 minutes while WORKING

### Notification System

Multi-channel notification, terminal-agnostic:

1. **tmux status bar**: Color-coded window names (exists)
2. **OSC escape sequences**: OSC 9 (iTerm2/WezTerm), OSC 99 (kitty), OSC 777 (rxvt)
3. **Native OS**:
   - macOS: `osascript -e 'display notification'` or `terminal-notifier`
   - Linux: `notify-send`
4. **Webhook**: POST to configurable URL (Slack, Discord, etc.)
5. **Sound**: Terminal bell (`\a`) or custom sound file

### Configuration

```yaml
# ~/.aimux/config.yaml
defaults:
  shell: fish          # or bash, zsh
  provider: claude     # default AI provider
  devcontainer: true   # auto-create devcontainers

notifications:
  native: true         # OS notifications
  sound: true          # terminal bell
  webhook: ""          # optional webhook URL

agent:
  stuck_timeout: 300   # seconds before marking STUCK
  poll_interval: 10    # state check interval
  max_iterations: 20   # default ralph-loop limit

theme:
  working: "red"
  waiting: "yellow"
  done: "green"
  stuck: "magenta"
  idle: "default"
```

## Packaging & Distribution

### Homebrew Formula

```ruby
class Aimux < Formula
  desc "AI Agent Multiplexer - terminal-agnostic agent orchestration"
  homepage "https://github.com/<org>/aimux"
  url "https://github.com/<org>/aimux/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "..."
  license "MIT"

  depends_on "tmux"
  depends_on "fzf"
  depends_on "jq"

  def install
    bin.install "bin/aimux"
    lib.install Dir["lib/aimux/*"]
    # Install tmux config snippet
    (share/"aimux").install "config/aimux.tmux.conf"
    # Install completions
    fish_completion.install "completions/aimux.fish"
    bash_completion.install "completions/aimux.bash"
    zsh_completion.install "completions/_aimux"
  end
end
```

### Installation Flow

```bash
brew install aimux

# First run — interactive setup
aimux doctor
# → Checks: tmux installed, fzf installed, jq installed
# → Creates: ~/.aimux/ directory structure
# → Offers: Add aimux tmux config to .tmux.conf
```

### Repository Structure

```
aimux/
├── bin/
│   └── aimux                 # Main CLI entry point
├── lib/aimux/
│   ├── new.sh                # Workspace creation
│   ├── status.sh             # Status display
│   ├── run.sh                # Autonomous execution
│   ├── attach.sh             # Session attachment
│   ├── kill.sh               # Workspace cleanup
│   ├── doctor.sh             # Health check
│   ├── queue.sh              # Queue management
│   ├── notify.sh             # Notification dispatch
│   ├── daemon.sh             # State monitoring daemon
│   ├── help.sh               # Help text
│   └── _common.sh            # Shared utilities
├── config/
│   └── aimux.tmux.conf       # tmux config snippet (source-file)
├── completions/
│   ├── aimux.fish
│   ├── aimux.bash
│   └── _aimux
├── tests/
│   ├── test_new.sh
│   ├── test_status.sh
│   ├── test_kill.sh
│   └── test_notify.sh
├── docs/
│   ├── README.md
│   ├── getting-started.md
│   ├── configuration.md
│   └── vs-cmux.md
├── Formula/
│   └── aimux.rb
├── LICENSE
└── README.md
```

## Migration Path from Dotfiles

The existing dotfiles functions remain untouched. aimux wraps them:

1. **Extract**: Copy relevant scripts from `scripts/tmux/` and functions from `.config/fish/functions/` into aimux repo
2. **Generalize**: Remove dotfiles-specific assumptions (paths, Fish-only syntax)
3. **Shell-agnostic**: Core logic in POSIX sh/bash, with Fish/Zsh completion wrappers
4. **Config-driven**: Move hardcoded values to `~/.aimux/config.yaml`
5. **Backward-compatible**: aimux commands can coexist with existing Fish functions

## Open Source Strategy

### Naming & Branding
- **Name**: `aimux` (AI + tmux)
- **Tagline**: "The agent multiplexer for your terminal"
- **Positioning**: Not a terminal replacement — an agent orchestration layer

### Adoption Strategy
1. **README with GIF demos** showing side-by-side: manual agent management vs aimux
2. **"5-minute quickstart"** that gets users from `brew install` to running their first agent
3. **Comparison page** (vs-cmux.md) highlighting terminal-agnostic + orchestration advantages
4. **Plugin system** for custom agent providers (not just Claude/Codex)
5. **Community templates** for common workflows (PR review, ticket execution, multi-repo)

### License
MIT — maximizes adoption, allows commercial use, minimal friction.

## Success Criteria

### MVP (Phase 1)
- [ ] `brew install aimux` works
- [ ] `aimux new`, `aimux status`, `aimux kill` work with any terminal
- [ ] `aimux run` executes a ticket autonomously
- [ ] Agent state monitoring with color-coded tmux status
- [ ] Works on macOS and Linux
- [ ] Shell completions for Fish, Bash, Zsh
- [ ] README with quickstart guide

### Phase 2
- [ ] Background daemon with native OS notifications
- [ ] Unix socket API for programmatic access
- [ ] Webhook notifications (Slack, Discord)
- [ ] `aimux dashboard` TUI

### Phase 3
- [ ] Plugin system for custom providers
- [ ] Community workflow templates
- [ ] CI/CD integration (GitHub Actions support)
- [ ] Metrics/analytics dashboard
