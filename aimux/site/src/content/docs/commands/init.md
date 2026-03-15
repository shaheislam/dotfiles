---
title: aimux init
description: Interactive first-run setup
---

## Usage

```bash
aimux init [--force]
```

## Description

Detects your environment and creates a configuration file. Run this once after installation to get optimal defaults for your machine.

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Overwrite existing configuration |
| `--help` | `-h` | Show help |

## What it does

1. **Creates** the `~/.aimux/` directory structure (`state/`, `logs/`, `providers/`, `templates/`)
2. **Detects installed agents** -- scans PATH for `claude`, `codex`, `ollama`, `aider`, and any custom provider binaries
3. **Checks dependencies** -- verifies `tmux`, `git`, `bash`, and optional tools like `fzf`, `jq`, `gh`, `docker`
4. **Detects tmux version** and adjusts configuration for compatibility
5. **Generates `~/.aimux/config.toml`** with detected defaults (default provider, poll intervals, notification channels)
6. **Copies built-in provider plugins** to `~/.aimux/providers/` if not already present
7. **Prints a summary** of what was detected and configured

## Examples

```bash
# First-time setup
aimux init

# Re-run after installing new agents
aimux init --force
```

## Example output

```
aimux init

Creating ~/.aimux/ directory structure...
  created ~/.aimux/state/
  created ~/.aimux/logs/
  created ~/.aimux/providers/
  created ~/.aimux/templates/

Detecting environment...
  [FOUND] tmux 3.4
  [FOUND] git 2.44.0
  [FOUND] bash 5.2.26
  [FOUND] fzf 0.48.1
  [FOUND] jq 1.7.1
  [FOUND] gh 2.47.0
  [FOUND] docker 25.0.3

Detecting AI providers...
  [FOUND] claude — set as default provider
  [FOUND] codex
  [-----] ollama — not installed
  [-----] aider — not installed

Writing ~/.aimux/config.toml...
  default_provider = "claude"
  poll_interval = 10
  stuck_timeout = 300
  max_retries = 3

Setup complete. Run 'aimux doctor' to verify.
```

## Notes

- Running `aimux init` without `--force` when `~/.aimux/config.toml` already exists exits with a message: `Config already exists. Use --force to overwrite.`
- The generated config can be edited manually afterward -- see the [config reference](/configuration/reference/) for all options
- Provider plugins in `~/.aimux/providers/` are not overwritten by `--force` if they have been modified (timestamps are checked)
- Run `aimux doctor` after `aimux init` to verify everything is healthy
