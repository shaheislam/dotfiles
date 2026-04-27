---
name: continue-claude-work
description: Recover actionable context from interrupted Claude Code sessions using local session artifacts. Use instead of `claude --resume` for targeted context recovery without replaying full transcripts. Triggers on "continue work", "what was I working on", "recover session", "pick up where I left off", or when given a session ID.
argument-hint: "[session-id] [--list] [--search <query>]"
allowed-tools: Bash, Read, Glob, Grep
---

# Continue Claude Work

Recover actionable context from a prior session and continue in the current conversation.

## Why This Exists

`claude --resume` replays the full transcript into the context window. For long sessions this wastes tokens on resolved issues and stale state. This skill runs `scripts/extract_context.py` to selectively extract only actionable context: session end status, compact summary, pending work, errors, and tool/file stats.

## Arguments

- `$ARGUMENTS` - Options:
  - `<session-id>` - Resume a specific session
  - `--list` - Show recent sessions for this project
  - `--search <query>` - Find sessions by keyword

## Step 1: Locate Session Directory

```bash
PROJECT_DIR=$(pwd)
NORMALIZED=$(echo "$PROJECT_DIR" | sed 's|/|-|g; s|^-||')
SESSION_DIR="$HOME/.claude/projects/$NORMALIZED"
ls "$SESSION_DIR"/*.jsonl 2>/dev/null | wc -l
```

If no sessions found, also try the `-Users-` prefix variant that Claude Code sometimes uses.

## Step 2: Run Extraction Script

For `--list`:
```bash
for f in $(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -10); do
  stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" | tr '\n' ' '
  du -sh "$f" | cut -f1 | tr '\n' ' '
  basename "$f" .jsonl
done
```

For `--search`:
```bash
grep -rl "$QUERY" "$SESSION_DIR"/*.jsonl 2>/dev/null | while read f; do
  basename "$f" .jsonl
done
```

For context extraction (specific session or most recent):
```bash
SESSION_FILE="$SESSION_DIR/$SESSION_ID.jsonl"

# Guard: skip if this is the active session
if [ $(($(date +%s) - $(stat -f '%m' "$SESSION_FILE"))) -lt 60 ]; then
  echo "WARNING: Active session. Skipping."
else
  python3 "$(dirname "$0")/../scripts/extract_context.py" "$SESSION_FILE"
fi
```

The script outputs structured sections: SESSION_STATUS, COMPACT_SUMMARY, RECENT_MESSAGES, ERRORS, TOP_TOOLS, FILES_TOUCHED.

## Step 3: Act on Session Status

The script classifies how the session ended. Branch strategy accordingly:

| Status | Meaning | Strategy |
|--------|---------|----------|
| **COMPLETED** | Session ended normally | Check if follow-up work was mentioned in final messages |
| **INTERRUPTED** | User was mid-conversation | Resume from their last message - this is the primary use case |
| **ERROR_CASCADE** | 3+ consecutive tool errors | Read the errors section first. Do NOT retry the same approach blindly |
| **ABANDONED** | Session stopped without conclusion | Check recent messages for intent, then check workspace state |

## Step 4: Check Current Workspace State

```bash
git status --short
git log --oneline -5
cat .plan.md 2>/dev/null | head -40
bd list --status=in_progress 2>/dev/null
```

Cross-reference workspace state against the extracted context:
- If git branch changed since the session, note it
- If referenced files were modified by another session, note conflicts
- If .plan.md exists, it may be more current than the session transcript

## Step 5: Reconcile and Continue

Before making changes:
1. Verify current directory matches the session's project
2. Check that files mentioned in the session still exist and match expectations
3. Do NOT assume prior claims are valid without checking

Then:
- For INTERRUPTED: implement the next concrete step from the last user request
- For ERROR_CASCADE: diagnose the root cause before retrying
- For ABANDONED: present a summary and ask user what to prioritize
- For COMPLETED: check for mentioned follow-up work

Always run deterministic verification (tests, type-checks, build) after changes.

## Step 6: Report

```
=== CONTEXT RECOVERED ===
Session: [session-id]
Last active: [date]
Status: [COMPLETED|INTERRUPTED|ERROR_CASCADE|ABANDONED]
Summary: [key findings from compact summary]
Top files: [most-touched files from session]

=== STRATEGY ===
[Based on status, what we're doing and why]

=== REMAINING ===
[Pending tasks, if any]
```

## Guardrails

- Do NOT run `claude --resume` or `claude --continue` - this skill provides context recovery within the current session
- Do NOT treat compact summaries as complete truth - they are lossy. Verify against current workspace
- Do NOT overwrite unrelated working-tree changes
- Do NOT load full session JSONL files into context - always use the extraction script
- Session files are local only - cannot recover from other machines
- For ERROR_CASCADE sessions: read errors before acting. The same approach will likely fail again
