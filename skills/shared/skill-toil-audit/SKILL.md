---
name: skill-toil-audit
description: Audit OpenCode session history for repeated prompts and recurring workflows that can become skills, skill improvements, scripts, aliases, or commands. Run periodically to reduce agent TOIL.
argument-hint: "[--days 30|--all] [--min-count N] [--save PATH] [--json] [--stubs]"
---

# Skill TOIL Audit

Use this when the user asks to mine OpenCode history, find repetitive prompts, reduce TOIL, evaluate skill candidates, or run a periodic skill audit.

## Command

```bash
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py $ARGUMENTS
```

Useful examples:

```bash
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py --days 30
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py --days 90 --min-count 2 --stubs
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py --all --json
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py --save ~/obsidian/Claude/Audit/skill-toil-$(date +%F).md
```

## What It Checks

- Opens `~/.local/share/opencode/opencode.db` read-only with SQLite `mode=ro` so active WAL-backed history can be inspected safely.
- Extracts user text prompts from `message` and `part` JSON, ignoring `ignored: true` parts and compression/system noise.
- Extracts assistant `tool` parts and builds privacy-safe post-prompt tool-use sequences such as `grep -> read -> apply_patch`.
- Redacts obvious secrets before printing samples.
- Clusters exact normalized prompt repeats and recurring session-title themes.
- Compares prompt and tool-use candidates against existing skills in `~/dotfiles/skills/` to avoid duplicate skills.
- Classifies each candidate as `new-skill-candidate`, `improve-existing-skill`, `script-alias-or-command`, `inspect-session-theme`, or no result below threshold.

## Decision Rule

Do not create a skill just because text repeats. Create or improve a skill only when the candidate has one of these properties:

- Repeatable multi-step workflow.
- Durable instructions that should persist across devices.
- Safety or quality benefit from consistent execution.
- Regression examples that prevent future drift.

Otherwise recommend a command, alias, script, documentation update, or no action.

## Follow-Up Workflow

1. Run the audit with the desired time window.
2. Review the top candidates and their samples.
3. Review `Tool-use signals` to see whether repeated tool sequences imply a reusable workflow, script, or skill eval.
4. If the action is `improve-existing-skill`, edit that skill instead of creating a duplicate.
5. If the action is `new-skill-candidate`, inspect nearby session context before creating the skill.
6. Add fixture-backed checks or invariant tests for any accepted skill workflow.
7. Run `python3 scripts/validate-skills.py`, `scripts/sync-skills-harnesses.sh --check`, and `scripts/test-filter.sh opencode` after changes.

## Tracking Decisions

Use `--decisions path/to/decisions.json` to suppress rejected candidates or boost accepted ones.

```json
{
  "accepted": ["normalized candidate key"],
  "rejected": ["normalized candidate key"]
}
```

Candidate keys are present in `--json` output.
