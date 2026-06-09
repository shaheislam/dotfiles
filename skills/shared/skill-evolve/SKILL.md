---
name: skill-evolve
description: Evolve, prune, merge, or tighten dotfiles skills using the monthly skill-stats SQLite tracker and skill TOIL audit evidence. Use when reviewing skill bloat or improving skill performance over time.
argument-hint: "[--month YYYY-MM] [--dry-run]"
---

# Skill Evolve

Use this when the user asks to improve, prune, merge, or prioritize skills based on observed usage.

## Evidence Sources

- `~/.local/state/agent-skills/invocations.jsonl` is the append-only source of truth.
- `~/.local/state/agent-skills/skill-stats.sqlite` is the derived query index.
- `python3 ~/dotfiles/scripts/opencode/skill-stats.py top --days 30` shows active skills.
- `python3 ~/dotfiles/scripts/opencode/skill-stats.py unused --days 90` shows pruning candidates.
- `python3 ~/dotfiles/scripts/opencode/skill-stats.py describe <skill>` shows privacy-safe invocation evidence.
- `python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py --days 30 --min-count 3 --limit 20` adds repeated-prompt and tool-sequence evidence.

## Workflow

1. Refuse to start if the git worktree is dirty unless the user explicitly asks to include the existing changes.
2. Rebuild the stats index with `python3 scripts/opencode/skill-stats.py rebuild-index --days 90`.
3. Create or reuse a local branch named `skill-evolve/YYYY-MM`.
4. Make real edits in `skills/` only after the evidence supports the change.
5. Commit each accepted skill change separately.
6. Do not push automatically; leave the branch local for Neovim Diffview review.

## Commit Style

Use per-skill commit subjects so Diffview review is easy:

```text
skill-evolve: tighten description 'skill-name' (12 hits, 3 near misses)
skill-evolve: merge 'old-skill' into 'new-skill' (unused 90d)
skill-evolve: attic 'stale-skill' (unused 180d)
```

Commit bodies should include privacy-safe evidence only:

- Invocation counts and date windows.
- `prompt_hash` or message IDs, never raw prompt text.
- Audit classifications and cluster IDs.
- Validation commands run.

## Validation Gates

Run after each edit batch and before each commit:

```bash
python3 scripts/validate-skills.py
scripts/sync-skills-harnesses.sh --check
scripts/test-filter.sh opencode
```

If validation fails, revert only the current skill-evolve edit, log the failure, and continue with the next independent candidate.

## Pruning Rules

- Prefer tightening descriptions before deleting a skill.
- Prefer merging overlapping skills before atticking either one.
- Keep rare safety skills unless they are broken or duplicated.
- Do not delete compatibility wrappers without checking external command aliases and generated harness surfaces.
- Do not remove a skill based only on zero invocations if telemetry is known to be incomplete.

## Monthly Automation

The macOS LaunchAgent runs `scripts/opencode/skill-toil-audit-monthly.sh` monthly. That wrapper rebuilds the SQLite stats index, writes the Skill TOIL report, and opens a `skill-toil-YYYY-MM` tmux window when a tmux server is already running. Treat the monthly output as review input, not permission for unattended destructive pruning.
