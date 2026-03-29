---
description: Suggest the best model for a task type using the routing presets
agent: plan
model: anthropic/claude-haiku-4-5
---

Given the following task, recommend which model routing preset to use.

Task: $ARGUMENTS

Available presets from `.opencode/model-routing.json`:

!`cat .opencode/model-routing.json | jq -r '.presets | to_entries[] | "- \(.key): \(.value.model) — \(.value.description)"'`

Recommend the best preset and explain why in one sentence. If the task spans multiple categories, recommend the primary one and mention the secondary.
