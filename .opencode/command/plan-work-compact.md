---
description: Produce a compact execution checklist for already-scoped work
agent: caveman-checklist
model: anthropic/claude-haiku-4-5
---

Create a compact execution checklist for this already-scoped work:

$ARGUMENTS

Current branch state:

!`git -c core.fsmonitor=false status --short --branch`

Account for AGENTS.md, CLAUDE.md, and targeted validation. If the work needs open-ended planning, ask one short clarifying question instead of compressing away uncertainty.
