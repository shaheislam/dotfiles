---
name: ship
description: Unified release workflow -- pre-flight checks, base branch sync, validation, coverage analysis, commit, push, and PR creation in one command
argument-hint: "[--dry-run] [--no-pr] [--base BRANCH] [--force]"
---

# Ship

Automate the full release workflow from current branch to PR. Chains validation, testing, and PR creation into a single command. Inspired by gstack's /ship skill.

## Arguments

- `$ARGUMENTS` - Optional:
  - `--dry-run` — Run all checks but don't push or create PR
  - `--no-pr` — Push but skip PR creation
  - `--base BRANCH` — Target branch (default: auto-detect main/master)
  - `--force` — Skip the review readiness check

## Execution

### 1. Pre-flight checks

```bash
# Get current branch
CURRENT=$(git branch --show-current)

# Detect base branch
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$BASE" ]; then
  BASE="main"
  git rev-parse --verify origin/main >/dev/null 2>&1 || BASE="master"
fi
```

**Abort if:**
- On the base branch (`$CURRENT` = `$BASE`) — "You're on $BASE. Create a feature branch first."
- Detached HEAD — "You're in detached HEAD state."

**Warn if:**
- Uncommitted changes exist — stage and commit them first
- No commits ahead of base — "Nothing to ship."

### 2. Show change summary

```bash
# Commits ahead of base
git log --oneline $BASE..HEAD

# Diffstat
git diff --stat $BASE..HEAD

# Files changed
git diff --name-only $BASE..HEAD
```

Display this as a "Ship Manifest" to the user.

### 3. Sync with base branch

```bash
git fetch origin $BASE
git merge origin/$BASE --no-edit
```

**If merge conflicts:**
- List conflicted files
- For simple conflicts (< 5 files): attempt auto-resolution
- For complex conflicts: stop and ask the user to resolve

### 4. Validation gate

Run the project's validation suite. Detect what's available:

1. Check for `package.json` scripts: `test`, `lint`, `typecheck`, `build`
2. Check for `Makefile` targets: `test`, `lint`, `check`
3. Check for Fish syntax: `fish --no-execute` on changed `.fish` files
4. Check for Bash syntax: `bash -n` on changed `.sh` files
5. Check for ShellCheck: `shellcheck` on changed `.sh` files
6. Check for stow: `stow --simulate --verbose .` if in dotfiles repo

Run all detected validators. Collect pass/fail for each.

**If any fail and not `--force`:**
- Display failures
- Ask: "Validation failed. Fix issues and re-run /ship, or use --force to override."
- Stop.

### 5. Coverage analysis (if test runner detected)

If a test runner was found in step 4:

```bash
# Identify changed source files (non-test)
git diff --name-only $BASE..HEAD | grep -v -E "(test|spec|_test|__test)"

# For each changed source file, check if a corresponding test exists
# Report coverage gaps
```

Display coverage status:
- Files with tests
- Files WITHOUT tests (coverage gaps)
- Suggest: "Consider adding tests for uncovered files before shipping."

### 6. Push

If not `--dry-run`:

```bash
git push origin $CURRENT
```

If push fails (no upstream):
```bash
git push --set-upstream origin $CURRENT
```

### 7. Create PR

If not `--dry-run` and not `--no-pr`:

Generate a PR description from the commit log and diffstat. Use conventional format:

```markdown
## Summary
[Auto-generated from commit messages]

## Changes
[Diffstat summary]

## Testing
[Validation results from step 4]

## Coverage
[Coverage analysis from step 5, if available]
```

Create the PR using `gh pr create` or the `/create-pr` skill if available.

### 8. Ship report

Display final status:

```
Ship Report
  Branch:     $CURRENT -> $BASE
  Commits:    N
  Files:      N changed
  Validation: PASS/FAIL
  Coverage:   N/M files covered
  Push:       OK / DRY-RUN
  PR:         URL / SKIPPED / DRY-RUN
```
