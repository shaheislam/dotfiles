---
title: Installation
description: How to install aimux on macOS and Linux
---

## Requirements

| Dependency | Required | Purpose |
|-----------|----------|---------|
| tmux | Yes | Terminal multiplexing substrate |
| git | Yes | Worktree management |
| bash 4+ | Yes | CLI runtime |
| fzf | Recommended | Interactive workspace picker for `aimux attach` |
| jq | Recommended | JSON parsing for state and queue operations |
| docker | Optional | Devcontainer support via `devcon` |

## Install via Homebrew

```bash
brew tap shaheislam/aimux
brew install aimux
```

## Install from source

```bash
git clone https://github.com/shaheislam/aimux.git
cd aimux
make install
```

By default, this installs to `/usr/local`. To change the prefix:

```bash
make install PREFIX=$HOME/.local
```

## Install the Go daemon (optional)

The Go daemon provides enhanced monitoring with proper signal handling, PID file locking, and concurrent queue dispatch:

```bash
cd aimux
make build    # Builds the aimuxd binary
make install  # Installs everything including aimuxd
```

The bash-based daemon (`aimux daemon start`) works without the Go binary -- `aimuxd` is an optional upgrade.

## Verify installation

```bash
aimux doctor
```

This checks all dependencies, tmux status, daemon processes, git worktrees, configuration, state health, and available providers.

Example output:

```
aimux doctor

Dependencies
  [PASS] tmux
  [PASS] git
  [PASS] bash
  [PASS] fzf
  [PASS] jq
  [WARN] docker — not installed (optional)

tmux Status
  [PASS] tmux server running (3 sessions)

Agent Watcher
  [PASS] aimux daemon

Git Worktrees
  [PASS] git repo detected (4 worktrees)

Configuration
  [PASS] ~/.aimux directory
  [PASS] config.toml
  [WARN] aimuxd (Go daemon) — not found (optional, bash daemon used as fallback)

State Health
  [PASS] state files (2 tracked)

AI Providers
  [PASS] provider: claude (claude)
  [PASS] provider: codex (codex)
  [WARN] provider: ollama (ollama) — command not found

Summary: 13 checks, 3 warnings, 0 failures
```

## Shell completions

Completions are installed automatically for Fish, Bash, and Zsh when using `make install`. If they are not working, copy them manually:

**Fish:**
```bash
cp completions/aimux.fish ~/.config/fish/completions/
```

**Bash:**
```bash
cp completions/aimux.bash /etc/bash_completion.d/
```

**Zsh:**
```bash
cp completions/_aimux /usr/local/share/zsh/site-functions/
```

## Create initial configuration (optional)

aimux works with sensible defaults. To customize behavior, copy the default config:

```bash
mkdir -p ~/.aimux
cp config/default.toml ~/.aimux/config.toml
```

Or if installed via Homebrew:

```bash
cp "$(brew --prefix)/share/aimux/default.toml" ~/.aimux/config.toml
```

See the [Configuration Reference](/configuration/reference/) for all available settings.
