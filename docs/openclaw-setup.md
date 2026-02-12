# OpenClaw Integration Plan

> Detailed plan for securely setting up OpenClaw in the dotfiles environment and leveraging it as a multi-channel AI assistant layer.

## Table of Contents

1. [What is OpenClaw](#what-is-openclaw)
2. [Architecture Overview](#architecture-overview)
3. [Security Hardening Plan](#security-hardening-plan)
4. [Installation & Setup](#installation--setup)
5. [Integration with Dotfiles](#integration-with-dotfiles)
6. [Fish Shell Functions](#fish-shell-functions)
7. [LaunchAgent Daemon](#launchagent-daemon)
8. [Channel Configuration](#channel-configuration)
9. [Agent Orchestration Integration](#agent-orchestration-integration)
10. [MCP Server Integration](#mcp-server-integration)
11. [Testing Strategy](#testing-strategy)
12. [Operational Runbook](#operational-runbook)
13. [Implementation Phases](#implementation-phases)

---

## What is OpenClaw

OpenClaw is a **self-hosted, single-user AI assistant platform** that provides:

- **Multi-channel unified inbox**: 13+ messaging platforms (WhatsApp, Telegram, Slack, Discord, Signal, Google Chat, iMessage via BlueBubbles, Microsoft Teams, Matrix, WebChat)
- **Local-first Gateway**: WebSocket control plane at `ws://127.0.0.1:18789` orchestrating sessions, channels, tools, and events
- **Pi Agent Runtime**: RPC-mode agent execution with streaming tools
- **Voice capabilities**: Always-on speech recognition + TTS (ElevenLabs/Deepgram)
- **Browser automation**: Dedicated Chromium control via playwright-core
- **Skills platform**: Bundled + workspace skills with ClawHub registry
- **Session isolation**: Per-group sandboxed sessions with Docker containers

**Repository**: https://github.com/openclaw/openclaw
**License**: MIT
**Runtime**: Node.js >= 22.12.0

### Why OpenClaw in This Environment

| Existing Capability | OpenClaw Enhancement |
|---------------------|----------------------|
| `gwt-ticket` autonomous execution | Multi-channel completion notifications (Slack, Discord, Telegram) |
| `ralph-loop` iterations | Real-time progress updates to messaging channels |
| `cross-provider-bridge` review | Forward review results to team channels |
| `merge-queue` completion | Notify stakeholders across platforms simultaneously |
| `phase-gates` human input | Request gate signals via messaging instead of CLI |
| `checkpoints` audit trail | Send checkpoint summaries to documentation channels |
| Claude Code CLI-only interface | Voice-activated queries + mobile messaging access |

---

## Architecture Overview

```
                     ┌─────────────────────────────────────┐
                     │           OpenClaw Gateway           │
                     │      ws://127.0.0.1:18789            │
                     │                                       │
                     │  ┌─────────┐  ┌──────────────────┐  │
                     │  │ Session  │  │  Pi Agent Runtime │  │
                     │  │ Manager  │  │  (RPC mode)       │  │
                     │  └────┬────┘  └────────┬─────────┘  │
                     │       │                 │             │
                     │  ┌────┴─────────────────┴────┐       │
                     │  │     Channel Router          │       │
                     │  └────┬──┬──┬──┬──┬──┬──┬────┘       │
                     └───────┼──┼──┼──┼──┼──┼──┼────────────┘
                             │  │  │  │  │  │  │
              ┌──────────────┘  │  │  │  │  │  └──────────────┐
              ▼                 ▼  │  ▼  │  ▼                  ▼
         ┌─────────┐    ┌──────┐  │ ┌──┐ │ ┌──────┐    ┌─────────┐
         │Telegram │    │Slack │  │ │WA│ │ │Signal│    │ WebChat │
         └─────────┘    └──────┘  │ └──┘ │ └──────┘    └─────────┘
                           ┌──────┘      └──────┐
                           ▼                     ▼
                      ┌─────────┐          ┌─────────┐
                      │ Discord │          │ Matrix  │
                      └─────────┘          └─────────┘

  ┌──────────────────────────────────────────────────────────────┐
  │                   Dotfiles Integration                        │
  │                                                                │
  │  gwt-ticket ──notify──► openclaw message send                  │
  │  ralph-loop ──status──► openclaw message send                  │
  │  merge-queue ─done───► openclaw message send                   │
  │  phase-gates ─signal─► openclaw message receive                │
  │  checkpoints ─summary► openclaw message send                   │
  └──────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Inbound**: Messages from channels → Gateway → Session → Agent Runtime → Response
2. **Outbound**: Scripts → `openclaw message send` CLI → Gateway → Channel Router → Platform
3. **Internal**: Gateway manages session lifecycle, tool execution, memory indexing

### State Directory Structure

```
~/.openclaw/
├── openclaw.json          # Primary configuration
├── .env                   # Secrets (API keys, tokens)
├── credentials/           # Channel-specific credentials
│   ├── telegram/
│   ├── discord/
│   ├── slack/
│   └── whatsapp/
├── workspace/             # Agent workspace root
│   ├── skills/            # Custom workspace skills
│   └── sandbox/           # Docker sandbox workspace
├── memory/                # Agent memory index
├── sessions/              # Session transcripts
└── logs/                  # Gateway logs
```

---

## Security Hardening Plan

### Threat Model

OpenClaw's threat model acknowledges that an AI assistant with shell access is inherently risky. The principle is **"access control before intelligence"**:

1. **Identity first**: Control who can communicate with the bot
2. **Scope next**: Define where the bot can act
3. **Model last**: Assume the model can be manipulated; limit blast radius

### Security Configuration Matrix

| Layer | Setting | Value | Rationale |
|-------|---------|-------|-----------|
| **Network** | `gateway.bind` | `loopback` | Never expose directly to network |
| **Network** | `gateway.port` | `18789` (default) | Standard port, loopback only |
| **Auth** | `gateway.auth.mode` | `token` | Stronger than password |
| **Auth** | `OPENCLAW_GATEWAY_TOKEN` | 64-char random hex | Generated via `openssl rand -hex 32` |
| **Remote** | `gateway.tailscale.mode` | `off` | Disabled by default; opt-in with `openclaw config set gateway.tailscale.mode serve` |
| **Remote** | `gateway.auth.allowTailscale` | `true` | Accept Tailscale identity headers (only relevant when Tailscale enabled) |
| **DM** | `channels.*.dmPolicy` | `pairing` | All channels require pairing approval |
| **Sandbox** | `agents.defaults.sandbox.mode` | `non-main` | Sandbox all non-main sessions |
| **Sandbox** | `agents.defaults.sandbox.scope` | `session` | One container per session |
| **Sandbox** | `agents.defaults.sandbox.workspaceAccess` | `none` | No host workspace access in sandbox |
| **Sandbox** | `agents.defaults.sandbox.docker.network` | `none` | No network in sandbox containers |
| **Tools** | `tools.profile` | `coding` | Restrict to coding-relevant tools |
| **Tools** | `tools.deny` | `[browser, canvas, cron]` | Deny high-risk tools by default (`nodes` NOT denied — needed for bun/Node.js workflows) |
| **Tools** | `tools.elevated.allowFrom` | `[]` (empty) | No elevated execution |
| **Plugins** | `plugins.allow` | explicit allowlist | Only trusted plugins |
| **Logging** | `logging.redactSensitive` | `tools` | Redact sensitive tool output |
| **Filesystem** | `~/.openclaw/` permissions | `700` (dirs), `600` (files) | Strict file permissions |

### Secret Management

```bash
# Secret hierarchy (highest precedence first):
# 1. Process environment variables
# 2. ./.env (project-level)
# 3. ~/.openclaw/.env (user-level)
# 4. openclaw.json env block

# Required secrets in ~/.openclaw/.env:
OPENCLAW_GATEWAY_TOKEN=<generated-64-char-hex>
ANTHROPIC_API_KEY=<from-existing-claude-config>

# Optional channel secrets (enable as needed):
TELEGRAM_BOT_TOKEN=<bot-token>
DISCORD_BOT_TOKEN=<bot-token>
SLACK_BOT_TOKEN=<xoxb-token>
SLACK_APP_TOKEN=<xapp-token>

# Optional enhancement secrets:
ELEVENLABS_API_KEY=<for-voice-tts>
DEEPGRAM_API_KEY=<for-speech-recognition>
BRAVE_API_KEY=<for-web-search>
```

**Security rules for secrets**:
- NEVER commit `~/.openclaw/.env` to git
- NEVER store secrets in `openclaw.json` (use env vars)
- Use 1Password CLI (`op read`) for secret injection where possible
- Add `~/.openclaw/.env` to global gitignore

### Tailscale Remote Access (Opt-In)

Tailscale mode is **disabled by default** (`off`). When enabled, use **Serve** (tailnet-only), never **Funnel** (public internet).

```bash
# Enable Tailscale Serve (tailnet-only access)
openclaw config set gateway.tailscale.mode serve

# NEVER use Funnel (exposes Gateway publicly)
# openclaw config set gateway.tailscale.mode funnel  # DO NOT DO THIS
```

**When enabling Tailscale Serve**:
- Verify tailnet ACLs restrict access to your devices only
- Confirm TLS is active (Tailscale Serve handles TLS automatically)
- Gateway still binds to loopback; Tailscale proxies through its HTTPS endpoint
- `gateway.auth.allowTailscale: true` accepts Tailscale identity headers as auth
- Run `openclaw security audit --deep` after enabling to validate configuration

### Security Audit

```bash
# Run security audit after setup
openclaw security audit --deep

# Auto-fix common issues
openclaw security audit --fix

# Verify permissions
ls -la ~/.openclaw/
# Expected: drwx------  (700)

ls -la ~/.openclaw/.env
# Expected: -rw-------  (600)
```

---

## Installation & Setup

### Prerequisites

| Requirement | Status | Notes |
|-------------|--------|-------|
| Node.js >= 22.12.0 | Already in Brewfile (`node@22`) | Verify: `node --version` |
| Docker (Colima) | Already in Brewfile | For sandbox mode |
| Tailscale | Already in Brewfile | For remote access |
| Homebrew | Already installed | Package manager |

### Phase Placement in setup.sh

OpenClaw installation is wired in **Phase 4 (Cloud Tools)** of `scripts/setup.sh` alongside other agent tools. It uses `bun add -g` (per repo policy — `use_bun.py` hook enforces bun over npm).

```bash
# Phase 4: Cloud Tools & AI Integration (already wired in scripts/setup.sh)
# Simplified reference of the install logic:
install_openclaw() {
    log_info "Installing OpenClaw..."

    # Install via bun (global) — npm is blocked by use_bun.py hook
    bun add -g openclaw

    # Create state directory with secure permissions
    mkdir -p ~/.openclaw
    chmod 700 ~/.openclaw

    # Generate gateway token if not exists
    if [[ ! -f ~/.openclaw/.env ]]; then
        local token=$(openssl rand -hex 32)
        cat > ~/.openclaw/.env << EOF
# OpenClaw Gateway Authentication
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
OPENCLAW_GATEWAY_TOKEN=${token}

# Model Provider (uses existing Anthropic key)
# ANTHROPIC_API_KEY is inherited from shell environment

# Channel tokens (uncomment and configure as needed)
# TELEGRAM_BOT_TOKEN=
# DISCORD_BOT_TOKEN=
# SLACK_BOT_TOKEN=
# SLACK_APP_TOKEN=
EOF
        chmod 600 ~/.openclaw/.env
        log_info "Generated gateway token in ~/.openclaw/.env"
    fi

    # Copy base configuration
    if [[ ! -f ~/.openclaw/openclaw.json ]]; then
        cp "$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json" ~/.openclaw/openclaw.json
        chmod 600 ~/.openclaw/openclaw.json
    fi

    # Install launchd service (macOS)
    if [[ "$DETECTED_OS" == "macos" ]]; then
        openclaw gateway install 2>/dev/null || true
    fi

    # Run doctor to validate
    openclaw doctor 2>/dev/null || log_warn "OpenClaw doctor found issues - run 'openclaw doctor' manually"

    mark_step_complete "openclaw"
}
```

### Base Configuration

File: `scripts/openclaw/openclaw-base.json`

```json
{
  "$schema": "https://raw.githubusercontent.com/openclaw/openclaw/main/schema/openclaw.schema.json",

  "gateway": {
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token"
    },
    "tailscale": {
      "mode": "serve",
      "resetOnExit": true
    }
  },

  "agents": {
    "defaults": {
      "model": {
        "provider": "anthropic",
        "name": "claude-sonnet-4-5-20250929"
      },
      "workspace": "~/.openclaw/workspace",
      "sandbox": {
        "mode": "non-main",
        "scope": "session",
        "workspaceAccess": "none",
        "docker": {
          "network": "none"
        }
      }
    }
  },

  "tools": {
    "profile": "coding",
    "deny": ["browser", "canvas", "nodes", "cron"],
    "elevated": {
      "allowFrom": []
    }
  },

  "channels": {
    "telegram": {
      "dmPolicy": "pairing"
    },
    "discord": {
      "dmPolicy": "pairing"
    },
    "slack": {
      "dmPolicy": "pairing"
    },
    "whatsapp": {
      "dmPolicy": "pairing"
    },
    "signal": {
      "dmPolicy": "pairing"
    }
  },

  "sessions": {
    "ttl": 3600000,
    "pruning": {
      "enabled": true,
      "interval": 60000
    }
  },

  "logging": {
    "redactSensitive": "tools"
  },

  "plugins": {
    "allow": []
  }
}
```

---

## Integration with Dotfiles

### File Layout

```
~/dotfiles/
├── .config/
│   └── fish/
│       └── functions/
│           ├── openclaw.fish            # Main wrapper (alias: claw)
│           ├── openclaw-notify.fish     # Send notifications to channels
│           └── openclaw-doctor.fish     # Health check wrapper
├── scripts/
│   └── openclaw/
│       ├── openclaw-base.json          # Base configuration template
│       ├── notify.sh                   # Notification helper for bash scripts
│       └── test-openclaw.sh            # Test suite
├── docs/
│   └── openclaw-setup.md              # This document
└── homebrew/
    └── Brewfile                        # node@22 already present
```

### Stow Considerations

- `scripts/openclaw/` is excluded from stow (per `.stow-local-ignore`)
- Fish functions in `.config/fish/functions/` are stowed automatically
- `~/.openclaw/` is NOT in the dotfiles repo (runtime state, contains secrets)
- Base config template lives in `scripts/openclaw/` and is copied during setup

### Brewfile Addition

```ruby
# AI Assistant Platform
# OpenClaw is installed via bun (global: `bun add -g openclaw`), NOT Homebrew.
# No Brewfile entry needed — no Homebrew formula exists.
# All runtime dependencies are already in Brewfile:
# - bun (for global package installation, per repo policy)
# - node@22 (required runtime: >= 22.12.0)
# - colima + docker (for sandbox mode)
# - tailscale (for remote access, if enabled)
# The `openclaw` binary is installed to bun's global bin directory,
# which is already on PATH via bun configuration in config.fish.
# No additional PATH entries needed for Fish or Zsh.
# Installation is wired in scripts/setup.sh Phase 4.
```

---

## Fish Shell Functions

### `openclaw.fish` - Main Wrapper

```fish
function openclaw --description "OpenClaw AI assistant management"
    # Subcommands: start, stop, status, doctor, send, config, audit, logs
    set -l subcmd $argv[1]

    switch $subcmd
        case start
            openclaw gateway start
            echo "OpenClaw Gateway started"

        case stop
            openclaw gateway stop
            echo "OpenClaw Gateway stopped"

        case restart
            openclaw gateway restart
            echo "OpenClaw Gateway restarted"

        case status
            openclaw gateway status

        case doctor
            command openclaw doctor

        case send
            # openclaw send <channel> <message>
            if test (count $argv) -lt 3
                echo "Usage: claw send <channel> <message>"
                return 1
            end
            set -l channel $argv[2]
            set -l message (string join " " $argv[3..])
            command openclaw message send --channel $channel --message "$message"

        case audit
            command openclaw security audit --deep

        case logs
            command openclaw logs --follow

        case config
            if test (count $argv) -lt 3
                command openclaw config list
            else
                command openclaw config set $argv[2..]
            end

        case pair
            # Approve DM pairing
            if test (count $argv) -lt 3
                echo "Usage: claw pair <channel> <code>"
                return 1
            end
            command openclaw pairing approve $argv[2] $argv[3]

        case agent
            # Direct agent query
            set -l message (string join " " $argv[2..])
            command openclaw agent --message "$message" --thinking high

        case help -h --help
            echo "OpenClaw - Self-hosted AI Assistant"
            echo ""
            echo "Usage: claw <command> [args]"
            echo ""
            echo "Commands:"
            echo "  start          Start the Gateway daemon"
            echo "  stop           Stop the Gateway daemon"
            echo "  restart        Restart the Gateway daemon"
            echo "  status         Show Gateway status"
            echo "  doctor         Run health checks"
            echo "  send <ch> <m>  Send message to channel"
            echo "  audit          Run security audit"
            echo "  logs           Follow Gateway logs"
            echo "  config [k] [v] Get/set configuration"
            echo "  pair <ch> <c>  Approve DM pairing"
            echo "  agent <msg>    Direct agent query"
            echo "  help           Show this help"

        case '*'
            # Pass through to openclaw CLI
            command openclaw $argv
    end
end

# Abbreviation
abbr -a claw openclaw
```

### `openclaw-notify.fish` - Notification Helper

```fish
function openclaw-notify --description "Send notifications via OpenClaw channels"
    # Usage: openclaw-notify [--channel <ch>] [--urgency low|normal|high] <message>
    set -l channel "default"
    set -l urgency "normal"
    set -l message ""

    # Parse arguments
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --channel -c
                set i (math $i + 1)
                set channel $argv[$i]
            case --urgency -u
                set i (math $i + 1)
                set urgency $argv[$i]
            case '*'
                set message "$message $argv[$i]"
        end
        set i (math $i + 1)
    end

    set message (string trim "$message")

    if test -z "$message"
        echo "Usage: openclaw-notify [--channel <ch>] [--urgency low|normal|high] <message>"
        return 1
    end

    # Check if Gateway is running
    if not command openclaw gateway status >/dev/null 2>&1
        # Fallback to local notification if Gateway is down
        if command -q terminal-notifier
            terminal-notifier -title "OpenClaw" -message "$message"
        end
        return 0
    end

    # Format based on urgency
    switch $urgency
        case high
            set message "[URGENT] $message"
        case low
            set message "[info] $message"
    end

    # Send via OpenClaw
    command openclaw message send --channel "$channel" --message "$message" 2>/dev/null
end
```

---

## LaunchAgent Daemon

OpenClaw uses its own `launchd` integration via `openclaw gateway install`, which creates:
`~/Library/LaunchAgents/bot.molt.gateway.plist`

This is managed by the `openclaw` CLI directly, NOT by our dotfiles stow. The setup script simply calls `openclaw gateway install` during Phase 4.

### Service Management

```bash
# Status
openclaw gateway status

# Start/Stop/Restart
openclaw gateway start
openclaw gateway stop
openclaw gateway restart

# Manual launchctl (if needed)
launchctl kickstart -k gui/$(id -u)/bot.molt.gateway
launchctl bootout gui/$(id -u)/bot.molt.gateway

# Logs
openclaw logs --follow

# Doctor (validates service config)
openclaw doctor
```

---

## Channel Configuration

### Recommended Channel Priority

| Priority | Channel | Use Case | Setup Effort |
|----------|---------|----------|--------------|
| 1 | **Telegram** | Primary mobile interface, bot API is simple | Low |
| 2 | **Slack** | Team notifications, CI/CD integration | Medium |
| 3 | **Discord** | Community/personal server notifications | Medium |
| 4 | **WebChat** | Browser-based fallback, no third-party deps | None (built-in) |
| 5 | **Signal** | Secure personal messaging | Medium |
| 6 | **WhatsApp** | Already have Clawdbot integration | High (Baileys) |

### Telegram Setup (Recommended First Channel)

```bash
# 1. Create bot via @BotFather on Telegram
# 2. Get bot token
# 3. Add to ~/.openclaw/.env:
echo 'TELEGRAM_BOT_TOKEN=123456:ABCDEF...' >> ~/.openclaw/.env

# 4. Enable in config
openclaw config set channels.telegram.enabled true
openclaw config set channels.telegram.dmPolicy pairing

# 5. Restart gateway
openclaw gateway restart

# 6. Message your bot on Telegram - you'll get a pairing code
# 7. Approve pairing
openclaw pairing approve telegram <code>
```

### Slack Setup (For Team Notifications)

```bash
# 1. Create Slack App at api.slack.com/apps
# 2. Add Bot Token Scopes: chat:write, channels:history, im:history
# 3. Install to workspace
# 4. Add tokens to ~/.openclaw/.env:
echo 'SLACK_BOT_TOKEN=xoxb-...' >> ~/.openclaw/.env
echo 'SLACK_APP_TOKEN=xapp-...' >> ~/.openclaw/.env

# 5. Enable in config
openclaw config set channels.slack.enabled true
openclaw config set channels.slack.dmPolicy pairing

# 6. Restart and pair
openclaw gateway restart
```

---

## Sandbox Profiles for Devcontainer Sessions

The default sandbox config (`workspaceAccess: "none"`, `docker.network: "none"`) is intentionally restrictive for **non-main sessions** (group chats, untrusted channels). The main session is always unrestricted.

For devcontainer-based workflows (via `devcon.fish` / `gwt-dev`), where bun/Node.js need workspace access, override sandbox settings per-agent:

```json
{
  "agents": {
    "list": [
      {
        "name": "devcontainer-agent",
        "sandbox": {
          "mode": "off",
          "workspaceAccess": "rw"
        },
        "tools": {
          "profile": "full"
        }
      }
    ]
  }
}
```

Or relax at runtime for a specific session:

```bash
# Temporarily allow workspace access for devcontainer coding session
openclaw config set agents.defaults.sandbox.workspaceAccess rw

# Restore restrictive defaults after session
openclaw config set agents.defaults.sandbox.workspaceAccess none
```

The key distinction:
- **Main session** (direct DM with bot owner): Full access, no sandbox restrictions
- **Non-main sessions** (group chats, other users): Sandboxed with restrictive defaults
- **Devcontainer agents**: Override via per-agent config when workspace access is needed

---

## Agent Orchestration Integration

### Integration Points with Existing Systems

#### 1. gwt-ticket Completion Notifications

Add to `worktree-witness.sh` (on task completion):

```bash
# After merge queue submission
if command -v openclaw &>/dev/null; then
    openclaw message send --channel default \
        --message "Ticket $TICKET_KEY completed. Branch: $BRANCH. PR: $PR_URL"
fi
```

#### 2. ralph-loop Progress Updates

Add periodic status to `ralph-loop` iteration hook:

```bash
# Every N iterations, send progress update
if (( iteration % 5 == 0 )); then
    openclaw message send --channel default \
        --message "Ralph-loop iteration $iteration/$max_iterations for $TICKET_KEY"
fi
```

#### 3. phase-gates Signal Reception

OpenClaw can receive phase gate signals via messaging:

```bash
# User messages bot: "signal gate ENG-123"
# OpenClaw skill processes → calls: phase-gates.sh signal <worktree>
```

#### 4. merge-queue Status

```bash
# In merge-queue.sh daemon, on merge completion:
if command -v openclaw &>/dev/null; then
    openclaw message send --channel default \
        --message "Merge complete: $BRANCH → main ($(git rev-parse --short HEAD))"
fi
```

#### 5. Cross-Provider Bridge Results

```bash
# In cross-provider-bridge.sh, after review:
if [[ "$CROSS_PROVIDER_BRIDGE_NOTIFY" == "1" ]] && command -v openclaw &>/dev/null; then
    openclaw message send --channel default \
        --message "Cross-provider review: $REVIEW_STATUS for $(git branch --show-current)"
fi
```

### Notification Architecture (Fish + Bash)

**Why two implementations?** The Fish function (`openclaw-notify.fish`) is the primary implementation for interactive use. The Bash helper (`scripts/openclaw/notify.sh`) exists because several agent orchestration scripts are pure Bash (`worktree-witness.sh`, `merge-queue.sh`, `cross-provider-bridge.sh`) and cannot call Fish functions. Both implementations share the same behavior:

- Graceful degradation (skip if openclaw not installed or gateway down)
- Structured failure logging to `~/.openclaw/notify.log`
- Strict mode via `OPENCLAW_NOTIFY_STRICT=1` (fail on notification errors)
- Fallback to `terminal-notifier` when gateway is unavailable (Fish only)

### Notification Helper Script

File: `scripts/openclaw/notify.sh`

```bash
#!/usr/bin/env bash
# OpenClaw notification helper for bash scripts
# Usage: source scripts/openclaw/notify.sh
#        oc_notify "message" [channel] [urgency]

oc_notify() {
    local message="$1"
    local channel="${2:-default}"
    local urgency="${3:-normal}"

    # Skip if openclaw not installed
    if ! command -v openclaw &>/dev/null; then
        return 0
    fi

    # Skip if gateway not running
    if ! openclaw gateway status &>/dev/null; then
        return 0
    fi

    # Format urgency prefix
    case "$urgency" in
        high) message="[URGENT] $message" ;;
        low)  message="[info] $message" ;;
    esac

    openclaw message send --channel "$channel" --message "$message" 2>/dev/null || true
}

oc_notify_ticket() {
    local ticket_key="$1"
    local status="$2"
    local details="${3:-}"

    oc_notify "Ticket $ticket_key: $status${details:+ - $details}"
}
```

---

## MCP Server Integration

OpenClaw does NOT need to be added as an MCP server to Claude Code. Instead, it's integrated at the **script/hook level** — Claude Code's existing hooks call `openclaw message send` for notifications.

However, if a future OpenClaw MCP server becomes available, the integration would follow the existing pattern:

```bash
# In scripts/setup.sh Phase 4:
# claude mcp add openclaw -- openclaw mcp-server

# In claude_desktop_config.json:
# "openclaw": { "command": "openclaw", "args": ["mcp-server"] }
```

For now, the integration is purely CLI-based via hooks and scripts.

---

## Testing Strategy

### Test Suite

File: `scripts/openclaw/test-openclaw.sh` (also wired into `scripts/test-filter.sh`)

```bash
#!/usr/bin/env bash
# OpenClaw integration tests

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"

run_test() {
    local name="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}  PASS${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}  FAIL${NC} $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo -e "${BLUE}=== OpenClaw Integration Tests ===${NC}"

# Installation tests
echo -e "\n${BLUE}--- Installation ---${NC}"
run_test "Node.js >= 22 installed" "node --version 2>/dev/null | grep -qE 'v2[2-9]|v[3-9][0-9]'"
run_test "openclaw CLI installed" "command -v openclaw"
run_test "State directory exists" "[ -d ~/.openclaw ]"
run_test "State directory permissions" "[ $(stat -f '%Lp' ~/.openclaw 2>/dev/null || stat -c '%a' ~/.openclaw 2>/dev/null) = '700' ]"

# Configuration tests
echo -e "\n${BLUE}--- Configuration ---${NC}"
run_test "openclaw.json exists" "[ -f ~/.openclaw/openclaw.json ]"
run_test ".env file exists" "[ -f ~/.openclaw/.env ]"
run_test ".env file permissions" "[ $(stat -f '%Lp' ~/.openclaw/.env 2>/dev/null || stat -c '%a' ~/.openclaw/.env 2>/dev/null) = '600' ]"
run_test "Gateway auth is token mode" "grep -q '\"token\"' ~/.openclaw/openclaw.json"
run_test "Gateway binds to loopback" "grep -q '\"loopback\"' ~/.openclaw/openclaw.json"
run_test "Sandbox mode is non-main" "grep -q '\"non-main\"' ~/.openclaw/openclaw.json"
run_test "DM pairing enabled" "grep -q '\"pairing\"' ~/.openclaw/openclaw.json"
run_test "Browser tool denied" "grep -q 'browser' ~/.openclaw/openclaw.json"
run_test "Elevated allowFrom empty" "python3 -c \"import json; c=json.load(open('$HOME/.openclaw/openclaw.json')); assert c['tools']['elevated']['allowFrom'] == []\""

# Fish function tests
echo -e "\n${BLUE}--- Fish Functions ---${NC}"
run_test "openclaw.fish exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish' ]"
run_test "openclaw-notify.fish exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish' ]"
run_test "openclaw.fish valid syntax" "fish -n '$DOTFILES_ROOT/.config/fish/functions/openclaw.fish'"
run_test "openclaw-notify.fish valid syntax" "fish -n '$DOTFILES_ROOT/.config/fish/functions/openclaw-notify.fish'"

# Script tests
echo -e "\n${BLUE}--- Scripts ---${NC}"
run_test "Base config template exists" "[ -f '$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json' ]"
run_test "Base config valid JSON" "python3 -c \"import json; json.load(open('$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json'))\""
run_test "notify.sh exists" "[ -f '$DOTFILES_ROOT/scripts/openclaw/notify.sh' ]"
run_test "notify.sh valid bash" "bash -n '$DOTFILES_ROOT/scripts/openclaw/notify.sh'"

# Security tests
echo -e "\n${BLUE}--- Security ---${NC}"
run_test ".env not in git" "! git -C '$DOTFILES_ROOT' ls-files --error-unmatch .openclaw/.env 2>/dev/null"
run_test "No secrets in openclaw.json" "! grep -qE '(sk-|xoxb-|xapp-)' ~/.openclaw/openclaw.json 2>/dev/null"
run_test "Gateway token in .env" "grep -q 'OPENCLAW_GATEWAY_TOKEN' ~/.openclaw/.env 2>/dev/null"

# Summary
echo ""
echo -e "${BLUE}Results: ${TESTS_PASSED}/${TESTS_RUN} passed, ${TESTS_FAILED} failed${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
```

### test-filter.sh Integration

Add to `scripts/test-filter.sh`:

```bash
openclaw)
    source "$SCRIPT_DIR/openclaw/test-openclaw.sh"
    ;;
```

---

## Operational Runbook

### Daily Operations

```bash
# Check status
claw status

# View logs
claw logs

# Health check
claw doctor
```

### Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Gateway won't start | `openclaw doctor` | Check Node.js version, port conflicts |
| Messages not delivered | `claw status` | Verify channel tokens in `.env` |
| Pairing not working | Check bot is running | `claw restart` then retry pairing |
| High memory usage | `claw status` | Restart gateway, prune sessions |
| Sandbox failures | Docker running? | `colima start` then `claw restart` |

### Backup & Recovery

```bash
# Backup configuration (exclude credentials)
tar czf openclaw-config-backup.tar.gz \
    ~/.openclaw/openclaw.json \
    ~/.openclaw/workspace/skills/ \
    --exclude='*.env' \
    --exclude='credentials/'

# Restore
tar xzf openclaw-config-backup.tar.gz -C /

# Full reset
openclaw gateway uninstall
rm -rf ~/.openclaw
# Then re-run setup
```

### Updating

```bash
# Update CLI
npm update -g openclaw

# Restart service
claw restart

# Verify
claw doctor
```

---

## Implementation Phases

### Phase 1: Foundation (This PR)
- [x] Create plan document (`docs/openclaw-setup.md`)
- [ ] Create base configuration template (`scripts/openclaw/openclaw-base.json`)
- [ ] Create notification helper (`scripts/openclaw/notify.sh`)
- [ ] Create Fish shell functions (`openclaw.fish`, `openclaw-notify.fish`)
- [ ] Create test suite (`scripts/openclaw/test-openclaw.sh`)
- [ ] Wire into `scripts/test-filter.sh`
- [ ] Add installation function to `scripts/setup.sh` Phase 4
- [ ] Update CLAUDE.md with OpenClaw section

### Phase 2: Channel Setup (Manual, Post-Install)
- [ ] Install OpenClaw: `bun add -g openclaw`
- [ ] Run onboarding: `openclaw onboard --install-daemon`
- [ ] Configure Telegram bot via @BotFather
- [ ] Configure Slack app (if team use)
- [ ] Run security audit: `openclaw security audit --deep --fix`
- [ ] Test DM pairing for each channel
- [ ] Verify sandbox mode with test group message

### Phase 3: Agent Integration (Future PR)
- [ ] Add `oc_notify` calls to `worktree-witness.sh`
- [ ] Add `oc_notify` calls to `merge-queue.sh`
- [ ] Add `oc_notify` calls to `ralph-loop` status hook
- [ ] Create OpenClaw skill for phase-gate signaling
- [ ] Add `--notify` flag to `gwt-ticket`
- [ ] Test end-to-end notification flow

### Phase 4: Voice & Mobile (Future)
- [ ] Configure ElevenLabs/Deepgram for voice
- [ ] Set up macOS companion app
- [ ] Configure iOS/Android nodes
- [ ] Test voice-activated agent queries

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OPENCLAW_GATEWAY_TOKEN` | *(generated)* | Gateway authentication token |
| `OPENCLAW_STATE_DIR` | `~/.openclaw` | State directory |
| `OPENCLAW_CONFIG_PATH` | `~/.openclaw/openclaw.json` | Config file path |
| `OPENCLAW_LOAD_SHELL_ENV` | `1` | Load env from shell profile |
| `OPENCLAW_NOTIFY_CHANNEL` | `default` | Default notification channel |

### Fish config.fish Addition

```fish
# OpenClaw
set -gx OPENCLAW_LOAD_SHELL_ENV 1
set -gx OPENCLAW_NOTIFY_CHANNEL default
```

---

## Security Checklist (Pre-Deploy)

- [ ] Gateway binds to loopback only
- [ ] Token auth enabled with 64-char hex token
- [ ] All channels use DM pairing policy
- [ ] Sandbox mode set to `non-main`
- [ ] Sandbox has no network access
- [ ] Sandbox has no workspace access
- [ ] Browser, canvas, cron tools denied (nodes allowed for bun/Node.js)
- [ ] Elevated execution disabled (empty allowFrom)
- [ ] Plugin allowlist is explicit (not wildcard)
- [ ] Sensitive log redaction enabled
- [ ] State directory permissions are 700
- [ ] .env file permissions are 600
- [ ] No secrets in openclaw.json
- [ ] No secrets committed to git
- [ ] Security audit passes: `openclaw security audit --deep`
- [ ] Tailscale mode is `off` by default (opt-in: `openclaw config set gateway.tailscale.mode serve`)
- [ ] If Tailscale enabled: Serve only (NOT Funnel), verify tailnet ACLs, confirm TLS

---

## References

- **Repository**: https://github.com/openclaw/openclaw
- **Documentation**: https://docs.openclaw.ai
- **Security Guide**: https://docs.openclaw.ai/security
- **Skill Registry**: https://clawhub.dev
- **Threat Model**: https://docs.openclaw.ai/security/threat-model
