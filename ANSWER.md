# Skills Audit: Recommendations for New Skills

## Executive Summary

After cataloging all 32 existing skills, analyzing git history (300+ commits since Jan 2026), beads task patterns, 14 hook events with 30+ implementations, and 15 subagents, the clearest gap is **workflow observability** — understanding what you do, what works, and what fails across sessions. You have excellent infrastructure for *doing* work but limited tooling for *learning from* work.

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

### Tier 1: High-Value, Fills Clear Gap

#### 1. `/health-check` — Dotfiles & Tooling Health Dashboard

**What**: Run all validation scripts (`test-architecture.sh`, `validate-docs.sh`, `detect-drift.sh`, stow simulate, Fish/Bash syntax checks) in one shot. Report pass/fail with actionable fixes.

**Why**: You have 3+ quality gate scripts that run ad-hoc. No single entry point combines them. The `dotfiles-doctor` agent exists but isn't a skill — meaning you can't invoke it with `/health-check` from any session.

**Evidence**: `detect-drift.sh` checks stow integrity, PATH parity, theme consistency, stale state files. `test-architecture.sh` validates structural invariants. `validate-docs.sh` checks doc accuracy. These are documented but not unified.

**Trigger**: `/health-check`, or "check my dotfiles", "is everything working", "validate my setup"

---

#### 2. `/hook-audit` — Hook Effectiveness Review

**What**: Enumerate all configured hooks, check which are actually executing (via JSONL logs or OTEL telemetry), identify stale hooks (referenced but missing scripts), and measure hook duration/failure rates.

**Evidence**: You have 14 hook events with 30+ implementations. Several hooks reference scripts that may have drifted (e.g., `session-synthesize.sh`, `session-end-extract.py` with missing dependencies). The hooks analysis doc is comprehensive but one-off — no recurring audit.

**Trigger**: `/hook-audit`, or "which hooks are firing", "audit my hooks", "stale hooks"

---

#### 3. `/pattern-mine` — Session Pattern Extraction

**What**: Analyze recent session transcripts (via JFDI database, OTEL telemetry, or beads history) to extract:
- Most-used tool sequences (e.g., Read->Edit->Bash patterns)
- Recurring prompting phrases that indicate unmet needs
- Error clusters (what fails repeatedly)
- Time-of-day and task-type distributions

**Why**: This is exactly what the current task is — and it's being done manually. This is the skill equivalent of "gap-analysis but for your own workflow."

**Evidence**: The JFDI family captures session data. OTEL captures metrics. Beads tracks tasks. But nothing synthesizes *across* these sources to find patterns. `/jfdi-synthesis` comes closest but is monthly Obsidian output, not interactive analysis.

**Trigger**: `/pattern-mine`, or "what patterns do you see", "analyze my sessions", "what do I do most"

---

#### 4. `/onboard-tool` — New Tool Integration Checklist

**What**: When adding a new CLI tool or GUI app, walk through the full integration checklist from CLAUDE.md:
1. Add to Brewfile
2. Add Fish PATH (`.config/fish/config.fish`)
3. Update `scripts/setup.sh`
4. Create aliases/functions
5. Add Zsh compatibility (`.zshrc`)
6. Apply Tokyo Night theme (if GUI)
7. Create `.config/` subdirectory (if needed)
8. Run stow simulate

**Why**: CLAUDE.md documents this checklist but it's easy to miss steps. A skill that walks through it interactively ensures completeness.

**Evidence**: The "Adding New Tools" section in CLAUDE.md is one of the most referenced sections. Multiple commits fix missing PATH entries or Zsh compatibility gaps — indicating steps get skipped.

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

## Implementation Priority

If building these, the order that maximizes value:

1. **`/health-check`** — Immediate value, mostly wiring existing scripts
2. **`/onboard-tool`** — Prevents recurring integration gaps
3. **`/pattern-mine`** — Deepest insight value, builds on JFDI + OTEL infrastructure
4. **`/hook-audit`** — Maintains hook infrastructure health
5. **`/changelog`** — Low effort, useful for weekly reviews

The remaining 5 are valuable but lower frequency — build them when the need arises naturally.

## Methodology

- **Skills catalog**: Read frontmatter of all 32 skills in `.claude/skills/`
- **Git history**: Analyzed 300+ commits since 2026-01-01 (188 feat, 134 fix, 50 docs, 27 test)
- **Beads**: Reviewed open and closed issues for recurring task patterns
- **Hooks**: Mapped all 14 hook events and 30+ implementations
- **Agents**: Reviewed 15 subagents for coverage overlap
- **Documentation**: Cross-referenced CLAUDE.md, rules/, and docs/ for stated workflows vs actual skill coverage
