---
description: Sync bead state and show current work context
agent: plan
model: anthropic/claude-haiku-4-5
---

Sync and display the current bead work context.

In-progress work:

!`if command -v bd >/dev/null 2>&1; then bd list --status=in_progress 2>/dev/null; else echo "bd not available"; fi`

Ready work (unblocked):

!`if command -v bd >/dev/null 2>&1; then bd ready 2>/dev/null; else echo "bd not available"; fi`

Summarize the active and ready work. If there are blocked items, note what is blocking them.
