---
description: Run the repo's OpenCode doctor and explain only what matters
agent: plan
---

This command is normally intercepted by the OpenCode ops command plugin and run without a model call.

If you see this text as an assistant response, the plugin did not load. Review the following OpenCode doctor output and summarize only the actionable items.

Review the following OpenCode doctor output and summarize only the actionable items.

Doctor output:

!`./scripts/opencode/doctor.sh 2>&1`

Focus on failures, warnings, and the next concrete steps. If everything is healthy, say that briefly.
