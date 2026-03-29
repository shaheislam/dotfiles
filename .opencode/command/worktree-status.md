---
description: Show current worktree and agent orchestration status
agent: plan
model: anthropic/claude-haiku-4-5
---

Show the current worktree and agent status for this repository.

Git worktree state:

!`git worktree list 2>/dev/null || echo "Not in a git worktree"`

Current branch:

!`git -c core.fsmonitor=false branch --show-current 2>/dev/null || echo "detached HEAD"`

Active tmux sessions with agent context:

!`tmux list-sessions -F '#{session_name} #{session_activity}' 2>/dev/null || echo "No tmux sessions"`

Bead status:

!`if command -v bd >/dev/null 2>&1; then bd list --status=in_progress 2>/dev/null; else echo "bd not available"; fi`

Summarize the active work context briefly. Note any stale or stuck agents.
