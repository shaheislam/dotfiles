# Gap Analysis: garrytan/gstack vs dotfiles

**Source:** https://github.com/garrytan/gstack
**Current Repo:** ~/dotfiles (dotfiles-garrytan worktree)
**Date:** 2026-03-28

---

## Executive Summary

Analyzed 28 gstack skills + 8 power tools against 38 existing dotfiles skills, 15 agents, 30+ hooks, and 4 browser tools. Of 34 features inventoried, **8 are already present**, **11 are partial**, **10 are missing**, and **5 are N/A**. Top 3 opportunities by value score: **/retro** (git-history engineering retrospective, score 20), **/ship** (unified release workflow, score 16), and **/freeze+careful** (safety guardrails as skills, score 15).

The dotfiles repo already exceeds gstack in browser automation (4 tools vs 1), observability (OTEL stack vs JSONL), and multi-agent orchestration (convoys, molecules, mayor). The highest-value gaps are in **structured release workflows**, **git analytics**, and **on-demand safety constraints**.

---

## Feature Comparison Matrix

| # | Feature | Status | Value Score | Category |
|---|---------|--------|-------------|----------|
| 1 | /retro - Engineering retrospective | x Missing | 20 | analytics |
| 2 | /ship - Unified release workflow | ~ Partial | 16 | release |
| 3 | /freeze + /careful - Safety guardrails | ~ Partial | 15 | safety |
| 4 | /cso - Security auditing (OWASP+STRIDE) | ~ Partial | 15 | security |
| 5 | /autoplan - Combined review pipeline | x Missing | 12 | planning |
| 6 | /investigate - Systematic debugging | ~ Partial | 10 | debugging |
| 7 | /qa - Browser-based QA with auto-fix | ~ Partial | 9 | testing |
| 8 | /canary - Post-deploy monitoring | x Missing | 8 | ops |
| 9 | /office-hours - Product reframing | x Missing | 6 | strategy |
| 10 | /document-release - Auto-update docs | x Missing | 6 | docs |
| 11 | /plan-ceo-review - Product thinking | ~ Partial | 6 | planning |
| 12 | /plan-eng-review - Architecture review | ~ Partial | 6 | planning |
| 13 | /design-consultation - Design systems | ~ Partial | 5 | design |
| 14 | /benchmark - Post-deploy perf checks | x Missing | 5 | ops |
| 15 | Preamble system - Skill init checks | x Missing | 4 | infra |
| 16 | Template-based skill generation | x Missing | 4 | infra |
| 17 | Cookie import for browser testing | x Missing | 4 | testing |
| 18 | Proactive skill suggestions | ~ Partial | 3 | dx |
| 19 | Browser handoff (CAPTCHA) | x Missing | 3 | testing |
| 20 | Sidebar agent (Chrome extension) | - N/A | - | agent |
| 21 | /browse - Headless browser | ~ Present | - | testing |
| 22 | /review - Code review | Present | - | review |
| 23 | /codex - Cross-model analysis | Present | - | review |
| 24 | Self-update mechanism | ~ Partial | 3 | infra |
| 25 | Telemetry (remote) | Present | - | observability |
| 26 | Local analytics dashboard | Present | - | observability |
| 27 | Session heartbeat/tracking | Present | - | agent |
| 28 | Multi-host setup (Claude/Codex/Gemini) | Present | - | infra |
| 29 | /design-review - Visual audit | ~ Partial | 5 | design |
| 30 | /qa-only - Report-only testing | ~ Partial | 4 | testing |
| 31 | Completeness principle enforcement | Present | - | philosophy |
| 32 | /guard - Combined safety mode | x Missing | 12 | safety |
| 33 | /design-shotgun - Rapid design fixes | - N/A | - | design |
| 34 | /connect-chrome - Live browser control | - N/A | - | testing |

**Legend:** Present = fully implemented | ~ Partial = exists but incomplete | x Missing = not present | - N/A = not applicable

---

## Top Opportunities (Ranked by Value Score)

### 1. /retro - Engineering Retrospective -- Score: 20/25

**Status:** Missing
**Impact:** 5/5 -- Provides data-driven team/individual retrospectives from git history
**Feasibility:** 4/5 -- Git data is readily available; skill is prompt + script

**What gstack does:**
- Analyzes git history for configurable time windows (7d, 14d, 30d)
- Computes metrics: commits, LOC, test ratio, PR sizes, fix ratio
- Team-aware: identifies contributors, praises strengths, flags growth areas
- Tracks test health: total test files, tests added, regression commits
- Compares current window against prior period for trend analysis

**Current state in this repo:**
- `/session-review` provides end-of-session retrospective but is session-scoped, not time-window-scoped
- `/jfdi-synthesis` generates weekly reports from session DB but focuses on memory, not code metrics
- No skill combines git analytics + test health + team metrics into a single retrospective

**Recommended implementation:**
Create `.claude/skills/retro/SKILL.md` that:
1. Accepts time window arg (default 7d)
2. Runs `git log --since` with `--numstat` to compute LOC, commit counts, file churn
3. Analyzes test file changes (files matching `test`, `spec`, `_test` patterns)
4. Groups by author when multiple contributors
5. Compares against prior period
6. Outputs structured retrospective report

---

### 2. /ship - Unified Release Workflow -- Score: 16/25

**Status:** Partial (have `/wrap-up` + `/create-pr` separately)
**Impact:** 4/5 -- Eliminates manual multi-step release process
**Feasibility:** 4/5 -- Combines existing skills with git automation

**What gstack does:**
- Pre-flight checks (branch validation, uncommitted changes)
- Merges base branch into feature branch
- Bootstraps test framework if missing
- Coverage audit with ASCII diagram
- Auto-generates tests for coverage gaps
- Opens PR with structured description

**Current state in this repo:**
- `/wrap-up` handles: lint, typecheck, tests, commit, bead close
- `/create-pr` handles: PR creation
- No unified skill that chains: sync + test + coverage + commit + PR

**Recommended implementation:**
Create `.claude/skills/ship/SKILL.md` that orchestrates:
1. Pre-flight: check branch, check for uncommitted changes
2. Sync: fetch + merge base branch
3. Validate: invoke existing `/wrap-up` validation (lint, typecheck, tests)
4. Coverage: run test coverage analysis
5. Commit + push
6. PR: invoke `/create-pr`

---

### 3. /freeze + /careful + /guard - Safety Guardrails -- Score: 15/25

**Status:** Partial (hooks exist but no on-demand toggle)
**Impact:** 3/5 -- Prevents accidents in unfamiliar codebases
**Feasibility:** 5/5 -- Thin skill that sets session-scoped hooks

**What gstack does:**
- `/careful`: Warns before any destructive command (rm -rf, git reset --hard, DROP TABLE)
- `/freeze <dir>`: Restricts ALL file edits to a single directory for the session
- `/guard`: Combines both -- freeze + careful
- `/unfreeze`: Removes the freeze boundary

**Current state in this repo:**
- `protect-files.py` PreToolUse hook blocks edits to specific paths
- Hooks warn about destructive operations
- But no **on-demand toggle** -- safety is always-on or always-off per hook config
- No directory freeze capability

**Recommended implementation:**
Create three skills:
- `.claude/skills/careful/SKILL.md` -- instructions to warn before destructive ops
- `.claude/skills/freeze/SKILL.md` -- sets a session-scoped directory constraint
- `.claude/skills/guard/SKILL.md` -- combines both

The freeze skill would instruct Claude to only edit files within the specified directory for the remainder of the session.

---

### 4. /cso - Security Auditing -- Score: 15/25

**Status:** Partial (have security agent, no structured audit framework)
**Impact:** 5/5 -- OWASP + STRIDE is industry-standard threat modeling
**Feasibility:** 3/5 -- Requires well-crafted security checklist prompt

**What gstack does:**
- Systematic OWASP Top 10 review
- STRIDE threat modeling
- Focuses on the actual codebase, not theoretical threats
- Produces actionable findings with severity ratings

**Current state in this repo:**
- `security-reviewer` agent reviews for vulnerabilities, credential exposure, injection
- `security` agent does threat modeling
- `devops-security-auditor` does infrastructure security
- But: no unified skill with OWASP/STRIDE framework, no structured report format

**Recommended implementation:**
Create `.claude/skills/security-audit/SKILL.md` that:
1. Runs OWASP Top 10 checklist against the codebase
2. Performs STRIDE threat modeling on key components
3. Produces structured report with severity, affected files, remediation

---

### 5. /autoplan - Combined Review Pipeline -- Score: 12/25

**Status:** Missing
**Impact:** 4/5 -- Eliminates running multiple review skills separately
**Feasibility:** 3/5 -- Orchestration of existing capabilities

**What gstack does:**
- Automatically runs CEO review, design review, and eng review in sequence
- Surfaces only subjective taste decisions for human input
- Produces a Review Readiness Dashboard

**Current state in this repo:**
- Has `brainstorming` superpowers skill for creative work
- Has `code-architect` agent for architecture
- Has `code-reviewer` agent for review
- But: no combined pipeline that sequences multiple review perspectives

**Recommended implementation:**
Create `.claude/skills/autoplan/SKILL.md` that:
1. Reads the current plan/PR/feature description
2. Runs product-level review (user value, completeness)
3. Runs architecture review (patterns, scalability, edge cases)
4. Runs security review (OWASP quick check)
5. Produces a Review Readiness Dashboard with pass/fail per dimension

---

## Already Present (Validation)

Features from gstack that this repo already implements well:

- **Browser automation**: agent-browser, Playwright MCP, and ClaudeCodeBrowser vs gstack's single /browse
- **Code review**: code-review plugin, pr-review-toolkit, claude-review.fish -- more comprehensive than gstack's /review
- **Cross-model analysis**: codex-bridge-review.sh + cross-provider bridge vs gstack's /codex skill
- **Telemetry**: Full OTEL LGTM stack (Grafana, Prometheus, Loki, Tempo) vs gstack's JSONL + Supabase
- **Local analytics**: OTEL Grafana dashboard with 8 metric types vs gstack's gstack-analytics
- **Session tracking**: gwt-status, tmux-claude-watcher, agent-state.sh vs gstack's heartbeat files
- **Multi-agent**: Convoys, molecules, mayor, town-beads vs gstack's single-agent model
- **Multi-host**: Cross-provider bridge (Codex, Gemini, Ollama, DeepSeek) vs gstack's setup --host

---

## Implementation Roadmap

### Phase 1: Quick Wins (Score 15-20) -- Est. 2-3 hours total

| Feature | Files to Create | Est. Effort |
|---------|----------------|-------------|
| /retro | `.claude/skills/retro/SKILL.md` | 45 min |
| /freeze + /careful + /guard | 3 skill files in `.claude/skills/` | 30 min |
| /ship | `.claude/skills/ship/SKILL.md` | 45 min |

### Phase 2: High Value (Score 12-15) -- Est. 3-4 hours

| Feature | Files to Create | Est. Effort |
|---------|----------------|-------------|
| /cso (security-audit) | `.claude/skills/security-audit/SKILL.md` | 60 min |
| /autoplan | `.claude/skills/autoplan/SKILL.md` | 60 min |

### Phase 3: Consider (Score 3-10)

- /canary, /benchmark -- post-deploy ops skills (lower priority for dotfiles)
- /office-hours -- product strategy (niche use case)
- /document-release -- auto-doc updates (covered by scribe agent)
- Cookie import, browser handoff -- browser enhancements (marginal over existing tools)

---

## Dependencies & Prerequisites

- No new Brewfile additions needed -- all skills are prompt-only
- No setup.sh changes -- skills are loaded from `.claude/skills/`
- The /retro skill benefits from `git log` with `--numstat` (already available)
- The /ship skill depends on existing `/wrap-up` and `/create-pr` skills

---

## Methodology

- **DeepWiki**: read_wiki_structure, read_wiki_contents, 4 ask_question calls
- **WebFetch**: GitHub README for feature list and installation
- **Current repo scan**: Glob, Grep, Bash for skills/, agents/, hooks/, functions/
- **Cross-reference**: Mapped 34 gstack features against current capabilities
