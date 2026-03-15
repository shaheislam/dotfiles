---
title: Quick Start
description: Get up and running with aimux in 5 minutes
---

## Your first workspace

A workspace is a git worktree paired with a tmux window. Create one from any git repository:

```bash
cd ~/projects/my-app
aimux new feature-auth
```

This creates:
- A git worktree at `../my-app-feature-auth/`
- A tmux window named `feature-auth`
- A state file at `~/.aimux/state/my-app-feature-auth.json`
- Log capture via `tmux pipe-pane` to `~/.aimux/logs/`

## Launch an agent

Switch to the workspace and start Claude Code interactively:

```bash
aimux attach feature-auth
claude
```

Or do it all in one command with autonomous monitoring:

```bash
aimux run AUTH-001 "Implement OAuth2 login flow"
```

This creates the workspace, launches Claude Code with your prompt, and starts a witness process that monitors for completion.

## Check status

```bash
aimux status
```

```
WORKTREE                                 BRANCH                    CONTAINER    AGENT      PROVIDER
──────────────────────────────────────── ───────────────────────── ──────────── ────────── ──────────
*/Users/me/projects/my-app               main                      -            -          -
 /Users/me/projects/my-app-auth-001      auth-001                  -            working    claude
```

The `*` marker indicates your current worktree. Agent states are color-coded:
- **Red** = working (agent is generating output)
- **Yellow** = waiting (agent is idle)
- **Green** = done (task completed)
- **Magenta** = stuck (no output change for 5+ minutes)

## Start the monitoring daemon

The daemon polls tmux panes and color-codes your windows:

```bash
aimux daemon start
```

You will get a desktop notification when an agent completes or gets stuck.

## View agent output

```bash
# Show recent output from a workspace
aimux log auth-001

# Follow output in real-time
aimux log auth-001 --follow
```

## Clean up

When you are done with a workspace:

```bash
aimux kill feature-auth
```

This removes the worktree, tmux window, state file, log file, and the local branch. Use `--force` to kill workspaces with uncommitted changes.

## Next steps

- Queue multiple tickets with [`aimux queue`](/commands/queue/)
- Run agents from different providers with [`aimux run --provider`](/commands/run/)
- Learn about the [Core Concepts](/getting-started/concepts/) behind aimux
