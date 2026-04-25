---
paths:
  - "scripts/obsidian/**"
  - ".config/fish/functions/obsidian-session-sync.fish"
  - "scripts/tmux/tmux-worktree-cleanup.sh"
  - "scripts/ticket-complete.sh"
  - ".claude/skills/wrap-up/**"
  - ".claude/skills/handoff/**"
---

# Obsidian Session Synthesis

Per-session synthesis of Claude Code work into the Obsidian vault. Triggered at multiple lifecycle boundaries to capture context before it's lost (compaction, worktree cleanup, ticket completion, etc.).

## Architecture

Single backing script (`scripts/obsidian/session-synthesize.sh`) with one Fish wrapper (`obsidian-session-sync` / `oss`). All callers — hooks, skills, scripts — funnel through these two surfaces.

## Trigger Surface

| Trigger | Reason tag | Force? | Wired in |
|---------|------------|--------|----------|
| `Stop` hook (every Claude turn end) | `stop` | no | `.claude/settings.json` |
| `SessionEnd` hook | `session-end` | yes | `.claude/settings.json` |
| `PreCompact` hook | `pre-compact` | yes | `.claude/settings.json` |
| tmux `prefix+x` (kill pane) | `worktree-cleanup` | yes | `scripts/tmux/tmux-kill-pane-cleanup.sh` → `tmux-worktree-cleanup.sh` |
| tmux `prefix+X` (kill window) | `worktree-cleanup` | yes | `.tmux.conf:405` → `tmux-worktree-cleanup.sh` |
| `ticket-execute --complete` | `ticket-done` | yes | `scripts/ticket-complete.sh` |
| `/wrap-up` skill | `wrap-up` | yes | `.claude/skills/wrap-up/SKILL.md` step 7 |
| `/handoff` skill | `handoff` | yes | `.claude/skills/handoff/SKILL.md` step 3 |
| `gwt-cleanup --reconcile` | `reconcile` | yes (mode bypasses) | `gwt-cleanup.fish:96,419` |

## Reason Tag

Every caller passes `--reason <tag>`. The tag flows into the Obsidian note's frontmatter as `reason: "<tag>"` and into `tags` as `trigger/<tag>`. Use this in Obsidian Dataview queries to filter by trigger:

```dataview
TABLE date, project FROM "Claude/Sessions"
WHERE reason = "pre-compact"
SORT date DESC
```

## Dedup Window

Default 60s per-cwd dedup gate prevents back-to-back fires (e.g., Stop immediately followed by PreCompact). Stamp file at `${TMPDIR:-/tmp}/obsidian-sync-dedup/<md5(cwd)>`.

- Tunable: `OBSIDIAN_SYNC_DEDUP_SEC=120` (env var)
- Bypass: `--force` flag (used by every non-Stop trigger so they always fire)
- Always bypassed: `--reconcile` and `--dry-run` modes

## Adding a New Trigger

1. Caller: invoke `obsidian-session-sync --reason <new-tag> --force` (Fish) or `bash session-synthesize.sh --cwd "$X" --reason <new-tag> --force` (Bash hooks/scripts).
2. Document the new reason in this file's trigger table.
3. No changes needed to the script itself — `SYNTH_REASON` is opaque to the synthesis logic; it only flows through to the frontmatter.

## Settings.json Edits

`.claude/settings.json` is protected by a PreToolUse hook (`settings-edit-redirect.py`). Always use `jq` via Bash to modify it, never `Edit`/`Write`. See `.claude/rules/hooks.md`.
