---
name: jfdi-sync
description: Sync missed Claude Code sessions to the Obsidian vault using reconcile mode. Walks ~/.claude/projects/ for unsynced sessions and writes them to ~/obsidian/Claude/Sessions/.
---

# JFDI Sync

Catch up any Claude Code sessions that were not yet synthesized to the Obsidian vault.

## Usage

```
/jfdi-sync [--verbose]
```

## What it does

1. Runs `session-synthesize.sh --reconcile` to walk `~/.claude/projects/*/` and find sessions not yet written to `~/obsidian/Claude/Sessions/`
2. Synthesizes each missed session into a markdown file in the vault
3. Reports how many sessions were processed

## Instructions

Run the reconcile synthesis:

```bash
bash ~/dotfiles/scripts/obsidian/session-synthesize.sh --reconcile --verbose 2>&1
```

After the script completes, count the sessions now in the vault:

```bash
ls ~/obsidian/Claude/Sessions/*.md 2>/dev/null | wc -l
```

Report:
- How many sessions were processed/created during this run (parse "Synthesized" lines in output)
- Total session files now in `~/obsidian/Claude/Sessions/`
- Any errors encountered (lines starting with "ERROR" or "Warning" in the output)

If the script does not exist at `~/dotfiles/scripts/obsidian/session-synthesize.sh`, report the error and advise the user to check their dotfiles installation.
