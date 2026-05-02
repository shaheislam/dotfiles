---
paths:
  - ".claude/skills/ticket-execute/**"
  - ".claude/skills/todo/**"
  - "scripts/ticket-queue/**"
  - ".config/fish/functions/gwt-queue*"
---

# Agentic Ticket Execution System

Autonomously execute tickets from Linear/Jira using OpenCode-first worktrees, tmux, and nvim.

| Command | Description |
|---------|-------------|
| `/todo <desc>` | Create ticket in Linear/Jira (auto-detected) |
| `/ticket-execute [KEY]` | Execute ticket autonomously |
| `gwt-ticket` | Core function: worktree + tmux + OpenCode + nvim (`--claude` fallback) |
| `ticket-execute` / `tex` | High-level orchestrator |

**Detection**: `.claude/settings.local.json` → `.linear.toml` → git remote patterns → default Linear.

## Ticket Queue
Rate-limit-aware multi-sub scheduling. Daemon auto-dispatches to lowest-utilization subscription profile.

**Commands**: `gwt-queue add|list|remove|start|stop|status|usage|profiles|next|log`
**Multi-Sub**: `--sub NAME` pins to profile; without it, auto-dispatches to lowest 5-hour utilization.
**Files**: Queue data at `~/.claude/ticket-queue.json`, scripts at `scripts/ticket-queue/`.
