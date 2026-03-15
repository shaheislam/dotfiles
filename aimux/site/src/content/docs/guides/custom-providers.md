---
title: Custom Providers
description: Step-by-step guide to creating a custom AI agent provider
---

## Overview

aimux's provider system is designed for extensibility. Any CLI-based AI agent can be integrated by creating a bash script with three functions. This guide walks through creating a provider for [Aider](https://aider.chat), an AI pair programmer.

## Step 1: Create the provider file

Create `~/.aimux/providers/aider.sh`:

```bash
#!/usr/bin/env bash
# aimux provider: aider (AI pair programmer)
```

User-defined providers in `~/.aimux/providers/` take precedence over built-in providers with the same name.

## Step 2: Implement launch_cmd

This function returns the shell command to start the agent. It receives the worktree path and an optional prompt.

```bash
provider_aider_launch_cmd() {
    local wt="$1" prompt="$2"

    # Read command and args from config (with defaults)
    local cmd
    cmd="$(cfg_get "providers.aider.command" "aider")"
    local args_raw
    args_raw="$(cfg_get "providers.aider.args" '["--auto-commits", "--yes"]')"
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
    [[ -z "$args" ]] && args="--auto-commits --yes"

    if [[ -n "$prompt" ]]; then
        echo "$cmd $args --message \"$prompt\""
    else
        echo "$cmd $args"
    fi
}
```

Key points:
- Use `cfg_get` to read provider configuration from `config.toml`
- Provide sensible defaults so the provider works without explicit configuration
- When a prompt is provided, pass it to the agent

## Step 3: Implement detect

This function checks whether the agent process is running on a given TTY. The daemon calls this for every tmux pane to discover active agents.

```bash
provider_aider_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'aider'
}
```

Key points:
- Return exit code 0 if the agent is detected, non-zero otherwise
- Use `ps -t` to list processes on the TTY
- The pattern should match the process name, not the full command line

## Step 4: Implement detect_state

This function analyzes terminal output to determine the agent's current state. It should echo one of: `working`, `idle`, or `done`.

```bash
provider_aider_detect_state() {
    local content="$1"

    # Check done patterns first (highest priority)
    local done_raw
    done_raw="$(cfg_get "providers.aider.done_patterns" '["Applied edit"]')"
    local pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        if echo "$content" | grep -qF "$pattern" 2>/dev/null; then
            echo "done"
            return 0
        fi
    done < <(echo "$done_raw" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    # Check working pattern
    local working
    working="$(cfg_get "providers.aider.working_pattern" "Tokens:")"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    # Default to idle
    echo "idle"
}
```

Key points:
- Check `done` first -- it takes priority over `working`
- Done detection typically uses fixed string matching (`grep -qF`)
- Working detection can use regex (`grep -qE`) for patterns like spinners
- Default to `idle` when no pattern matches
- Read patterns from config so users can customize without editing the script

## Step 5: Complete provider file

Here is the complete `~/.aimux/providers/aider.sh`:

```bash
#!/usr/bin/env bash
# aimux provider: aider (AI pair programmer)

provider_aider_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.aider.command" "aider")"
    local args_raw
    args_raw="$(cfg_get "providers.aider.args" '["--auto-commits", "--yes"]')"
    local args
    args="$(echo "$args_raw" | tr -d '[]"' | tr ',' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
    [[ -z "$args" ]] && args="--auto-commits --yes"

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

    local done_raw
    done_raw="$(cfg_get "providers.aider.done_patterns" '["Applied edit"]')"
    local pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        if echo "$content" | grep -qF "$pattern" 2>/dev/null; then
            echo "done"
            return 0
        fi
    done < <(echo "$done_raw" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

    local working
    working="$(cfg_get "providers.aider.working_pattern" "Tokens:")"
    if [[ -n "$working" ]] && echo "$content" | grep -qE "$working" 2>/dev/null; then
        echo "working"
        return 0
    fi

    echo "idle"
}
```

## Step 6: Add TOML configuration (optional)

Add provider-specific settings to `~/.aimux/config.toml`:

```toml
[providers.aider]
command = "aider"
args = ["--auto-commits", "--yes", "--model", "claude-3-5-sonnet"]
detect_patterns = ["aider"]
working_pattern = "Tokens:"
done_patterns = ["Applied edit", "aider>"]
```

## Step 7: Test the provider

```bash
# Verify aimux detects the new provider
aimux doctor

# Should show:
#   [PASS] provider: aider (aider)

# Run a ticket with the new provider
aimux run PROJ-123 "Refactor the auth module" --provider aider
```

## Additional examples

### Cursor CLI provider

```bash
#!/usr/bin/env bash
# aimux provider: cursor

provider_cursor_launch_cmd() {
    local wt="$1" prompt="$2"
    if [[ -n "$prompt" ]]; then
        echo "cursor --folder \"$wt\" --execute \"$prompt\""
    else
        echo "cursor --folder \"$wt\""
    fi
}

provider_cursor_detect() {
    local tty="$1"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE 'cursor'
}

provider_cursor_detect_state() {
    local content="$1"
    if echo "$content" | grep -qF "Task complete"; then
        echo "done"
    elif echo "$content" | grep -qE 'Generating|Applying'; then
        echo "working"
    else
        echo "idle"
    fi
}
```

### Generic wrapper provider

For agents that do not have specific state indicators:

```bash
#!/usr/bin/env bash
# aimux provider: generic

provider_generic_launch_cmd() {
    local wt="$1" prompt="$2"
    local cmd
    cmd="$(cfg_get "providers.generic.command" "my-agent")"
    echo "cd \"$wt\" && $cmd \"$prompt\""
}

provider_generic_detect() {
    local tty="$1"
    local cmd
    cmd="$(cfg_get "providers.generic.command" "my-agent")"
    ps -t "$tty" -o comm= 2>/dev/null | grep -qE "$cmd"
}

provider_generic_detect_state() {
    # Without specific patterns, always return idle
    # Stuck detection (content hash) will handle completion
    echo "idle"
}
```

## Tips

- **Test detect_state locally**: Capture some terminal output from your agent and test your patterns with `grep`
- **Done patterns should be specific**: Avoid patterns that match intermediate output
- **Working patterns can be broad**: A spinner, token counter, or progress indicator all work
- **The stuck detector is your safety net**: Even without perfect state detection, the content hash-based stuck detection will catch agents that stop producing output
