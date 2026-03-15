---
title: aimux run
description: Execute a ticket autonomously with agent retry loop
---

## Usage

```bash
aimux run [options] <ticket> [prompt...]
```

## Description

The central command of aimux. Creates a workspace, launches an AI agent with your prompt, and starts a witness process that monitors the agent to completion -- with automatic retry on failure.

## Options

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--provider NAME` | `-P` | AI provider to use (`claude`, `codex`, `ollama`, or custom) | from config (`claude`) |
| `--max-retries N` | `--max` | Maximum restart attempts when agent gets stuck | `3` |
| `--template FILE` | `-T` | Custom launch template (overrides provider default) | auto-detected |
| `--no-witness` | | Do not start the witness lifecycle monitor | |
| `--no-devcon` | | Skip devcontainer setup | |
| `--mount DIR` | `-m` | Additional directory mount (repeatable) | |
| `--repo DIR` | | Use specified git repo instead of detecting from cwd | current directory |
| `--help` | `-h` | Show help | |

## Examples

```bash
# Basic: run a ticket with Claude Code (default provider)
aimux run PROJ-123 "Fix the authentication timeout bug"

# Use Codex instead
aimux run PROJ-124 "Add rate limiting" --provider codex

# Run without monitoring (just launch the agent)
aimux run PROJ-125 "Update README" --no-witness

# Increase retries for flaky tasks
aimux run PROJ-126 "Migrate database schema" --max-retries 5

# Use a custom launch template
aimux run PROJ-127 "Refactor utils" --template ~/my-template.sh.tmpl
```

## What happens

1. **Converts** ticket key to branch name (e.g., `PROJ-123` becomes `proj-123`)
2. **Creates workspace** via `aimux new` (git worktree + tmux window)
3. **Loads provider** plugin for the specified provider
4. **Builds launch command** from the provider's `launch_cmd` function
5. **Writes launch script** to `<worktree>/.aimux/launch.sh` (if a template and prompt are provided)
6. **Sends command** to the tmux pane via `tmux send-keys`
7. **Writes state file** with ticket metadata, provider, and retry configuration
8. **Starts witness** process (unless `--no-witness` is specified)

## The witness process

The witness runs in the background and monitors the agent:

- Polls the tmux pane every `poll_interval` seconds (default: 10)
- Captures the last 30 lines of terminal output
- Uses the provider's `detect_state` function to determine agent status
- Tracks content changes via MD5 hashing -- if no change for `stuck_timeout` seconds (default: 300), marks as stuck
- **On stuck**: sends Ctrl-C to interrupt, waits 2 seconds, re-executes the launch script, and increments the retry counter
- **On completion**: sends notification via all configured channels, updates state file
- **On max retries exceeded**: marks the task as failed, sends failure notification

## Launch templates

When a template file exists for the provider, aimux generates a launch script with these substitutions:

| Placeholder | Value |
|-------------|-------|
| `{{WORKTREE}}` | Full path to the worktree directory |
| `{{COMMAND}}` | Provider command binary (e.g., `claude`) |
| `{{ARGS}}` | Provider arguments (e.g., `--effort max`) |
| `{{PROMPT}}` | The user-provided prompt text |
| `{{ENV_SETUP}}` | Environment setup commands |

Templates are searched in order:
1. `--template` flag (explicit path)
2. `~/.aimux/templates/launch/<provider>.sh.tmpl` (user override)
3. `<aimux-dir>/templates/launch/<provider>.sh.tmpl` (built-in)

## Combining with queue

For batch execution, use `aimux queue add` instead of `aimux run`:

```bash
aimux queue add PROJ-123 "Fix auth" --provider claude
aimux queue add PROJ-124 "Add tests" --provider codex
aimux queue start  # Dispatcher calls aimux run for each ticket
```

See the [queue command reference](/commands/queue/) for details.
