---
name: session-review
description: End-of-session retrospective analyzing value contributions and generating usage guidance
argument-hint: "[--save PATH] [--since COMMIT] [--quiet]"
---

# Session Review

Analyze what was accomplished in the current session, highlight value contributions, and generate
actionable usage guidance for everything that was built.

## Arguments

- `$ARGUMENTS` - Optional flags:
  - `--save PATH` — Write the full review to a markdown file at PATH
  - `--since COMMIT` — Explicit session start point (commit SHA or ref)
  - `--quiet` — Skip interactive discussion, output summary only

## Execution

### 1. Parse arguments

Extract flags from `$ARGUMENTS`:
- Look for `--save <path>` and capture the path
- Look for `--since <ref>` and capture the commit reference
- Look for `--quiet` flag (boolean)
- Any unrecognized arguments should be ignored with a note

### 2. Detect session boundary

Use a cascading strategy to find the start of the current session's work:

1. If `--since` was provided, use that commit/ref directly
2. If on a feature branch (not `main`/`master`), run:
   ```
   git merge-base HEAD main
   ```
   (try `master` if `main` doesn't exist)
3. Fall back to commits within the last 4 hours:
   ```
   git log --since="4 hours ago" --format="%H" | tail -1
   ```
4. Final fallback: use the 10th most recent commit:
   ```
   git log -10 --format="%H" | tail -1
   ```

Store the resulting ref as `SESSION_START`.

### 3. Gather git data

Run these commands to understand all session changes:

```bash
# Commit log with stats
git log --oneline --stat SESSION_START..HEAD

# Summary diffstat
git diff --stat SESSION_START..HEAD

# Full diff for analysis (read with care for large diffs)
git diff SESSION_START..HEAD
```

Also check for uncommitted work:
```bash
git status --porcelain
git diff --stat  # unstaged
git diff --cached --stat  # staged
```

### 4. Analyze value contributions

Categorize every change into one of these buckets:

- **New Capabilities** — Features, commands, integrations, skills, functions that didn't exist before
- **Quality Improvements** — Bug fixes, refactors, test additions, error handling improvements
- **Documentation & Knowledge** — Docs, comments, CLAUDE.md updates, memory files
- **Infrastructure & Tooling** — CI/CD, build config, hooks, setup scripts, dependency changes

For each item, note:
- What changed (files, scope)
- Why it matters (user impact)
- Rough effort level (trivial / moderate / significant)

### 5. Present findings

Display a structured summary:

```
## Session Summary

**Duration**: [time range or commit range]
**Commits**: N | **Files changed**: N | **Lines**: +N / -N

### Value Contributions (ranked by impact)

#### New Capabilities
- [capability]: [1-sentence description] ([files])

#### Quality Improvements
- [improvement]: [1-sentence description] ([files])

#### Documentation & Knowledge
- [doc]: [1-sentence description] ([files])

#### Infrastructure & Tooling
- [change]: [1-sentence description] ([files])

### Key Decisions
- [decision]: [rationale]
```

Unless `--quiet` is set, use `AskUserQuestion` to ask:
> "What would you like to explore further?"
> Options: "Deep dive into a specific change", "Generate usage examples", "Identify follow-up work", "Done - looks good"

If the user picks an option, address it before continuing to step 6.

### 6. Generate usage cheat-sheet

For each **New Capability** identified in step 4, produce a mini reference:

```
## Usage Cheat-Sheet

### [Capability Name]
**What**: [1-sentence description]
**How**: [command, flag, or workflow to use it]
**Example**:
  [concrete example invocation or usage pattern]
```

Skip this section if no new capabilities were added (only quality/docs/infra work).

### 7. Optional save

If `--save PATH` was provided:
- Combine the session summary (step 5) and usage cheat-sheet (step 6) into a single markdown document
- Add a header with date and session range
- Write to the specified path using the Write tool
- Confirm the file was written

## Example Usage

```
/session-review
/session-review --quiet
/session-review --since abc1234
/session-review --save /tmp/session-2026-03-01.md
/session-review --since HEAD~5 --save ~/notes/review.md --quiet
```
