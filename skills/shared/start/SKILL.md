---
name: start
description: Load project context, find the next unblocked task, and begin implementation. Use when starting a work session or when ready for the next task. Reduces verbose prompts to "implement the next task" via structured context loading.
argument-hint: "[BEAD_ID] [--pick] [--dry-run]"
---

# Start Workflow

Load project context, pick the next task, and begin implementation autonomously.

## Arguments

- `$ARGUMENTS` - Optional:
  - `BEAD_ID` — Start a specific bead instead of auto-picking
  - `--pick` — Show candidates and let the user choose (instead of auto-picking)
  - `--dry-run` — Show what would be picked without starting

## Execution

### 1. Load Project Context

Read the project's key context files to understand the current state:

```bash
# Check for living plan (persists session state)
cat .plan.md 2>/dev/null

# Check for session changelog (recent history)
tail -20 .claude/CHANGELOG.md 2>/dev/null
```

Read the root `CLAUDE.md` to refresh project architecture, conventions, and rules.

### 2. Check Current State

```bash
# Check git status for uncommitted work
git status --short

# Check if any beads are already in_progress
bd list --status=in_progress
```

If there are **in_progress beads**: report them. Ask whether to continue that work or pick a new task. If `--pick` was NOT specified, default to continuing the in-progress work.

If there is **uncommitted work**: warn about it. Suggest running `/wrap-up` first.

### 3. Find Next Task

If a specific `BEAD_ID` was provided in `$ARGUMENTS`, use that bead.

Otherwise, find the next unblocked task:

```bash
# Show tasks ready to work (no blockers)
bd ready
```

**Auto-pick logic** (when no BEAD_ID and no `--pick`):
1. From `bd ready` output, prefer tasks by priority (P0 > P1 > P2 > P3 > P4)
2. Within same priority, prefer tasks with parent beads (subtasks) over standalone
3. If multiple candidates at same priority, pick the first one listed

If `--pick` was specified: display the candidates in a numbered list and ask the user to choose.

If `--dry-run` was specified: show the pick result and stop here.

### 4. Load Task Context

For the selected bead:

```bash
# Get full task details
bd show BEAD_ID
```

If the bead has a parent, also load the parent's context:
```bash
bd show PARENT_ID
```

Check for related context files:
- If the bead title or description references specific files, read those files
- If there's a `.plan.md` with relevant sections, note them

### 5. Mark In-Progress and Begin

```bash
# Claim the task
bd update BEAD_ID --status=in_progress
```

Output a ready summary in this format:

```
--- START ---
Task: BEAD_ID - Task Title
Priority: P{n}
Context: {parent bead title if any}
Files: {relevant files mentioned in description, or "TBD after investigation"}
---

Ready. Implementing...
```

Then begin working on the task. Read relevant files, understand the problem, and start implementation.
