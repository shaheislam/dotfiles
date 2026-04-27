---
name: jfdi-synthesis
description: Generate a weekly (or monthly) synthesis report from recent Obsidian session and memory files. Delegates to weekly-synthesis.sh if available; otherwise synthesizes inline and writes to ~/obsidian/Claude/Synthesis/weekly/.
---

# JFDI Synthesis

Generate a synthesis report aggregating key decisions, learnings, patterns, and outcomes from recent sessions and memories.

## Usage

```
/jfdi-synthesis [--period weekly|monthly]
```

- No argument: generate weekly synthesis (default)
- `--period monthly`: generate monthly rollup

## What it does

1. Calls `weekly-synthesis.sh` if it exists (preferred path)
2. Falls back to inline synthesis: reads session and memory files from the last 7 days (or 30 for monthly), aggregates key themes, and writes a report to `~/obsidian/Claude/Synthesis/weekly/`

## Instructions

### Step 1: Check for synthesis script

```bash
if [ -f ~/dotfiles/scripts/obsidian/weekly-synthesis.sh ]; then
  bash ~/dotfiles/scripts/obsidian/weekly-synthesis.sh 2>&1
  echo "SCRIPT_DONE"
fi
```

If `SCRIPT_DONE` is printed, report the output and stop — the script handled everything.

### Step 2: Inline fallback (script not found)

Determine the period:
- Weekly (default): last 7 days, ISO week format `YYYY-Www`
- Monthly (`--period monthly`): last 30 days, format `YYYY-MM`

Gather recent session files:

```bash
# Weekly
find ~/obsidian/Claude/Sessions/ -name "*.md" -mtime -7 -type f 2>/dev/null | sort -r

# Monthly
find ~/obsidian/Claude/Sessions/ -name "*.md" -mtime -30 -type f 2>/dev/null | sort -r
```

Gather recent memory files:

```bash
# Weekly
find ~/obsidian/Claude/Memories/ -name "*.md" -mtime -7 -type f 2>/dev/null | sort -r

# Monthly
find ~/obsidian/Claude/Memories/ -name "*.md" -mtime -30 -type f 2>/dev/null | sort -r
```

Read up to 15 session files and up to 30 memory files. Extract:
- From sessions: first message (task description), work type, files touched
- From memories: type, title, summary, confidence

### Step 3: Synthesize

Produce a structured synthesis covering:

1. **Overview** — session count, memory count, work type distribution
2. **Key Decisions** — decision-type memories from the period
3. **Learnings & Insights** — learning + insight memories
4. **Patterns Detected** — pattern-type memories
5. **Workflow Improvements** — workflow-type memories
6. **Recommendations** — 2-3 actionable suggestions based on the data

### Step 4: Write report

Determine the output filename:

```bash
# Weekly: ISO week
WEEK=$(date +%Y-W%V)
OUTPUT=~/obsidian/Claude/Synthesis/weekly/${WEEK}.md

# Monthly:
MONTH=$(date +%Y-%m)
OUTPUT=~/obsidian/Claude/Synthesis/weekly/${MONTH}-monthly.md
```

Write the file with YAML frontmatter:

```yaml
---
type: synthesis
period: YYYY-Www
generated: YYYY-MM-DD
sessions: N
memories: N
tags:
  - synthesis
  - weekly
---
```

Create the output directory if it does not exist:

```bash
mkdir -p ~/obsidian/Claude/Synthesis/weekly/
```

### Step 5: Report

Tell the user:
- The output file path
- Session and memory counts processed
- Top 3 insights surfaced
