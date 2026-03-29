---
description: Create a repo-aware implementation plan before making changes
agent: plan
model: anthropic/claude-opus-4-6
---

Plan the following work in this repository without making changes:

$ARGUMENTS

Current branch state:

!`git -c core.fsmonitor=false status --short --branch`

Account for AGENTS.md, CLAUDE.md, worktree/tmux workflows, and relevant validation commands. Produce a concise implementation plan with verification steps.
