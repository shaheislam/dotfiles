# Provider System

Providers define how aimux launches, detects, and monitors AI agents. Three providers ship built-in; you can add custom ones.

## Built-in Providers

### claude

The default provider. Launches Claude Code with `--effort max`.

| Setting | Default |
|---------|---------|
| command | `claude` |
| args | `["--effort", "max"]` |
| detect_patterns | `["claude"]` |
| working_pattern | `… \(` |
| done_patterns | `["COMPLETE", "_DONE", "TICKET_TASK_COMPLETE"]` |

### codex

OpenAI Codex CLI in full-auto mode.

| Setting | Default |
|---------|---------|
| command | `codex` |
| args | `["--full-auto"]` |
| detect_patterns | `["codex"]` |
| working_pattern | (empty) |
| done_patterns | `["COMPLETE"]` |

### ollama

Local Ollama models for self-hosted inference.

| Setting | Default |
|---------|---------|
| command | `ollama` |
| args | `["run"]` |
| detect_patterns | `["ollama"]` |
| working_pattern | (empty) |
| done_patterns | `[">>>"]` |

## Using a Provider

```bash
# Use default provider (from config or "claude")
aimux run PROJ-123 "Fix the bug"

# Specify provider explicitly
aimux run --provider codex PROJ-123 "Fix the bug"
aimux run --provider ollama PROJ-123 "Summarize the code"
```

## Configuring Providers

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

## Custom Provider API

Create a shell script at `~/.aimux/providers/<name>.sh`. The script must define three functions.

### Required Functions

```bash
# provider_<name>_launch_cmd <worktree> <prompt>
# Returns the shell command to launch the agent.
provider_myagent_launch_cmd() {
    local wt="$1" prompt="$2"
    if [[ -n "$prompt" ]]; then
        echo "myagent --work-dir \"$wt\" \"$prompt\""
    else
        echo "myagent --work-dir \"$wt\""
    fi
}

# provider_<name>_detect <tty>
# Returns 0 if the agent process is running on the given TTY.
provider_myagent_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'myagent'
}

# provider_<name>_detect_state <captured_content>
# Echoes one of: working, idle, done
# based on the terminal content captured from the tmux pane.
provider_myagent_detect_state() {
    local content="$1"
    if echo "$content" | grep -qF "TASK_COMPLETE"; then
        echo "done"
    elif echo "$content" | grep -qE 'processing|thinking'; then
        echo "working"
    else
        echo "idle"
    fi
}
```

### Example: Custom Provider

`~/.aimux/providers/aider.sh`:

```bash
#!/usr/bin/env bash
# aimux provider: aider (AI pair programmer)

provider_aider_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd="aider"
    local args="--auto-commits --yes"
    if [[ -n "$prompt" ]]; then
        echo "$cmd $args --message \"$prompt\""
    else
        echo "$cmd $args"
    fi
}

provider_aider_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'aider'
}

provider_aider_detect_state() {
    local content="$1"
    if echo "$content" | grep -qF "Tokens:"; then
        echo "working"
    elif echo "$content" | grep -qF "aider>"; then
        echo "idle"
    else
        echo "idle"
    fi
}
```

Usage:

```bash
aimux run --provider aider PROJ-456 "Refactor the auth module"
```

### Provider Configuration in TOML

Custom providers can also read their configuration from `config.toml`:

```toml
[providers.aider]
command = "aider"
args = ["--auto-commits", "--yes"]
detect_patterns = ["aider"]
working_pattern = "Tokens:"
done_patterns = ["Applied edit"]
```

The built-in provider scripts use `cfg_get` to read these values, so a custom provider can follow the same pattern.

## Provider Search Order

1. `~/.aimux/providers/` (user overrides)
2. `lib/aimux/providers/` (built-in)

If the same provider name exists in both locations, the user version takes precedence.

## Listing Available Providers

```bash
# The provider_list function enumerates all available providers
# (used internally by aimux doctor and completions)
```
