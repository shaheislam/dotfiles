---
name: morning-brief
description: Generate a daily briefing by pulling live context from the Obsidian vault (second brain). Demonstrates the vault-referencing skill pattern where skills read from a centralized context layer instead of bundling their own copies. Use at the start of a work session. Triggers on "morning brief", "daily brief", "what should I focus on today".
---

# Morning Brief — Vault-Referenced Daily Overview

> **Pattern**: This skill reads context directly from `~/obsidian/` at runtime.
> It does NOT bundle reference files — when the vault is updated by other
> skills, scheduled tasks, or manual edits, this skill automatically sees
> fresh data. This is the Level 6 "second brain reference" pattern.

## Vault Context Sources

Read these files from the Obsidian vault to build the briefing. Skip any that don't exist.

### Priority & Strategy Context
```
~/obsidian/CLAUDE.md                    — Vault navigation and routing rules
~/obsidian/Career/CV/skills.md          — Current skills inventory
```

### Recent Activity Context
```
~/obsidian/Claude/Sessions/             — Last 3 session summaries (by date)
~/obsidian/Claude/Memories/decision/    — Recent decisions (last 5 files)
~/obsidian/Claude/Memories/learnings/   — Recent learnings (last 5 files)
```

### Active Work Context
```
~/obsidian/Projects/                    — Active project directories
```

### Daily Context
```
~/obsidian/Daily/                       — Today's daily note (if exists)
```

## Briefing Generation

### Step 1: Gather Context

Read each source file listed above. For directories, read the most recent files (sorted by modification date). Do not read more than 20 files total — this skill should be fast.

```bash
# Find recent session files
ls -t ~/obsidian/Claude/Sessions/*.md 2>/dev/null | head -3

# Find recent decision files
ls -t ~/obsidian/Claude/Memories/decision/*.md 2>/dev/null | head -5

# Find recent learning files
ls -t ~/obsidian/Claude/Memories/learnings/*.md 2>/dev/null | head -5

# List active projects
ls ~/obsidian/Projects/ 2>/dev/null
```

### Step 2: Check Active Beads

```bash
bd ready 2>/dev/null | head -20
bd list --status=in_progress 2>/dev/null | head -10
```

### Step 3: Synthesize Briefing

Generate a concise daily briefing covering:

1. **Active Work** — What beads are in progress or ready? What was the last session working on?
2. **Recent Decisions** — Key decisions from the last few sessions that provide continuity
3. **Learnings & Patterns** — Recent insights worth keeping in mind today
4. **Suggested Focus** — Based on priorities, open work, and momentum, what should you focus on?
5. **Context Warnings** — Any stale context, blocked work, or decisions pending follow-up

### Step 4: Output

Present the briefing directly in the conversation. Keep it under 500 words. Use this format:

```markdown
# Morning Brief — {DATE}

## Active Work
{2-3 bullet points on current state}

## Recent Decisions
{Key decisions providing continuity}

## Today's Focus
{1-2 recommended priorities based on open work and momentum}

## Heads Up
{Anything that needs attention — stale context, blocked items, follow-ups}
```

Do NOT save the briefing to a file unless the user asks. The value is in the live synthesis, not in a static document.
