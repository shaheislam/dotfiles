---
description: Assess whether the current branch is ready to land
agent: dotfiles-review
model: anthropic/claude-opus-4-6
---

Assess whether the current branch is ready to land.

Branch status:

!`git -c core.fsmonitor=false status --short --branch`

Recent commits:

!`git log --oneline --decorate -5`

Available quick test groups:

!`./scripts/test-filter.sh --list 2>/dev/null || true`

Focus on landing risks:

- missing validation
- uncommitted or unpushed work
- auth/config drift
- repo-specific completion requirements

If it is not ready, say exactly what remains.
