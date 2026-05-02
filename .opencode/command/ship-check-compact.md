---
description: Compact readiness check for landing the current branch
agent: dotfiles-review-caveman
model: anthropic/claude-opus-4-6
---

Assess landing readiness compactly.

Branch status:

!`git -c core.fsmonitor=false status --short --branch`

Recent commits:

!`git log --oneline --decorate -5`

Available quick test groups:

!`./scripts/test-filter.sh --list 2>/dev/null || true`

Return blockers, missing validation, uncommitted/unpushed work, and next action only.
