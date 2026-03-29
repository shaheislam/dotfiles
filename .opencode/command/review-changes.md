---
description: Review current branch changes using the repo's review standard
agent: dotfiles-review
model: anthropic/claude-opus-4-6
---

Review the current changes in this repository.

Current status:

!`git -c core.fsmonitor=false status --short --branch`

Diff summary:

!`git -c core.fsmonitor=false diff --stat`

Use AGENTS.md and CLAUDE.md guidance. Findings first, ordered by severity, with file references and any testing gaps.
