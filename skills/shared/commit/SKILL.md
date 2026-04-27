---
name: commit
description: Stage changes and create a clean commit using the repo's existing wrap-up workflow.
argument-hint: "[BEAD_ID] [--no-close]"
---

# Commit

Compatibility wrapper for setups that expect `/commit`.

In this repo, prefer the existing `/wrap-up` workflow because it already handles validation, tests, commit generation, and bead closure.

## What to do

1. Review the current worktree and staged changes.
2. Run the same validation you would normally run before finishing work.
3. Use `/wrap-up $ARGUMENTS` as the primary path.
4. If the user clearly wants commit-only behavior, skip bead closure with `--no-close`.

## Mapping

- `/commit` -> `/wrap-up`
- Commit-only fallback -> `/wrap-up --no-close`
