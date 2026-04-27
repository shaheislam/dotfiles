---
name: autoplan
description: Combined review pipeline -- runs product, architecture, and security reviews in sequence, producing a Review Readiness Dashboard
argument-hint: "[--quick] [--skip PHASE] [--save PATH]"
---

# Autoplan

Run a multi-dimensional review pipeline on the current work. Sequences product, architecture, and security perspectives to produce a unified Review Readiness Dashboard. Inspired by gstack's /autoplan skill.

## Arguments

- `$ARGUMENTS` - Optional:
  - `--quick` — Run abbreviated versions of each review phase
  - `--skip PHASE` — Skip a specific phase: `product`, `architecture`, `security`
  - `--save PATH` — Write the dashboard to a file

## Execution

### 1. Detect scope

Determine what to review:

```bash
# If on a feature branch, review the diff against base
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
BRANCH=$(git branch --show-current)

if [ "$BRANCH" != "$BASE" ]; then
  # Feature branch: review diff
  git diff --stat $BASE..HEAD
  git log --oneline $BASE..HEAD
else
  # On base branch: review recent changes
  git log --oneline -20
fi
```

Also check for:
- `.plan.md` — if present, read the plan for context
- Open beads — check `bd list --status=in_progress` for active work context
- PR description — if a PR exists for this branch

### 2. Phase 1: Product Review

**Persona:** Product-minded founder/CEO

Evaluate the changes from a product perspective:

| Dimension | Question |
|-----------|----------|
| **User Value** | Does this change deliver clear value to the end user? |
| **Completeness** | Is the feature complete or does it leave rough edges? |
| **Edge Cases** | Are error states, empty states, and edge cases handled? |
| **UX** | Is the user experience intuitive and consistent? |
| **Scope** | Is the scope appropriate or is it over/under-engineered? |

**Output:** PASS / NEEDS ATTENTION / FAIL for each dimension, with specific notes.

### 3. Phase 2: Architecture Review

**Persona:** Staff engineer

Evaluate technical quality:

| Dimension | Question |
|-----------|----------|
| **Patterns** | Does it follow existing codebase patterns and conventions? |
| **Data Flow** | Is the data flow clear, efficient, and correct? |
| **Error Handling** | Are errors handled gracefully with meaningful context? |
| **Dependencies** | Are new dependencies justified and well-chosen? |
| **Testability** | Is the code testable? Are tests adequate? |
| **Performance** | Are there obvious performance concerns? |
| **Maintainability** | Will another developer understand this in 6 months? |

**Output:** PASS / NEEDS ATTENTION / FAIL for each dimension, with specific notes.

### 4. Phase 3: Security Quick Check

**Persona:** Security engineer

Run a focused security check (not a full /security-audit):

| Dimension | Question |
|-----------|----------|
| **Input Validation** | Is user input validated at system boundaries? |
| **Authentication** | Are auth checks present where needed? |
| **Secrets** | Are secrets properly managed (not hardcoded)? |
| **Injection** | Are there injection vectors (SQL, command, XSS)? |
| **Data Exposure** | Could sensitive data leak via logs, errors, or APIs? |

**Output:** PASS / NEEDS ATTENTION / FAIL for each dimension, with specific notes.

### 5. Review Readiness Dashboard

Combine all phases into a unified dashboard:

```markdown
# Review Readiness Dashboard

| Phase | Status | Issues |
|-------|--------|--------|
| Product Review | PASS/WARN/FAIL | N issues |
| Architecture Review | PASS/WARN/FAIL | N issues |
| Security Check | PASS/WARN/FAIL | N issues |

## Overall: READY TO SHIP / NEEDS WORK / BLOCKED

### Product Review
[Dimension-by-dimension results]

### Architecture Review
[Dimension-by-dimension results]

### Security Check
[Dimension-by-dimension results]

## Action Items
1. [Priority-ordered list of things to fix before shipping]

## Subjective Decisions
[Items that require human judgment -- taste, UX choices, trade-offs]
```

### 6. Output

- Display the dashboard
- If `--save PATH`, write it to the file
- If any phase is FAIL: recommend specific actions before proceeding
- If all phases PASS: recommend proceeding to `/ship`

### Quick Mode (--quick)

In quick mode, each phase runs in abbreviated form:
- Product: 3 dimensions instead of 5
- Architecture: 4 dimensions instead of 7
- Security: 3 dimensions instead of 5
- Total review time target: < 2 minutes
