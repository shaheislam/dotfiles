---
name: context-health
description: Audit the Obsidian vault and dotfiles context infrastructure for duplicates, stale files, structural issues, and context conflicts. Run weekly or when context quality degrades. Triggers on "audit context", "context health", "vault health", "check my second brain".
---

# Context Health — Vault & Context Infrastructure Audit

Systematic audit of your Obsidian second brain and dotfiles context layer. Produces an actionable health report.

## Arguments

- `$ARGUMENTS` — Optional:
  - `--vault-only` — Audit only the Obsidian vault (skip dotfiles context)
  - `--dotfiles-only` — Audit only the dotfiles context infrastructure
  - `--fix` — Auto-fix safe issues (empty files, broken wiki links)
  - Bare `/context-health` runs full audit

## Vault Location

```
VAULT=~/obsidian
DOTFILES_CONTEXT=<project-root>/.claude
```

## Phase 1: Vault Structure Audit

Check the Obsidian vault for structural health.

### 1a. Duplicate Detection

Find files with identical or near-identical names across different directories:

```bash
# Find potential duplicates by filename similarity
find ~/obsidian -name "*.md" -not -path "*/\.*" | sort | awk -F/ '{print $NF}' | sort | uniq -d
```

For each duplicate filename found, report:
- Both file paths
- Last modified dates
- First 5 lines of each (to assess if truly duplicate or just same-named)

### 1b. Stale File Detection

Find files not modified in 90+ days that might be outdated:

```bash
# Files older than 90 days (excluding templates and system files)
find ~/obsidian -name "*.md" -not -path "*/\.*" -not -path "*/templates/*" -not -path "*/_System/*" -mtime +90 | head -20
```

Flag files in active project directories that haven't been updated recently. Do NOT flag:
- Templates (they're meant to be static)
- Historical records (sessions, clippings with dates in filenames)
- Reference material (it stays valid)

### 1c. Empty & Stub Files

```bash
# Files under 50 bytes (likely stubs or placeholders)
find ~/obsidian -name "*.md" -not -path "*/\.*" -size -50c | head -20
```

### 1d. Broken Wiki Links

Read 10 random files with `[[wiki links]]` and verify the linked files exist:

```bash
# Sample files with wiki links
grep -rl '\[\[' ~/obsidian --include="*.md" | shuf | head -10
```

For each sampled file, extract `[[link]]` targets and check if the target file exists anywhere in the vault.

## Phase 2: Dotfiles Context Audit

Check the dotfiles context infrastructure for consistency.

### 2a. CLAUDE.md Hierarchy Consistency

Read all CLAUDE.md files in the project and check:
- Do `@import` targets exist?
- Are referenced files (in tables, links) still present?
- Do rule file `paths:` globs match actual file locations?

### 2b. Skills Completeness

For each skill directory in `.claude/skills/`:
- Does `SKILL.md` exist?
- Does it have valid YAML frontmatter (name, description)?
- Are referenced scripts/files still present?

```bash
# Skills without SKILL.md
for d in .claude/skills/*/; do
  [ -f "$d/SKILL.md" ] || echo "MISSING: $d/SKILL.md"
done
```

### 2c. Context File Freshness

Check if context files in `.claude/context/` are still accurate:
- Read each file
- Cross-reference key claims against the actual codebase
- Flag any obvious staleness (e.g., tool versions, file paths that no longer exist)

## Phase 3: Cross-Reference Audit

Check for consistency between the vault and dotfiles context.

### 3a. Skill-to-Vault References

For skills that reference `~/obsidian/` paths, verify those paths exist.

### 3b. Orphaned References

Find context files referenced in CLAUDE.md or skills that no longer exist.

## Phase 4: Report

Generate a structured health report:

```markdown
## Context Health Report — {DATE}

### Summary
- Vault files scanned: {N}
- Duplicates found: {N}
- Stale files flagged: {N}
- Empty/stub files: {N}
- Broken links sampled: {N}/{TOTAL_SAMPLED}
- Skills audited: {N}
- Missing skill files: {N}
- Orphaned references: {N}

### Grade: {A|B|C|D|F}

Grading criteria:
- A: 0 critical issues, <3 warnings
- B: 0 critical issues, 3-5 warnings
- C: 1-2 critical issues OR 6-10 warnings
- D: 3+ critical issues OR 10+ warnings
- F: Structural problems (missing CLAUDE.md, broken imports)

### Critical Issues
{List issues requiring immediate attention}

### Warnings
{List issues to address when convenient}

### Suggestions
{Improvement recommendations based on audit findings}
```

If `--fix` was specified, auto-fix safe issues and report what was fixed.

## Phase 5: Save Report

Save the report to the Obsidian vault:

```bash
# Save to vault
REPORT_PATH=~/obsidian/Claude/Audit/context-health-$(date +%Y-%m-%d).md
```

Add YAML frontmatter:
```yaml
---
type: context-health-audit
date: {TODAY}
grade: {GRADE}
tags:
  - audit
  - context-health
---
```
