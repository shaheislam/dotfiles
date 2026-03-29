---
description: Run bead onboarding and extract the actionable repo context
agent: plan
model: anthropic/claude-opus-4-6
---

Run bead onboarding context and summarize only the actionable information for this repository.

Onboarding output:

!`if command -v bd >/dev/null 2>&1; then bd onboard; else echo "bd command not found"; fi`

Explain the important conventions, current priorities, and next actions. Call out anything that conflicts with AGENTS.md or the current gwtt/OpenCode workflow.
