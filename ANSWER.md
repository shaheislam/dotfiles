# Skills Audit: Recommendations for New Skills

## Executive Summary

After cataloging all 32 existing skills, analyzing git history (300+ commits since Jan 2026), beads task patterns, 14 hook events with 30+ implementations, and 15 subagents, the clearest gaps align with **explicitly documented pain points**: setup parity (Fish/Zsh PATH, MCP Desktop/CLI), drift detection, and validation — all called out in CLAUDE.md and AGENTS.md but lacking unified skill entry points.

Observability infrastructure exists across multiple layers — `/session-review` (git-based), `/jfdi-synthesis` (external DB), `insights-review.toml` (workflow orchestrator), and harness scripts (`session-report.sh`, `query-telemetry.sh`) — but no single interactive skill fuses JFDI + OTEL + beads data together. The higher-leverage opportunity is enriching existing skills rather than creating new observability skills from scratch.

## Current Skills by Category (32 total)

| Category | Count | Skills |
|----------|-------|--------|
| **Workflow** | 4 | start, wrap-up, session-review, ticket-execute |
| **Knowledge Mgmt** | 6 | jfdi, jfdi-sync, jfdi-extract, jfdi-recall, jfdi-synthesis, dream |
| **Research & Analysis** | 4 | gap-analysis, best-practice, research-spike, youtube |
| **Content & Publishing** | 3 | article, confluence, diagram |
| **Ticketing** | 3 | todo, jira, jira-batch |
| **Dev Infrastructure** | 6 | dotfiles-sync, fish-reload, mcp-restart, git-config-fix, commit-mode, claude-cleanup |
| **Cloud & Ops** | 3 | aws-profile, s3-search, s3-upload |
| **Specialized** | 3 | cv-generate, cross-ref, agent-browser |

## Recommended New Skills (Prioritized)

### Tier 1: High-Value, Addresses Documented Pain Points

#### 1. `/health-check` — Dotfiles & Tooling Health Dashboard

**What**: Run all validation scripts (`test-architecture.sh`, `validate-docs.sh`, `detect-drift.sh`, stow simulate, Fish/Bash syntax checks) in one shot. Report pass/fail with actionable fixes.

**Why — matches documented pain points**: CLAUDE.md's Troubleshooting section explicitly lists missing PATH, theme inconsistency, plugin failures, and stow conflicts as recurring issues. AGENTS.md warns about file location mistakes, shell script parity, and MCP parity. These are the most concrete, repeatedly documented problems. The `dotfiles-doctor` agent exists but isn't a skill — meaning you can't invoke it with `/health-check` from any session.

**Evidence**: `detect-drift.sh` checks stow integrity, PATH parity, theme consistency, stale state files. `test-architecture.sh` validates structural invariants. `validate-docs.sh` checks doc accuracy. These scripts exist and work but have no unified entry point. The `insights-review.toml` workflow orchestrates them but requires manual invocation of each step.

**Trigger**: `/health-check`, or "check my dotfiles", "is everything working", "validate my setup"

---

#### 2. `/hook-audit` — Hook Effectiveness Review

**What**: Enumerate all configured hooks, check which are actually executing (via JSONL logs or OTEL telemetry), identify stale hooks (referenced but missing scripts), and measure hook duration/failure rates.

**Evidence**: You have 14 hook events with 30+ implementations. Several hooks reference scripts that may have drifted (e.g., `session-synthesize.sh`, `session-end-extract.py` with missing dependencies). The hooks analysis doc is comprehensive but one-off — no recurring audit.

**Trigger**: `/hook-audit`, or "which hooks are firing", "audit my hooks", "stale hooks"

---

#### 3. Enrich `/session-review` with OTEL + Beads Inputs (Extend Existing Skill)

**What**: Instead of a new `/pattern-mine` skill, extend the existing `/session-review` skill to pull from three data sources:
- **Git** (already does this): commits, diffs, file changes
- **OTEL** (add): tool durations, API costs, error rates via `query-telemetry.sh`
- **Beads** (add): task completion rates, blocked issue patterns via `bd stats`

**Why — lower risk than a new skill**: `/session-review` already has the retrospective framing and git integration. Adding OTEL and beads inputs enriches it without creating a parallel skill that fragments the workflow. `/jfdi-synthesis` handles the Obsidian/monthly view; the enriched `/session-review` handles interactive in-session analysis.

**Evidence**: Currently `/session-review` is git-only (reads commits from session boundary to HEAD). `session-report.sh` already fuses hook logs + beads + git at the script level. The skill just needs to call that script and incorporate its output.

**Security constraint**: Session data must stay local-only. No transcript content should be written to shared files. Opt-in scope: only analyze the current session unless explicitly asked for broader range. Redact file paths containing secrets directories (`.ssh/`, `.gnupg/`, `1Password/`).

**Trigger**: Same as current `/session-review`, now with richer output

---

#### 4. `/onboard-tool` — Script-Backed Tool Integration Validator

**What**: A script-backed skill (not a prompt-only checklist) that runs deterministic checks for a given tool name:
1. `grep -q <tool> homebrew/Brewfile` — verify Brewfile entry
2. `grep -q <tool> scripts/setup.sh` — verify setup script reference
3. Check Fish PATH for tool binary (`command -v <tool>` in fish context)
4. Check Zsh PATH parity (`zsh -c 'command -v <tool>'`)
5. `stow --simulate --verbose . 2>&1` — verify stow won't conflict
6. If GUI: check for `.config/<tool>/` directory and Tokyo Night colors

**Why — script-backed avoids drift**: A prompt-only checklist would duplicate CLAUDE.md and diverge over time. A script reads the canonical sources (Brewfile, setup.sh, config files) directly and reports what's missing. The skill invokes the script and formats the output, keeping the checklist in one place (the code).

**Evidence**: AGENTS.md documents recurring "file location mistakes" and "shell script parity" as explicit pain points. Multiple commits fix missing PATH entries or Zsh compatibility — indicating steps get skipped even with the CLAUDE.md checklist present. Post-change validation (stow dry-run) prevents breaking both config targets.

**Trigger**: `/onboard-tool <name>`, or "add a new tool", "integrate X into my dotfiles"

---

### Tier 2: Medium-Value, Addresses Recurring Patterns

#### 5. `/changelog` — Generate Human-Readable Changelog

**What**: Generate a changelog for the last N days/commits in a format suitable for personal review. Group by category (new tools, fixes, config changes, skill additions). Different from git log — it's a curated summary.

**Why**: With 300+ commits in 3 months, understanding "what changed this week" requires manual git log spelunking. The session changelog (`.claude/CHANGELOG.md`) is per-worktree and append-only — no cross-worktree view.

**Trigger**: `/changelog`, `/changelog 7d`, or "what changed this week", "recent changes summary"

---

#### 6. `/prompt-library` — Curate Effective Prompts

**What**: Manage a collection of prompts that work well for this project. Extract from session history, tag by task type, make searchable. Different from beads (which tracks tasks) — this tracks *how you ask for things*.

**Evidence**: Per-repo `gwt-prompt.local.md` files are created manually. No centralized prompt template collection. Effective prompts get lost in session history.

**Trigger**: `/prompt-library save`, `/prompt-library search <topic>`, or "save this prompt", "find a prompt for"

---

#### 7. `/witness` — Watch for Changes in External Dependencies

**What**: Given a file path, git ref, or URL, set up a monitoring task that alerts when changes are detected. Useful for tracking upstream changes in tools you integrate with.

**Evidence**: Multiple open beads are witness tasks (BEADS-0qg witness-dotfiles-linetrim, BEADS-4nq witness-dotfiles-beadscommit, BEADS-e8d witness-dotfiles-aimux). These are created manually and checked manually.

**Trigger**: `/witness <path-or-url>`, or "watch for changes in X", "notify me when X changes"

---

#### 8. `/stow-diff` — Preview Stow Changes Before Apply

**What**: Show exactly what symlinks would change, be created, or be removed by a stow operation. More informative than `stow --simulate --verbose` — groups by application, highlights conflicts, shows before/after state.

**Evidence**: Stow operations are a common source of issues. The testing conventions doc explicitly says "always run stow --simulate --verbose . before actual stow operations." A skill wrapping this with better output reduces friction.

**Trigger**: `/stow-diff`, or "preview stow changes", "what will stow do"

---

### Tier 3: Nice-to-Have, Lower Frequency

#### 9. `/theme-check` — Tokyo Night Consistency Audit

**What**: Scan all config files for color definitions and verify they match the Tokyo Night palette defined in `.claude/context/`. Flag any off-palette colors.

**Evidence**: CLAUDE.md says "ALWAYS maintain consistent theming (Tokyo Night) across applications." The context directory has theme specs. But no automated verification.

**Trigger**: `/theme-check`, or "check theme consistency", "are my colors right"

---

#### 10. `/mcp-parity` — MCP Server Configuration Parity Check

**What**: Compare MCP server configurations between Claude Desktop (`claude_desktop_config.json`) and CLI (`setup.sh` `claude mcp add` commands). Flag any servers present in one but not the other.

**Evidence**: CLAUDE.md explicitly says "CRITICAL: ALWAYS maintain parity between Claude Desktop and CLI." This is a manual check that could be automated.

**Trigger**: `/mcp-parity`, or "check mcp servers", "are my MCPs in sync"

---

## Extend vs Create: Prefer Enriching Existing Skills

Before creating new skills, consider whether an existing skill can absorb the capability:

| Need | Extend This | Add What |
|------|-------------|----------|
| Session observability | `/session-review` | OTEL metrics + beads stats via `session-report.sh` |
| Monthly patterns | `/jfdi-synthesis` | Beads completion trends, hook failure rates |
| Drift detection | `/dotfiles-sync` | Call `detect-drift.sh` as pre-flight check |
| Theme validation | `/dotfiles-sync` | Tokyo Night color audit as post-stow step |

Only create a new skill when the capability doesn't fit an existing skill's scope (e.g., `/health-check` unifies 3+ scripts that span multiple existing skill domains).

## Skills NOT Recommended (Covered Adequately)

| Need | Already Covered By |
|------|--------------------|
| Task creation | `/todo` + `/start` |
| Research | `/gap-analysis` + `/research-spike` + `/best-practice` |
| Memory consolidation | `/dream` + JFDI family |
| Browser automation | `/agent-browser` + Playwright MCP + PinchTab |
| CI/CD review | `ci-check` plugin skill |
| PR creation | `create-pr` plugin skill |
| Code review | `code-review` plugin skill |
| Session retrospective | `/session-review` (git) + `/jfdi-synthesis` (DB) + `insights-review.toml` (workflow) |

## Implementation Priority

Ranked by alignment with explicitly documented pain points (CLAUDE.md Troubleshooting, AGENTS.md warnings), not by assumed leverage:

1. **`/health-check`** — Directly addresses 4 of 4 Troubleshooting items (PATH, theme, plugins, stow). Wires existing scripts.
2. **`/onboard-tool`** — Script-backed validation against the most-skipped checklist. Prevents PATH parity fixes.
3. **Enrich `/session-review`** — Low-risk extension adds OTEL + beads to existing git-based retrospective.
4. **`/hook-audit`** — Infrastructure health for 30+ hook implementations that are hard to verify manually.
5. **`/mcp-parity`** — CLAUDE.md calls this "CRITICAL" but it's a manual check today.
6. **`/changelog`** — Low effort, useful for weekly reviews.

The remaining items (witness, stow-diff, prompt-library, theme-check) are valuable but lower frequency.

## Security Considerations

Skills that analyze session data or cross-reference configurations must respect these constraints:

- **Pattern mining / session review**: Local-only analysis. Never write transcript content, file paths containing secrets directories (`.ssh/`, `.gnupg/`, `1Password/`, `.codex/accounts/`), or API keys to shared files. Opt-in scope: analyze current session by default, broader range only on explicit request.
- **MCP/stow-related skills**: Always enforce dry-run before apply. Post-change validation required (verify both Desktop and CLI configs load correctly after parity fix; verify stow symlinks resolve after sync).
- **Hook audit**: Read-only analysis of hook logs. Never modify hook configurations without explicit user confirmation. Flag hooks that have filesystem write access to sensitive paths.

## Methodology

- **Skills catalog**: Read frontmatter of all 32 skills in `.claude/skills/`
- **Git history**: Analyzed 300+ commits since 2026-01-01 (188 feat, 134 fix, 50 docs, 27 test)
- **Beads**: Reviewed open and closed issues for recurring task patterns
- **Hooks**: Mapped all 14 hook events and 30+ implementations
- **Agents**: Reviewed 15 subagents for coverage overlap
- **Documentation**: Cross-referenced CLAUDE.md, rules/, and docs/ for stated workflows vs actual skill coverage
