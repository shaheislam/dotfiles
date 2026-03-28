---
name: retro
description: Data-driven engineering retrospective analyzing git history, shipping velocity, test health, and team contributions over configurable time windows
argument-hint: "[7d|14d|30d] [--author NAME] [--compare] [--save PATH]"
---

# Engineering Retrospective

Analyze git history to produce a data-driven engineering retrospective. Inspired by gstack's /retro skill.

## Arguments

- `$ARGUMENTS` - Optional:
  - Time window: `7d` (default), `1d`, `14d`, `30d`
  - `--author NAME` — Focus on a specific contributor
  - `--compare` — Compare current window against the prior equivalent period
  - `--save PATH` — Write report to file

## Execution

### 1. Parse arguments

Extract from `$ARGUMENTS`:
- Time window (default: 7d). Convert to git `--since` format.
- `--author` filter (optional)
- `--compare` flag (boolean)
- `--save` path (optional)

Calculate date ranges:
```bash
# Current window
SINCE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)

# Prior window (for --compare)
PRIOR_END=$SINCE
PRIOR_START=$(date -v-14d +%Y-%m-%d 2>/dev/null || date -d "14 days ago" +%Y-%m-%d)
```

### 2. Gather git metrics

Run these to collect raw data:

```bash
# Commit count and authors
git log --since="$SINCE" --format="%H|%an|%ae|%s" --no-merges

# Lines changed per commit
git log --since="$SINCE" --numstat --format="%H" --no-merges

# File churn (most-changed files)
git log --since="$SINCE" --name-only --format="" --no-merges | sort | uniq -c | sort -rn | head -20

# Commit types (conventional commit prefixes)
git log --since="$SINCE" --format="%s" --no-merges | sed 's/:.*//' | sort | uniq -c | sort -rn
```

### 3. Compute metrics

From the raw data, compute:

| Metric | How |
|--------|-----|
| **Total commits** | Count unique SHAs |
| **Lines added** | Sum column 1 of numstat |
| **Lines removed** | Sum column 2 of numstat |
| **Net LOC** | Added - Removed |
| **Files touched** | Count unique file paths |
| **Test commits** | Commits with subject matching `test:` or touching files with `test`/`spec`/`_test` in name |
| **Test ratio** | Test commits / Total commits |
| **Fix ratio** | Commits with `fix:` prefix / Total commits |
| **Avg commit size** | Total LOC changed / Total commits |
| **Top 5 files** | Most frequently changed files |
| **Contributors** | Unique author names |

### 4. Test health analysis

```bash
# Count test files in repo
find . -name "*test*" -o -name "*spec*" -o -name "*_test*" | grep -v node_modules | grep -v .git | wc -l

# Test files added in window
git log --since="$SINCE" --diff-filter=A --name-only --format="" | grep -E "(test|spec|_test)" | wc -l

# Test files modified in window
git log --since="$SINCE" --diff-filter=M --name-only --format="" | grep -E "(test|spec|_test)" | wc -l
```

### 5. Per-author breakdown (if multiple contributors)

For each unique author:
- Commit count and percentage
- Lines added/removed
- Primary areas (top 3 directories)
- Notable contributions (largest commits)

If `--author` is specified, focus the entire report on that person.

### 6. Trend comparison (if --compare)

Run the same metrics for the prior period and produce a delta table:

| Metric | Current | Prior | Delta |
|--------|---------|-------|-------|
| Commits | N | N | +/-N |
| LOC | N | N | +/-N |
| Test ratio | N% | N% | +/-N% |

Flag significant changes (>20% delta) with commentary.

### 7. Generate report

Produce a structured report:

```markdown
# Engineering Retrospective: [DATE_RANGE]

## Summary
[2-3 sentence overview of the period's work]

## Key Metrics
| Metric | Value |
|--------|-------|
| Commits | N |
| Lines added | N |
| Lines removed | N |
| Net LOC | +/-N |
| Files touched | N |
| Test ratio | N% |
| Fix ratio | N% |
| Contributors | N |

## Shipping Velocity
[Commits per day, busiest days, patterns]

## Test Health
- Total test files: N
- Tests added this period: N
- Tests modified: N
- Test ratio trend: [improving/declining/stable]

## Top Contributors
[Per-author breakdown with praise and growth areas]

## Hot Spots
[Most-changed files — indicates complexity or instability]

## Highlights
[Notable commits, large features, significant fixes]

## Growth Opportunities
[Areas where metrics suggest room for improvement]
```

### 8. Output

- Display the report in the conversation
- If `--save PATH` was provided, also write the report to that file
- If `--compare` was used, append the trend comparison section
