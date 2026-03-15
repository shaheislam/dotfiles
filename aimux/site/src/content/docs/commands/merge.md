---
title: aimux merge
description: Merge workspace back to main branch or create a PR
---

## Usage

```bash
aimux merge [options] <workspace>
```

## Description

Completes the workspace lifecycle by merging changes back to the main branch. Auto-commits any uncommitted changes, merges the workspace branch (or creates a pull request), and cleans up the workspace afterward.

This is the command that closes the loop: `aimux new` creates the workspace, you (or an agent) do the work, and `aimux merge` lands it.

## Options

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--pr` | | Create a GitHub PR instead of merging locally | |
| `--squash` | `-s` | Squash all commits into a single merge commit | |
| `--message MSG` | `-m` | Custom merge commit message | auto-generated |
| `--delete` | | Delete the workspace after merging | enabled |
| `--no-delete` | | Keep the workspace after merging | |
| `--dry-run` | `-n` | Show what would happen without making changes | |
| `--help` | `-h` | Show help | |

## Examples

```bash
# Merge a workspace branch back to main
aimux merge feature-auth

# Create a PR instead of merging locally
aimux merge --pr feature-auth

# Squash merge with a custom commit message
aimux merge --squash -m "feat: add session timeout handling" feature-auth

# Preview the merge without executing it
aimux merge --dry-run feature-auth

# Merge but keep the workspace around for follow-up work
aimux merge --no-delete feature-auth

# Squash merge and create a PR
aimux merge --pr --squash proj-124
```

## What happens

1. **Resolves workspace** -- finds the worktree by branch name or path
2. **Checks branch status** -- ensures the workspace branch has commits ahead of the base branch
3. **Auto-commits** any uncommitted changes in the worktree with a generated commit message
4. **Switches to base branch** (`main` or `master`) in the main worktree
5. **Merges** the workspace branch:
   - Standard merge by default (preserves history)
   - Squash merge if `--squash` is specified (single commit)
6. **Creates PR** instead of merging if `--pr` is specified (delegates to `aimux pr`)
7. **Cleans up** the workspace via `aimux kill` (unless `--no-delete` is set)
8. **Updates state file** to mark the workspace as merged

## Dry run

With `--dry-run`, aimux prints every step it would take without executing anything:

```
dry-run: would auto-commit 2 files in /Users/me/projects/myapp-feature-auth
dry-run: would merge feature-auth into main (squash: no)
dry-run: would kill workspace feature-auth
```

## Notes

- The base branch is auto-detected: `main` is preferred, falls back to `master`
- If there are merge conflicts, the merge aborts and you are dropped into the worktree to resolve them manually
- The auto-commit message follows the format `chore: auto-commit before merge (<branch>)`
- When `--pr` is used, the merge step is replaced by `aimux pr` -- the branch is pushed and a PR is created
- Workspace cleanup uses `aimux kill` internally, so all resources (tmux window, state file, logs) are removed
- If the workspace has already been merged, aimux exits with a warning instead of failing
