---
name: wrap-up
description: Validate, test, commit, and close the current task. Use when finishing a piece of work to ensure quality gates are met before committing. Runs available validation (lint, typecheck, tests), generates a conventional commit, and updates bead status.
argument-hint: "[BEAD_ID] [--no-commit] [--no-close] [--amend]"
---

# Wrap-Up Workflow

Validate current work, run tests, commit changes, and update task status.

## Arguments

- `$ARGUMENTS` - Optional:
  - `BEAD_ID` — Close a specific bead (auto-detects from in_progress if omitted)
  - `--no-commit` — Skip the git commit step
  - `--no-close` — Skip closing the bead (leave in_progress)
  - `--amend` — Amend the previous commit instead of creating a new one

## Execution

### 1. Detect Current Work

```bash
# Find what's in progress
bd list --status=in_progress

# Check what files changed
git status --short
git diff --stat
```

If a specific `BEAD_ID` was provided, use that. Otherwise, use the in_progress bead.
If multiple beads are in_progress, list them and use the most recent one.

If NO beads are in_progress and no BEAD_ID given, still proceed with validation and commit (just skip bead closure).

### 2. Run Validation

Run whatever validation tools are available for this project. Check in order and run all that apply:

```bash
# Check for common validation commands
# Fish shell syntax check (for .fish files)
fish --no-execute <changed .fish files> 2>&1

# Shell syntax check (for .sh files)
bash -n <changed .sh files> 2>&1

# If package.json exists with scripts
cat package.json 2>/dev/null | grep -E '"(lint|typecheck|check)"'

# If pyproject.toml exists
cat pyproject.toml 2>/dev/null | grep -E '(ruff|mypy|pytest)'
```

**For this dotfiles repo specifically:**
- Check Fish function syntax: `fish --no-execute` on any changed `.fish` files
- Check shell script syntax: `bash -n` on any changed `.sh` files
- Verify stow would succeed: `stow --simulate --verbose . 2>&1` (if config files changed)

Report results. If validation fails, suggest running `/fix` to diagnose and repair, then re-run `/wrap-up`.

### 3. Run Tests

```bash
# Check for test files related to changes
# For shell scripts, look for corresponding test scripts
ls scripts/tests/ 2>/dev/null
ls tests/ 2>/dev/null

# Run relevant tests if they exist
```

If no test framework is detected, note "No automated tests found" and continue.

### 4. Codex Adversarial Review (if available)

If the codex plugin is installed (`ls ~/.claude/plugins/marketplaces/openai-codex/ 2>/dev/null`), run a pre-commit adversarial review:

```bash
# Only run if there are staged or unstaged changes to review
git diff --shortstat --cached; git diff --shortstat
```

If there are changes and `--no-commit` was NOT specified:
- Invoke `/codex:adversarial-review --wait --scope working-tree`
- Review the output for BLOCK/ALLOW verdict
- If BLOCK: report the issues and stop — do NOT commit. Suggest the user fix the issues and re-run `/wrap-up`
- If ALLOW or review unavailable (Codex not installed/authenticated): continue to commit

This step is skipped silently if:
- Codex CLI is not installed
- No changes exist to review
- `--no-commit` was specified

### 5. Generate Commit

If `--no-commit` was NOT specified:

```bash
# Stage all changes
git add -A

# Review what's being committed
git diff --cached --stat
```

Generate a conventional commit message following project rules:
- Format: `type: brief description`
- NO emojis
- NO AI assistant references
- Focus on what changed and why

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `test`

If `--amend` was specified, amend the previous commit. Otherwise create a new commit.

```bash
git commit -m "type: description"
```

### 6. Update Task Status

If `--no-close` was NOT specified and a bead was identified:

```bash
# Close the bead
bd close BEAD_ID

# Check if parent bead has remaining subtasks
bd show PARENT_ID 2>/dev/null
```

### 7. Synthesise Session to Obsidian

Capture the wrap-up boundary as a tagged synthesis note (bypasses the 60s dedup gate so this always fires alongside the natural Stop hook):

```bash
obsidian-session-sync --reason wrap-up --force 2>&1 | tail -3
```

Non-fatal: if synthesis fails (Obsidian unavailable, no substantive context, etc.) continue with the summary step.

### 8. Report Summary

Output a wrap-up summary:

```
--- WRAP-UP ---
Validation: {PASS/FAIL with details}
Tests: {PASS/FAIL/NONE}
Codex Review: {ALLOW/BLOCK/SKIPPED}
Commit: {commit hash} — {commit message}
Bead: {BEAD_ID} closed
Synthesis: {Obsidian note path or SKIPPED reason}
Remaining: {count of open subtasks under parent, if any}
---
```

If there are remaining tasks under the same parent, suggest: "Run `/start` to pick up the next task."
