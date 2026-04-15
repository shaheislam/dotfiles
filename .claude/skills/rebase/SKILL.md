---
name: rebase
description: Safely rebase the current branch onto its base branch using the repo's existing release and git workflows.
argument-hint: "[BASE_BRANCH]"
---

# Rebase

Compatibility wrapper for setups that expect `/rebase`.

## Safe workflow

1. Inspect `git status` and ensure you understand any local changes.
2. Determine the base branch, usually `main`.
3. Run a non-interactive rebase.
4. Resolve conflicts carefully without discarding unrelated user changes.
5. Re-run `/verify` after the rebase.

If the end goal is to ship the branch cleanly, prefer `/ship` after the rebase is complete.
