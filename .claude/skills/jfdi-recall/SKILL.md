---
name: jfdi-recall
description: Query past session memories and insights from the Obsidian vault using ripgrep. Supports optional --type and --days filters. Searches both Memories/ and Sessions/ directories.
---

# JFDI Recall

Search the Obsidian memory vault for relevant past insights, decisions, and learnings.

## Usage

```
/jfdi-recall [query] [--type TYPE] [--days N]
```

- `query`: Search term (required unless using a filter alone)
- `--type TYPE`: Limit to one memory type: `decision`, `learning`, `insight`, `pattern`, `workflow`, `commitment`
- `--days N`: Limit to memories modified in the last N days

## What it does

1. Runs ripgrep against `~/obsidian/Claude/Memories/` (and optionally scoped to a type subdir)
2. Optionally filters by file modification date
3. Reads the top matches, parses frontmatter, and summarizes findings
4. Also checks `~/obsidian/Claude/Sessions/` for relevant session context

## Instructions

Parse `$ARGUMENTS` to extract `query`, `--type`, and `--days` values.

### Step 1: Build the search scope

```bash
# Default: all memories
SEARCH_DIR=~/obsidian/Claude/Memories

# If --type was given, scope to that subdir
# e.g., --type decision -> ~/obsidian/Claude/Memories/decision/
```

### Step 2: Search memories

```bash
QUERY="<extracted query term>"

# Search memories
rg -l "$QUERY" ~/obsidian/Claude/Memories/ --type md 2>/dev/null | head -20
```

If `--type TYPE` is provided, scope the search:

```bash
rg -l "$QUERY" ~/obsidian/Claude/Memories/TYPE/ --type md 2>/dev/null | head -20
```

If `--days N` is provided, filter by modification date after gathering matches:

```bash
find ~/obsidian/Claude/Memories/ -name "*.md" -mtime -N 2>/dev/null | xargs rg -l "$QUERY" 2>/dev/null | head -20
```

### Step 3: Search sessions for context

```bash
rg -l "$QUERY" ~/obsidian/Claude/Sessions/ --type md 2>/dev/null | head -10
```

### Step 4: Read and summarize matches

Read the top 5 memory files from the search results. For each, extract:
- YAML frontmatter: `type`, `confidence`, `formed`, `entities`
- The `## Summary` section body

### Step 5: Present findings

Format the output as:

```
## Recall: "<query>"

### Memories Found (N matches)

**[type] Title** (confidence: X%)
Formed: DATE
Summary: ...

### Relevant Sessions (N matches)
- Session file name — first message snippet
```

If no matches are found, say so clearly and suggest broadening the query or removing type/day filters.
