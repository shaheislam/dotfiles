---
description: Implement a dotfiles change end-to-end with repo-aware validation
agent: build
model: openai/gpt-5.4
---

Implement the following change in this dotfiles repository end-to-end:

$ARGUMENTS

Follow AGENTS.md and CLAUDE.md strictly.

Prefer:

- fish functions for shell-facing behavior
- `scripts/test-filter.sh` for fast targeted validation
- repo-native workflows over ad hoc replacements

Do not stop at analysis if the task is concrete. Make the change, run relevant validation, and summarize any residual risk.
