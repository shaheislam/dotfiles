---
name: jfdi-synthesis
description: Generate weekly synthesis reports from session and memory data. Use when creating weekly summaries, analyzing work patterns, or generating Obsidian synthesis reports.
---

# JFDI Synthesis

Generate weekly synthesis reports from session and memory data.

## Usage

```
/jfdi-synthesis [--week YYYY-Www] [--weeks N]
```

## What it does

1. Gathers session data for the specified week(s)
2. Analyzes memory distribution and patterns
3. Identifies potential workflow improvements
4. Generates a synthesis report in Obsidian

## Report Contents

- **Overview**: Session count, memory count, token usage
- **Work Distribution**: Breakdown by work type
- **Memory Breakdown**: Memories by type
- **Key Corrections**: Important corrections from the week
- **Patterns**: Detected workflow patterns
- **Recommendations**: Actionable suggestions

## Options

- `--week YYYY-Www`: Generate for specific week (e.g., 2026-W01)
- `--weeks N`: Generate for last N weeks

## Instructions

Run the following commands:

```bash
cd /mounts/second-brain/jfdi

# Generate synthesis for current week
npx tsx scripts/weekly-synthesis.ts --verbose

# Or generate for last 4 weeks
# npx tsx scripts/weekly-synthesis.ts --weeks 4 --verbose
```

Report:
- Summary statistics for the week
- Key patterns or corrections found
- Recommendations for improvement
- Link to the generated Obsidian file
