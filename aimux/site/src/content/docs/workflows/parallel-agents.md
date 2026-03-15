---
title: Parallel Agents
description: Run multiple AI agents simultaneously on different tasks
---

## Overview

Each aimux workspace is a fully isolated git worktree with its own branch, tmux window, and state tracking. This means multiple agents can work on different tasks at the same time with zero conflicts.

## Launch three agents in parallel

```bash
# Terminal 1: Fix an auth bug with Claude
aimux run AUTH-001 "Fix session timeout in OAuth flow"

# Terminal 2: Add a new feature with Codex
aimux run FEAT-002 "Add rate limiting to API endpoints" --provider codex

# Terminal 3: Write tests with Claude
aimux run TEST-003 "Write integration tests for payment module"
```

Each command creates an isolated workspace and launches its agent independently.

## Monitor all of them

```bash
# Table view of all workspaces
aimux status

# Start daemon for live tmux window coloring
aimux daemon start

# Watch a specific agent's output
aimux log AUTH-001 --follow

# Watch all agents' output
aimux log --all --follow
```

## The result

Each agent works in complete isolation:

```
~/projects/myapp-auth-001/    Claude fixing auth (red window)
~/projects/myapp-feat-002/    Codex adding rate limiting (red window)
~/projects/myapp-test-003/    Claude writing tests (yellow window -> green when done)
```

When they complete, you get desktop notifications and can review each workspace independently.

## Mixing providers

Different tasks may suit different agents. Use `--provider` to pick the right tool:

```bash
# Complex architecture work -> Claude
aimux run ARCH-001 "Redesign the caching layer" --provider claude

# Boilerplate/scaffolding -> Codex
aimux run SCAF-002 "Generate CRUD endpoints for users, posts, comments" --provider codex

# Quick local experiments -> Ollama
aimux run EXP-003 "Summarize the codebase structure" --provider ollama
```

## Review and merge

Once agents complete, review their work:

```bash
# Switch to a completed workspace
aimux attach auth-001

# Review changes
git diff
git log --oneline

# If satisfied, push the branch
git push origin auth-001

# Clean up
aimux kill auth-001
```

## Scaling considerations

- **tmux windows**: Each workspace uses one tmux window. tmux handles hundreds of windows without issue.
- **System resources**: Each agent process uses its own CPU and memory. Monitor system load when running many agents.
- **API rate limits**: When using hosted providers (Claude, Codex), be aware of API rate limits. The queue system with cooldowns helps manage this.
- **Disk space**: Each git worktree is a full copy of the working tree (not the git objects). Large repos may use significant disk space with many concurrent worktrees.

## Tips

- Use `aimux status --json | jq '.[] | select(.status == "done")'` to find completed workspaces programmatically
- The daemon provides real-time visual feedback through tmux window colors, so you can see agent states at a glance
- Consider using the [queue system](/workflows/batch-execution/) for more than 3-4 concurrent agents to manage rate limits
