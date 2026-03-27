---
name: jfdi-extract
description: Extract memories from Claude Code sessions using AI analysis. Use when processing unextracted sessions, running memory extraction pipelines, or syncing session insights to Obsidian.
---

# JFDI Extract

Extract memories from Claude Code sessions using AI analysis.

## Usage

```
/jfdi-extract [--days N] [--limit N] [--session ID]
```

## What it does

1. Finds unprocessed sessions in the database
2. Sends each session to Claude for memory extraction
3. Saves extracted memories to the database
4. Syncs new memories to Obsidian

## Memory Types Extracted

- **correction**: Mistakes corrected by user (critical priority)
- **decision**: Explicit implementation choices
- **insight**: New understanding or realizations
- **learning**: Technical knowledge gained
- **pattern**: Repeated behaviors detected
- **workflow**: Process improvements

## Options

- `--days N`: Only extract from sessions in last N days
- `--limit N`: Maximum sessions to process
- `--session ID`: Extract from specific session only

## Instructions

Run the following commands:

```bash
cd /mounts/second-brain/jfdi

# Extract memories from unprocessed sessions
npx tsx scripts/extract-memories.ts --verbose --limit 5

# Sync new memories to Obsidian
npx tsx scripts/sync-obsidian.ts --verbose
```

Report:
- Number of sessions processed
- Number of memories extracted by type
- Any notable corrections or insights found
