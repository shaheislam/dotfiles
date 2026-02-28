# JFDI Sync

Sync Claude Code sessions to the JFDI database and Obsidian vault.

## Usage

```
/jfdi-sync [--force] [--verbose]
```

## What it does

1. Syncs all JSONL session files from `~/.claude/projects/` to the SQLite database
2. Syncs unsynced sessions to Obsidian as markdown files
3. Updates the Obsidian index file

## Options

- `--force`: Re-sync all sessions, even if unchanged
- `--verbose`: Show detailed output

## Instructions

Run the following commands:

```bash
cd /mounts/second-brain/jfdi

# Sync sessions to database
npx tsx scripts/sync-sessions.ts --verbose

# Sync to Obsidian
npx tsx scripts/sync-obsidian.ts --verbose
```

Report the sync results including:
- Number of sessions synced
- Number of files created in Obsidian
- Any errors encountered
