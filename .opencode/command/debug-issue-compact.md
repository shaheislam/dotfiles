---
description: Investigate an integration or workflow issue with compact output
agent: dotfiles-debug-caveman
model: openai/gpt-5.4
---

Investigate compactly:

$ARGUMENTS

Current branch state:

!`git -c core.fsmonitor=false status --short --branch`

Use smallest relevant probes first. Return root cause, evidence, minimum fix, risk, next action.
