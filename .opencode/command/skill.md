---
description: Load and apply a central dotfiles skill by name
agent: build
model: openai/gpt-5.5
---

Use the central dotfiles skill named by the first argument.

Skill request:

$ARGUMENTS

Instructions:

- Resolve the skill from `.opencode/skills/<name>/SKILL.md` first.
- If it is missing, inspect `skills/{shared,personal,work}/<name>/SKILL.md`.
- Follow the skill instructions exactly, while still obeying `AGENTS.md` and `CLAUDE.md`.
- If no matching skill exists, report the missing skill and suggest `scripts/sync-skills-harnesses.sh` if the central library contains it.
