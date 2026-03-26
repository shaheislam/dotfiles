---
name: continue-claude-work
description: Recover actionable context from interrupted Claude Code sessions using local session artifacts. Use instead of `claude --resume` for targeted context recovery without replaying full transcripts. Triggers on "continue work", "what was I working on", "recover session", "pick up where I left off", or when given a session ID.
argument-hint: "[session-id] [--list] [--search <query>]"
allowed-tools: Bash, Read, Glob, Grep
---

# Continue Claude Work

Recover actionable context from a prior Claude Code session and continue in the current conversation.

## Why This Exists

`claude --resume` replays the full session transcript into the context window. For long sessions this wastes tokens on resolved issues and stale state. This skill selectively reconstructs only actionable context: the latest compact summary, pending work, known errors, and current workspace state.

## Arguments

- `$ARGUMENTS` - Options:
  - `<session-id>` - Resume a specific session
  - `--list` - Show recent sessions for this project
  - `--search <query>` - Find sessions by keyword

## Step 1: Locate Sessions

Find the project's session directory:

```bash
# Get the normalized project path used by Claude Code
PROJECT_DIR=$(pwd)
NORMALIZED=$(echo "$PROJECT_DIR" | sed 's|/|-|g; s|^-||')
SESSION_DIR="$HOME/.claude/projects/$NORMALIZED"

# Verify it exists
ls -la "$SESSION_DIR"/*.jsonl 2>/dev/null | tail -10
```

If `--list`:
```bash
# List recent sessions with metadata
for f in $(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -10); do
  SESSION_ID=$(basename "$f" .jsonl)
  SIZE=$(du -sh "$f" | cut -f1)
  MODIFIED=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f")
  # Get first user message as topic hint
  TOPIC=$(grep -m1 '"role":"user"' "$f" 2>/dev/null | python3 -c "
import sys, json
try:
    line = json.loads(sys.stdin.readline())
    msg = line.get('message', {})
    content = msg.get('content', '')
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get('type') == 'text':
                content = c['text']
                break
    print(str(content)[:80])
except: print('(no topic)')
" 2>/dev/null)
  echo "$MODIFIED  $SIZE  $SESSION_ID  $TOPIC"
done
```
Stop here if `--list` was specified.

If `--search`:
```bash
# Search across sessions for keyword
grep -l "$QUERY" "$SESSION_DIR"/*.jsonl 2>/dev/null | while read f; do
  SESSION_ID=$(basename "$f" .jsonl)
  MODIFIED=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f")
  echo "$MODIFIED  $SESSION_ID"
done
```
Stop here if `--search` was specified.

## Step 2: Extract Context

For the target session (specific ID or most recent):

```bash
SESSION_FILE="$SESSION_DIR/$SESSION_ID.jsonl"

# Skip if this is the active session (modified < 60s ago)
if [ $(($(date +%s) - $(stat -f '%m' "$SESSION_FILE"))) -lt 60 ]; then
  echo "WARNING: This appears to be the currently active session. Skipping."
  exit 1
fi
```

### Find Compact Summary (Highest-Signal Context)

The compact summary is Claude's own distilled understanding of the conversation:

```bash
# Find the last compaction boundary and extract the summary
python3 -c "
import json, sys

session_file = '$SESSION_FILE'
last_compact = None

with open(session_file) as f:
    for line in f:
        try:
            entry = json.loads(line.strip())
            if entry.get('type') == 'summary':
                last_compact = entry
        except: pass

if last_compact:
    msg = last_compact.get('summary', last_compact.get('message', {}).get('content', ''))
    if isinstance(msg, list):
        texts = [c.get('text', '') for c in msg if isinstance(c, dict) and c.get('type') == 'text']
        msg = '\n'.join(texts)
    print('=== COMPACT SUMMARY ===')
    print(str(msg)[:3000])
else:
    print('No compaction found (short session)')
" 2>/dev/null
```

### Extract Recent Messages

```bash
# Get last 20 meaningful messages (skip system/progress)
python3 -c "
import json

session_file = '$SESSION_FILE'
messages = []

with open(session_file) as f:
    for line in f:
        try:
            entry = json.loads(line.strip())
            if entry.get('type') in ('user', 'assistant'):
                msg = entry.get('message', {})
                role = msg.get('role', entry.get('type', ''))
                content = msg.get('content', '')
                if isinstance(content, list):
                    texts = [c.get('text', '') for c in content if isinstance(c, dict) and c.get('type') == 'text']
                    content = '\n'.join(texts)
                content = str(content).strip()
                # Skip system reminders and empty
                if content and '<system-reminder>' not in content and '<task-notification>' not in content:
                    messages.append((role, content[:500]))
        except: pass

print('=== RECENT MESSAGES (last 20) ===')
for role, content in messages[-20:]:
    print(f'\n[{role.upper()}]: {content}')
" 2>/dev/null
```

### Check for Errors and Unresolved Work

```bash
# Find tool errors
python3 -c "
import json

session_file = '$SESSION_FILE'
errors = []

with open(session_file) as f:
    for line in f:
        try:
            entry = json.loads(line.strip())
            if entry.get('type') == 'tool_result':
                content = entry.get('content', '')
                if 'error' in str(content).lower():
                    errors.append(str(content)[:200])
        except: pass

if errors:
    print('=== ERRORS ENCOUNTERED ===')
    for e in errors[-5:]:
        print(f'- {e}')
else:
    print('No errors found in session')
" 2>/dev/null
```

## Step 3: Check Current Workspace State

```bash
# Current git state
git status --short
git log --oneline -5

# Check for living plan
cat .plan.md 2>/dev/null | head -40

# Check for in-progress beads
bd list --status=in_progress 2>/dev/null
```

## Step 4: Reconcile and Continue

Before making changes:
1. Confirm current directory matches the session's project
2. If git branch has changed, note and decide whether to switch
3. Verify old claims still hold by checking referenced files
4. Do NOT assume prior claims are valid without checking

Then:
- Implement the next concrete step from the last user request
- Run deterministic verification (tests, type-checks, build)
- If blocked, state the exact blocker and propose one next action

## Step 5: Report

```
=== CONTEXT RECOVERED ===
Session: [session-id]
Last active: [date]
Summary: [key findings from compact summary]

=== WORK EXECUTED ===
- [files changed]
- [commands run]
- [test results]

=== REMAINING ===
- [pending tasks, if any]
```

## Guardrails

- Do NOT run `claude --resume` or `claude --continue` - this skill provides context recovery within the current session
- Do NOT treat compact summaries as complete truth - they are lossy. Always verify against current workspace
- Do NOT overwrite unrelated working-tree changes
- Do NOT load full session files into context - use the extraction scripts above
- Session files are local only - cannot recover from other machines
