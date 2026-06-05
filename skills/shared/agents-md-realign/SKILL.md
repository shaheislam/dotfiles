---
name: agents-md-realign
description: Realign AGENTS.md hierarchy and local-ignore policy across ~/dotfiles, ~/neovim, and ~/work repos. Use when asked to refresh, split, audit, enforce, or agentically refactor agent instruction files with isolated repo context.
argument-hint: "[--dry-run|--apply] [--agentic] [--all|--personal|--work|--repo PATH] [--batch-size N]"
user-invocable: true
---

# AGENTS.md Realign

Realign agent instruction files and ignore policy across personal and work repositories.

## Purpose

- Keep root `AGENTS.md` files concise.
- Keep detailed guidance in nested `AGENTS.md` files where hierarchical loaders can use it lazily.
- Keep `~/dotfiles` and `~/neovim` `AGENTS.md` files committed and cross-device.
- Keep `~/work/*/AGENTS.md` local-only through `.gitignore_local -> .git/info/exclude`.
- Use isolated subagents for repo-specific refactors when `--agentic` is requested.

## Command

Run from `~/dotfiles`:

```bash
scripts/tools/realign-agents-md.sh $ARGUMENTS
```

If no arguments were supplied, run a dry run first:

```bash
scripts/tools/realign-agents-md.sh --dry-run --all
```

Apply only after reviewing proposed changes:

```bash
scripts/tools/realign-agents-md.sh --apply --all
```

## Modes

- `--dry-run` shows proposed changes without writing files. This is the default.
- `--apply` writes changes.
- `--all` targets `~/dotfiles`, `~/neovim`, and `~/work/*` repos. This is the default target set.
- `--personal` targets only `~/dotfiles` and `~/neovim`.
- `--work` targets only `~/work/*` repos.
- `--repo PATH` targets one repo and can be repeated.
- `--agentic` performs repo-specific analysis with isolated subagents before applying deterministic policy.
- `--batch-size N` limits concurrent subagent batches. Default is 3.

## Deterministic Mode

Without `--agentic`, run the backing script directly:

```bash
scripts/tools/realign-agents-md.sh $ARGUMENTS
```

This mode enforces known policy and templates. It does not inspect each repo deeply.

## Agentic Mode

When `$ARGUMENTS` contains `--agentic`, do not rely on the script alone. Use this workflow:

1. Discover target repos:

```bash
scripts/tools/realign-agents-md.sh --list-repos $ARGUMENTS
```

2. Remove orchestration-only flags before running the deterministic script later: `--agentic`, `--batch-size`, and its numeric value.

3. Spawn one subagent per repo, batching by `--batch-size` if provided. Use the `general` subagent type for each repo.

4. Give each subagent only that repo path and the policy below. The subagent should inspect only its assigned repo and return a compact proposal:

```text
Analyze AGENTS.md hierarchy for REPO_PATH only.

Policy:
- Root AGENTS.md should contain global, durable repo rules only.
- Nested AGENTS.md files should exist only where directory-specific rules improve context loading.
- Personal repos ~/dotfiles and ~/neovim should keep AGENTS.md trackable.
- Work repos under ~/work should keep AGENTS.md local-only through .git/info/exclude.
- Preserve existing useful guidance; do not invent project facts.
- Prefer minimal edits.

Return:
- Repo classification: dotfiles | neovim | work | other
- Existing AGENTS.md files found
- Recommended AGENTS.md files to add/update/delete
- Exact proposed contents for each changed AGENTS.md
- Validation commands for this repo
- Risks or unknowns

Do not modify files.
```

5. Review subagent proposals in the main context. Apply only proposals that are concrete, minimal, and backed by repo evidence.

6. Run deterministic policy enforcement after applying accepted proposals:

```bash
scripts/tools/realign-agents-md.sh --apply $TARGET_FLAGS
```

7. Run validation.

Important: subagents must be read-only. The main agent applies changes after reviewing proposals so the final diff remains controlled.

## Required Policy

- Personal source-of-truth repos keep committed `AGENTS.md` files.
- Work repos keep repo-specific `AGENTS.md` files local-only unless the company repo explicitly adopts a committed contract.
- Do not move reusable personal guidance into work repos.
- Do not commit company-specific local workflow notes to shared company repos.

## Validation

After applying changes, run:

```bash
scripts/test-filter.sh agents-md
scripts/test-filter.sh setup-syntax
scripts/sync-skills-harnesses.sh --check
```

If `~/neovim` was changed, also run:

```bash
nvim --headless +qa
```
