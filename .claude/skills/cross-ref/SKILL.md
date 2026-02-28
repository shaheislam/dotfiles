---
name: cross-ref
description: Cross-reference another worktree to detect changes that may affect current feature
argument-hint: <path-to-worktree>
---

# Cross-Reference Worktree Analysis

Analyze changes in another git worktree to determine if they could affect the feature
being developed in the current working directory.

## Arguments
- `$ARGUMENTS` - Path to the other worktree to analyze (required)

## Execution

1. **Validate the other worktree path**
   - Verify $ARGUMENTS is a valid directory
   - Confirm it contains a git repository (check for .git)
   - Get the branch name of the other worktree

2. **Find the common ancestor**
   - Run: `git merge-base HEAD <other-worktree-branch>`
   - This identifies where the two branches diverged

3. **Get changes in the other worktree**
   - From the other worktree directory, run:
     `git diff --name-status <merge-base>..HEAD`
   - This shows all files modified in that branch since divergence

4. **Get changes in current worktree**
   - In current directory, run:
     `git diff --name-status <merge-base>..HEAD`
   - Also check staged/unstaged changes: `git status --porcelain`

5. **Analyze potential impact**
   - Read the changed files from BOTH worktrees
   - Identify dependencies:
     - Files in current worktree that import/use files changed in other worktree
     - Shared files modified in both worktrees (merge conflict candidates)
     - API/interface changes that current code depends on

6. **Generate impact report**
   Provide a structured report with:
   - **Conflict Risk**: Files modified in both branches
   - **Dependency Impact**: Changes in other branch that your code uses
   - **Safe Changes**: Changes that don't appear to affect your work
   - **Recommendations**: What to review, test, or coordinate

## Example Usage
```
/cross-ref ~/projects/myapp-feature-b
/cross-ref ../worktree-auth-refactor
```
