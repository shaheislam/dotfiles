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
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py
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
- Reports skill inventory health using explicit invocation logs, historical slash prompts, stale-skill review candidates, and overlap signals.

## Skill Usage Tracking

Explicit slash-skill invocations are tracked without storing prompt text:

- Claude `UserPromptSubmit` runs `.claude/hooks/log-skill-invocation.py --harness claude`.
- OpenCode's harness compatibility plugin runs the same hook with `SKILL_INVOCATION_HARNESS=opencode`.
- The hook appends JSONL to `~/.local/state/agent-skills/invocations.jsonl`.
- Each record stores timestamp, harness, skill name, session id, cwd, and a prompt hash only.

The audit combines that tracker with local OpenCode and Claude history to classify skills as `active`, `stale-review`, `candidate-merge`, `keep-safety-rare`, `keep-compatibility-wrapper`, or `needs-better-trigger-description`.

## Monthly Per-Device Automation

`scripts/opencode/skill-toil-audit-monthly.sh` runs this audit with safe monthly defaults:

```bash
python3 ~/dotfiles/scripts/opencode/skill-toil-audit.py --days 30 --min-count 3 --limit 20
```

The monthly wrapper:

- Runs at most once per calendar month on each device using `~/.local/state/opencode/skill-toil-audit/last-run-month`.
- Saves reports under `~/obsidian/Claude/Audit/skill-toil/<hostname>/` when Obsidian exists, otherwise under `~/.local/state/opencode/skill-toil-audit/reports/`.
- Opens a `skill-toil-YYYY-MM` tmux window when a tmux server is already running.
- Runs headlessly and writes logs/reports when tmux is not available.

On macOS, setup installs `Library/LaunchAgents/com.dotfiles.skill-toil-audit.plist` to run the wrapper on the 1st of each month at 09:30 local time.

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
4. Review `Skill Inventory` before deleting or adding skills; prefer merge/deprecate over immediate deletion.
5. If the action is `improve-existing-skill`, edit that skill instead of creating a duplicate.
6. If the action is `new-skill-candidate`, inspect nearby session context before creating the skill.
7. Add fixture-backed checks or invariant tests for any accepted skill workflow.
8. Run `python3 scripts/validate-skills.py`, `scripts/sync-skills-harnesses.sh --check`, and `scripts/test-filter.sh opencode` after changes.

## Tracking Decisions

Use `--decisions path/to/decisions.json` to suppress rejected candidates or boost accepted ones.

```json
{
  "accepted": ["normalized candidate key"],
  "rejected": ["normalized candidate key"]
}
```

Candidate keys are present in `--json` output.
