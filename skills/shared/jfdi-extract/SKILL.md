---
name: jfdi-extract
description: Extract memories from Claude Code sessions using AI analysis. Batch mode processes up to 10 unextracted sessions; single-session mode targets a specific session by ID.
---

# JFDI Extract

Extract memories from Claude Code session transcripts and write them to the Obsidian vault under `~/obsidian/Claude/Memories/`.

## Usage

```
/jfdi-extract [SESSION_ID]
```

- No argument: batch mode — processes up to 10 unextracted sessions
- With SESSION_ID: single-session mode — processes only that session

## Memory Types Extracted

- **decision**: Explicit implementation choices
- **insight**: New understanding or realizations
- **learning**: Technical knowledge gained
- **pattern**: Repeated behaviors detected
- **workflow**: Process improvements
- **commitment**: Commitments made during a session

## Instructions

### Batch Mode (default — no argument)

Check if the batch distillation script exists and run it:

```bash
if [ -f ~/dotfiles/scripts/obsidian/session-distill-batch.sh ]; then
  bash ~/dotfiles/scripts/obsidian/session-distill-batch.sh --limit 10 --priority 2>&1
else
  echo "session-distill-batch.sh not found — falling back to manual guidance"
fi
```

If the batch script does not exist, instruct the user:

> The batch extraction script (`session-distill-batch.sh`) is not yet installed.
> To extract memories from a specific session, run:
>
> ```bash
> echo '{"session_id": "SESSION_ID_HERE", "hook_type": "SessionEnd", "cwd": "."}' \
>   | python3 ~/.claude/hooks/jfdi/session-end-extract.py
> ```
>
> Find available session IDs with:
> ```bash
> ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -10
> ```
> The session ID is the filename without `.jsonl`.

### Single Session Mode (SESSION_ID provided)

```bash
SESSION_ID="$ARGUMENTS"
echo "{\"session_id\": \"${SESSION_ID}\", \"hook_type\": \"SessionEnd\", \"cwd\": \".\"}" \
  | python3 ~/.claude/hooks/jfdi/session-end-extract.py
```

### Reporting

After extraction, report:
- Number of sessions processed
- Number of memories extracted, broken down by type
- Any notable corrections, decisions, or insights found
- Path to memories directory: `~/obsidian/Claude/Memories/`

Check results:

```bash
ls -lt ~/obsidian/Claude/Memories/**/*.md 2>/dev/null | head -20
```
