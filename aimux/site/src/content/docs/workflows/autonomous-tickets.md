---
title: Autonomous Ticket Execution
description: Fire-and-forget ticket execution with monitoring and retry
---

## The problem

Running AI agents interactively means sitting and watching. Context-switching between agents is exhausting. What if you could describe the task and walk away?

## The solution

```bash
aimux run PROJ-123 "Fix the session timeout bug in the OAuth flow. \
  The issue is that tokens expire after 30 minutes but the refresh \
  logic doesn't trigger. See src/auth/oauth.ts."
```

This single command:

1. Creates an isolated git worktree + tmux window
2. Launches Claude Code with your prompt and `--effort max`
3. Starts a witness process that monitors for completion
4. Retries automatically if the agent gets stuck
5. Sends you a desktop notification when done

## How the witness works

The witness is a background process that monitors a single workspace:

```
Witness loop:
  1. Sleep for poll_interval seconds (default: 10)
  2. Capture last 30 lines from tmux pane
  3. Hash the content (MD5)
  4. If hash changed -> reset idle timer
  5. If hash unchanged for stuck_timeout -> mark stuck
  6. If provider detects "done" markers -> complete
  7. If stuck and retries remaining -> Ctrl-C, wait 2s, re-launch
  8. If stuck and no retries remaining -> mark failed
```

## What "stuck" means

The witness tracks whether the terminal output changes. If nothing changes for `stuck_timeout` seconds (default: 300 = 5 minutes), the agent is considered stuck. This covers:

- Agent hung waiting for input that will not come
- Agent in an infinite loop without output
- Network issues causing the agent to freeze
- Agent process crashed but the shell remains

When stuck, the witness:

1. Sends Ctrl-C to interrupt the agent
2. Waits 2 seconds for the process to terminate
3. Re-executes the launch script (`.aimux/launch.sh` in the worktree)
4. Increments the retry counter

After `max_retries` (default: 3), the witness gives up and marks the task as failed.

## Configuring timeouts

In `~/.aimux/config.toml`:

```toml
[general]
stuck_timeout = 600    # 10 minutes before declaring stuck
poll_interval = 15     # Check every 15 seconds
```

Or per-run:

```bash
aimux run PROJ-123 "Fix the bug" --max-retries 5
```

Or via environment variables:

```bash
export AIMUX_STUCK_TIMEOUT=600
export AIMUX_POLL_INTERVAL=15
```

## Checking results

```bash
# See the current state of all workspaces
aimux status

# Read the agent's output log
aimux log PROJ-123

# Follow output in real-time
aimux log PROJ-123 --follow

# Inspect the code changes
cd ~/projects/myapp-proj-123
git diff
git log --oneline
```

## Writing good prompts

The quality of autonomous execution depends heavily on the prompt. Tips:

1. **Be specific**: Include file paths, function names, and error messages
2. **Provide context**: Mention relevant modules, dependencies, and constraints
3. **Set expectations**: State what "done" looks like (tests passing, lint clean, etc.)
4. **Include completion markers**: Tell the agent to print a completion marker when done

```bash
aimux run PROJ-123 "Fix the session timeout bug in src/auth/oauth.ts. \
  The refresh token logic in refreshSession() doesn't trigger when \
  the access token expires after 30 minutes. Root cause is likely \
  the expiry check on line 42. After fixing, run 'npm test' to \
  verify. Print TICKET_TASK_COMPLETE when done."
```

The `TICKET_TASK_COMPLETE` marker is one of the default done patterns for the Claude provider, so the witness will detect completion automatically.

## Overnight execution pattern

Queue multiple tickets and let them run while you sleep:

```bash
# Queue all your tickets
aimux queue add PROJ-100 "Fix login CSS" --priority 10
aimux queue add PROJ-101 "Add validation" --priority 5
aimux queue add PROJ-102 "Write tests" --priority 3

# Start the dispatcher
aimux queue start

# Start the daemon for monitoring
aimux daemon start

# Go to sleep
```

In the morning:

```bash
aimux status        # See what completed
aimux queue status  # See queue progress
```

See the [Batch Execution](/workflows/batch-execution/) workflow for details.
