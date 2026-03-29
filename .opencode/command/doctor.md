---
description: Run the repo's OpenCode doctor and explain only what matters
agent: plan
model: anthropic/claude-opus-4-6
---

Review the following OpenCode doctor output and summarize only the actionable items.

Doctor output:

!`./scripts/opencode/doctor.sh 2>&1`

Focus on failures, warnings, and the next concrete steps. If everything is healthy, say that briefly.
