---
title: Providers
description: Built-in AI agent providers and the provider plugin system
---

Providers define how aimux launches, detects, and monitors AI agents. Three providers ship built-in; you can add custom ones by dropping a shell script into `~/.aimux/providers/`.

## Built-in providers

### claude

The default provider. Launches Claude Code with `--effort max`.

| Setting | Default |
|---------|---------|
| `command` | `claude` |
| `args` | `["--effort", "max"]` |
| `detect_patterns` | `["claude"]` |
| `working_pattern` | `... \(` |
| `done_patterns` | `["COMPLETE", "_DONE", "TICKET_TASK_COMPLETE"]` |

The Claude provider detects activity by looking for the spinner pattern (`... (`) in terminal output, and completion by looking for `COMPLETE`, `_DONE`, or `TICKET_TASK_COMPLETE` markers.

### codex

OpenAI Codex CLI in full-auto mode.

| Setting | Default |
|---------|---------|
| `command` | `codex` |
| `args` | `["--full-auto"]` |
| `detect_patterns` | `["codex"]` |
| `working_pattern` | (empty) |
| `done_patterns` | `["COMPLETE"]` |

### ollama

Local Ollama models for self-hosted inference.

| Setting | Default |
|---------|---------|
| `command` | `ollama` |
| `args` | `["run"]` |
| `detect_patterns` | `["ollama"]` |
| `working_pattern` | (empty) |
| `done_patterns` | `[">>>"]` |

The Ollama provider detects completion when the `>>>` prompt reappears, indicating the model has finished responding.

## Using a provider

```bash
# Use default provider (from config or "claude")
aimux run PROJ-123 "Fix the bug"

# Specify provider explicitly
aimux run --provider codex PROJ-123 "Fix the bug"
aimux run --provider ollama PROJ-123 "Summarize the code"

# Set default provider in config
# ~/.aimux/config.toml:
# [general]
# default_provider = "codex"
```

## Configuring providers

Override provider settings in `~/.aimux/config.toml`:

```toml
[providers.claude]
command = "claude"
args = ["--effort", "max", "--model", "opus"]

[providers.codex]
command = "codex-rotate"    # use account rotation wrapper
args = ["--full-auto"]
```

Or with environment variables:

```bash
export AIMUX_PROVIDERS_CLAUDE_COMMAND="my-claude-wrapper"
```

## Provider plugin API

Each provider is a bash script that defines three functions. The naming convention is `provider_<name>_<function>`.

### Required functions

#### launch_cmd

```bash
provider_<name>_launch_cmd <worktree> <prompt>
```

Returns the shell command to launch the agent. Called by `aimux run` to build the launch command.

- `worktree` -- full path to the git worktree directory
- `prompt` -- user-provided prompt text (may be empty)

#### detect

```bash
provider_<name>_detect <tty>
```

Returns exit code 0 if the agent process is running on the given TTY. Used by the daemon to discover which panes have active agents.

- `tty` -- the TTY device path (e.g., `/dev/ttys001`)

#### detect_state

```bash
provider_<name>_detect_state <captured_content>
```

Echoes one of: `working`, `idle`, or `done`. Analyzes the terminal content captured from the tmux pane.

- `captured_content` -- the last N lines of terminal output

## Provider configuration in TOML

Providers can read their settings from `config.toml` using the `cfg_get` function:

```toml
[providers.aider]
command = "aider"
args = ["--auto-commits", "--yes"]
detect_patterns = ["aider"]
working_pattern = "Tokens:"
done_patterns = ["Applied edit"]
```

The built-in provider scripts use `cfg_get "providers.<name>.<key>" "<default>"` to read configuration, so custom providers can follow the same pattern.

## Provider search order

1. `~/.aimux/providers/` (user overrides)
2. `lib/aimux/providers/` (built-in)

If the same provider name exists in both locations, the user version takes precedence. This lets you override built-in provider behavior without modifying the aimux installation.

## Listing available providers

The `provider_list` function enumerates all `.sh` files in both provider directories. It is used internally by `aimux doctor` and the shell completions. Providers are deduplicated by name.

## See also

- [Custom Providers Guide](/guides/custom-providers/) -- step-by-step tutorial for creating a custom provider
- [Configuration Reference](/configuration/reference/) -- all config keys including provider settings
