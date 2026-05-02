---
description: Implement a known dotfiles change with compact receipt output
agent: caveman-build
model: openai/gpt-5.4
---

Implement this already-scoped dotfiles change compactly:

$ARGUMENTS

Follow AGENTS.md and CLAUDE.md strictly. Prefer the smallest correct change. Use `scripts/test-filter.sh` for targeted validation. Stop if requirements are ambiguous. Return changed files, validation, blockers, and risk only.
