---
description: Review current branch changes with compact findings-only output
agent: dotfiles-review-caveman
model: anthropic/claude-opus-4-6
---

Review current changes compactly.

Current status:

!`git -c core.fsmonitor=false status --short --branch`

Diff summary:

!`git -c core.fsmonitor=false diff --stat`

Use AGENTS.md and CLAUDE.md. Findings only: severity, file:line, issue, fix, test gap, residual risk.
