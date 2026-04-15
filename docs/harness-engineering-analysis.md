# Harness Engineering Analysis

> Analysis of current dotfiles agent infrastructure against Harness Engineering principles.
> Date: 2026-03-15 | Branch: harnessengineering

## What Is Harness Engineering?

Harness Engineering is the discipline of designing environments, feedback loops, and
control systems that allow AI coding agents to do reliable work at scale. The engineer's
primary job shifts from writing code to:

1. **Specifying intent** through machine-readable documentation and structured context
2. **Building feedback loops** that validate agent output automatically
3. **Enforcing constraints** through deterministic tooling (linters, structural tests, CI)
4. **Managing entropy** through periodic cleanup agents and drift detection

**Sources**: [OpenAI](https://openai.com/index/harness-engineering/),
[Martin Fowler](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html),
[Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents),
[Datadog](https://www.datadoghq.com/blog/ai/harness-first-agents/)

### Three Pillars (OpenAI/Fowler)

| Pillar | Description |
|--------|-------------|
| **Context Engineering** | Machine-readable knowledge base + dynamic context (observability, navigation) |
| **Architectural Constraints** | Deterministic linters + structural tests (not just LLM-based) |
| **Entropy Management** | Periodic agents fighting inconsistency, docs drift, constraint violations |

### Anthropic's Harness Pattern for Long-Running Agents

| Component | Purpose |
|-----------|---------|
| **Initializer Agent** | First session creates init.sh, progress file, feature list |
| **Progress File** | claude-progress.txt maintains work history across sessions |
| **Structured Feature List** | JSON-based tracking with verification procedures |
| **Session Startup Routine** | pwd → git log → progress review → test → work |
| **Git-Based Recovery** | Revert bad changes, commit with descriptive messages |

### Datadog's Verification Pyramid

| Layer | Tool/Approach | Speed | Purpose |
|-------|---------------|-------|---------|
| Symbolic | TLA+ specs | 2 min | Understanding invariants |
| Primary | Deterministic Simulation Testing | ~5s | Fast correctness |
| Exhaustive | Model checking | 30-60s | Proof |
| Bounded | Kani verification | ~60s | Bounded proof |
| Empirical | Telemetry + benchmarks | Seconds-min | Ground truth |

---

## Gap Analysis

### Pillar 1: Context Engineering

| Harness Engineering Requirement | Current State | Gap Level |
|-------------------------------|---------------|-----------|
| Machine-readable knowledge base in repo | CLAUDE.md + RULES.md + PRINCIPLES.md + .claude/rules/*.md | **COVERED** |
| Cross-linked design & architecture docs | Partial — docs exist but not cross-linked for agent navigation | **MEDIUM** |
| Structured domain context (JSON/YAML) | .beads/ JSONL, YAML frontmatter in state files | **COVERED** |
| Dynamic context from observability | OTEL LGTM stack with Grafana dashboards + PromQL access | **COVERED** (was HIGH) |
| Agent access to runtime telemetry | OTEL metrics via Prometheus + session-report.sh --otel | **COVERED** (was HIGH) |
| Session continuity across restarts | bd prime + entire checkpoints + ralph-loop state | **COVERED** |
| Browser/navigation context | Playwright MCP available but not wired into harness feedback | **LOW** |

**Key Gap**: ~~Agents can *produce* telemetry but cannot *query* it.~~ **RESOLVED** —
`query-telemetry.sh` provides structured querying (failures, top-failures, error-rate, summary).
Agents can now ask "what failed in the last 24 hours?" and get structured answers.

### Pillar 2: Architectural Constraints

| Harness Engineering Requirement | Current State | Gap Level |
|-------------------------------|---------------|-----------|
| Deterministic custom linters | validate-bash.py (blocks dangerous commands), use_bun.py | **COVERED** |
| Structural tests (like ArchUnit) | test-architecture.sh (shebangs, Fish conventions, hooks, OTEL, paths) | **COVERED** (was PARTIAL) |
| Layered dependency enforcement | No formal layer model (Types → Config → Service → UI) | **HIGH** |
| CI/CD pipeline validation | No CI — local-only validation | **MEDIUM** |
| Pre-commit hooks for constraint enforcement | .githooks/pre-commit (ShellCheck, fish_indent, YAML, secrets) | **COVERED** (was MEDIUM) |
| Module boundary definitions | Stow packages provide implicit boundaries, not enforced | **LOW** |
| Documentation consistency enforcement | validate-docs.sh cross-references CLAUDE.md vs actual files | **COVERED** (was HIGH) |

**Key Gap**: ~~No traditional software engineering guardrails.~~ **MOSTLY RESOLVED** —
Pre-commit hooks enforce ShellCheck, fish_indent, YAML lint, Python syntax, and secret detection.
test-architecture.sh validates structural invariants. validate-docs.sh detects doc drift.
Remaining gap: no CI/CD pipeline (local-only validation).

### Pillar 3: Entropy Management

| Harness Engineering Requirement | Current State | Gap Level |
|-------------------------------|---------------|-----------|
| Periodic cleanup agents | gwt-cleanup + detect-drift.sh (stow, PATH, theme, stale files) | **COVERED** (was PARTIAL) |
| Documentation drift detection | validate-docs.sh (function table, rules, scripts, Brewfile parity) | **COVERED** (was HIGH) |
| Architectural constraint monitoring | detect-drift.sh (stow integrity, theme consistency, package drift) | **COVERED** (was MEDIUM) |
| Dead code / stale config detection | detect-drift.sh checks stale state files and orphan PIDs | **PARTIAL** (was MEDIUM) |
| Cross-worktree consistency | merge-driver-union.sh prevents conflicts but no proactive scanning | **LOW** |

**Key Gap**: ~~No garbage collection agents.~~ **MOSTLY RESOLVED** —
detect-drift.sh scans for stow drift, PATH parity, theme consistency, stale state files, orphan PIDs.
validate-docs.sh detects documentation staleness. Both run on-demand (not yet periodic/cron).

### Feedback Loop Completeness

| Feedback Loop Stage | Current State | Gap Level |
|---------------------|---------------|-----------|
| Agent generates output | Ralph-loop, gwt-ticket, ticket-execute | **COVERED** |
| Harness verifies output | test-architecture.sh + pre-commit + hook tests + verify-harness.sh | **COVERED** (was PARTIAL) |
| Production telemetry validates | query-telemetry.sh + session-report.sh (wired to SessionEnd) | **COVERED** (was HIGH) |
| Feedback updates harness | suggest-improvements.sh analyzes failures → actionable suggestions | **PARTIAL** (was HIGH) |

**Key Gap**: ~~Feedback loop is open-ended.~~ **MOSTLY RESOLVED** —
suggest-improvements.sh reads harness-features.json pass/fail status and failure telemetry to
produce prioritized improvement suggestions. The loop is: generate → verify → query → suggest.
Remaining gap: suggestions are generated but not auto-applied (requires human review).

---

## SWOT Analysis

### Strengths

| # | Strength | Evidence |
|---|----------|----------|
| S1 | **Comprehensive agent lifecycle management** | 15+ hooks across 7 lifecycle events; agent-state.sh derives state from ground truth; witness monitors per-worktree |
| S2 | **Multi-agent orchestration at scale** | Crown tournaments, merge queue, phase gates, convoy patterns — few personal setups have this |
| S3 | **Persistent agent memory** | Beads (bd) with JSONL git-backed storage, session injection via bd prime, cross-project via town-beads |
| S4 | **Intelligent failure recovery** | agent-triage.sh with START/WAKE/NUDGE decisions, retry limits, stuck detection, crash recovery |
| S5 | **Usage-aware scheduling** | Queue daemon with Anthropic API usage monitoring, multi-subscription profile rotation |
| S6 | **Rich state file ecosystem** | YAML frontmatter in .local.md files, JSONL audit logs, PID tracking — zero-file-cache pattern |
| S7 | **Session continuity** | Entire checkpoints + beads prime + ralph-loop iteration tracking survive compaction |
| S8 | **Cross-provider capability** | Codex bridge, Ollama, Gemini, DeepSeek integration via cross-provider bridge |
| S9 | **Strong hook infrastructure** | 25+ hooks wired in settings.json, tested by 44-test suite, clear lifecycle coverage |
| S10 | **Agent-accessible documentation** | CLAUDE.md hierarchy, .claude/rules/ on-demand loading, skills system |

### Weaknesses

| # | Weakness | Impact |
|---|----------|--------|
| W1 | ~~No agent-queryable telemetry interface~~ **RESOLVED** | OTEL LGTM stack + Grafana dashboards + session-report.sh --otel |
| W2 | **No deterministic structural tests** | smoke-test.sh checks existence but not architectural invariants (e.g., "all Fish functions must have --description") |
| W3 | **No documentation drift detection** | CLAUDE.md and rules/ can become stale without anyone noticing |
| W4 | **No git pre-commit enforcement** | Constraints only fire during Claude sessions, not on manual commits or other tools |
| W5 | **No formal dependency layering** | No enforced module boundaries; stow packages are implicit |
| W6 | **Feedback loop not closed** | Data flows one way: agent → logs. No automated log → harness improvement path |
| W7 | **No automated test-on-commit** | Tests exist but require manual invocation; no CI-like automation |
| W8 | **Single-machine architecture** | All state lives on one Mac; no remote observability dashboard |
| W9 | ~~No metrics aggregation~~ **RESOLVED** | OTEL Prometheus aggregates metrics; Grafana dashboard trends tool failures, costs, sessions |
| W10 | **Hook tests don't run automatically** | 44 tests exist but need manual `test-filter.sh hooks` invocation |

### Opportunities

| # | Opportunity | Harness Engineering Alignment |
|---|-------------|-------------------------------|
| O1 | **Build telemetry query interface** | Close the verification loop — let agents query their own failure history |
| O2 | **Add structural architecture tests** | Enforce Fish function conventions, stow package boundaries, config consistency |
| O3 | **Create entropy management agents** | Periodic doc drift scanner, stale config detector, broken symlink finder |
| O4 | **Wire git pre-commit hooks** | Universal constraint enforcement regardless of who/what commits |
| O5 | **Build observability dashboard** | Aggregate JSONL logs into time-series metrics; trend failure rates |
| O6 | **Implement progress file pattern** | Anthropic's claude-progress.txt pattern for session continuity |
| O7 | **Add property-based testing** | Validate Fish functions with randomized inputs (ShellCheck + custom) |
| O8 | **Create harness improvement loop** | Automated analysis of failures → suggested hook/test additions |
| O9 | **Formalize architectural layers** | Define and enforce: core → config → functions → scripts → agents |
| O10 | **Export metrics to local Grafana** | Self-hosted observability stack (already have Ollama infrastructure) |

### Threats

| # | Threat | Mitigation |
|---|--------|------------|
| T1 | **Complexity ceiling** | 25+ hooks, 18 agents, 59 skills — onboarding friction. Mitigate: use harness to self-document |
| T2 | **State file proliferation** | Multiple YAML/JSON/JSONL formats. Mitigate: standardize on JSONL + query interface |
| T3 | **Single point of failure** | macOS machine is SPOF. Mitigate: git-backed state (beads), stow reproducibility |
| T4 | **Harness maintenance burden** | More harness = more maintenance. Mitigate: harness should self-validate (meta-tests) |
| T5 | **Tool version drift** | Homebrew updates can break integrations. Mitigate: version pinning + smoke tests |
| T6 | **Over-engineering risk** | Adding too much infrastructure for a personal dotfiles repo. Mitigate: implement incrementally, measure value |

---

## Implementation Roadmap

### Phase 1: Close the Verification Loop (Quick Wins)

**Priority: HIGH | Effort: LOW-MEDIUM**

These directly address the biggest harness engineering gap: the open feedback loop.

#### 1.1 Telemetry Query Script
Create `scripts/harness/query-telemetry.sh` that agents can invoke to answer:
- "What tools failed most in the last N days?"
- "What was my completion rate this week?"
- "Show recent errors matching pattern X"

Reads from existing JSONL logs, returns structured output.

#### 1.2 Session Health Report
Create `scripts/harness/session-report.sh` that runs at SessionEnd:
- Summarizes: tools used, failures encountered, time spent, beads closed
- Appends to `~/.claude/harness/session-reports.jsonl`
- Available to next session via bd prime or startup hook

#### 1.3 Git Pre-Commit Hook
Create `.githooks/pre-commit` that runs:
- ShellCheck on modified .sh files
- fish_indent --check on modified .fish files
- Stow dry-run validation
- YAML lint on modified YAML files

Wire with `git config core.hooksPath .githooks`

### Phase 2: Structural Tests & Constraints (Foundation)

**Priority: HIGH | Effort: MEDIUM**

#### 2.1 Architecture Test Suite
Create `scripts/harness/test-architecture.sh`:
- All Fish functions have --description flag
- All scripts have shebang + set -e/u
- No hardcoded paths outside $HOME or /tmp
- Stow packages don't overlap
- All .config/ dirs have matching stow entries

#### 2.2 Documentation Consistency Validator
Create `scripts/harness/validate-docs.sh`:
- Cross-reference CLAUDE.md mentions against actual files
- Detect function table entries vs actual functions in .config/fish/functions/
- Flag broken internal references in .claude/rules/*.md
- Verify Brewfile entries match setup.sh references

#### 2.3 Hook Wiring Validator
Extend existing hook tests to auto-run:
- Wire `scripts/test-filter.sh hooks` into pre-commit
- Add to SessionStart as background validation

### Phase 3: Entropy Management (Ongoing Health)

**Priority: MEDIUM | Effort: MEDIUM**

#### 3.1 Drift Detection Agent
Create `scripts/harness/detect-drift.sh` (periodic cron or on-demand):
- Stow symlink integrity check (target exists, not stale)
- Tokyo Night theme consistency across configs
- Fish/Zsh PATH parity verification
- Brewfile vs actually-installed packages delta

#### 3.2 Documentation Freshness Scanner
Create `scripts/harness/scan-docs.sh`:
- Compare git blame dates on docs vs code they reference
- Flag docs not updated in >30 days if referenced code changed
- Generate drift report as JSONL

#### 3.3 Dead Config Detector
Create `scripts/harness/find-dead-config.sh`:
- Fish functions that are never aliased or called
- Stow packages that aren't linked
- MCP servers configured but not responding
- Scripts not referenced from setup.sh or CLAUDE.md

### Phase 4: Observability Dashboard (Aggregate & Trend)

**Priority: LOW | Effort: HIGH**

#### 4.1 Metrics Aggregator
Create `scripts/harness/aggregate-metrics.sh`:
- Parse all JSONL logs into daily summaries
- Track: session count, tool failures/day, avg session duration, beads throughput
- Store in `~/.claude/harness/metrics.jsonl`

#### 4.2 Local Dashboard
Extend `agent-dashboard.sh` or create new:
- Time-series visualization of agent metrics
- Failure pattern detection
- Session efficiency trends
- Leverages existing Python/web infrastructure

#### 4.3 Harness Self-Improvement Loop
Create `scripts/harness/suggest-improvements.sh`:
- Analyze failure patterns → suggest new hooks or tests
- Detect recurring manual interventions → suggest automation
- Track harness coverage ratio (what % of failures are caught automatically)

---

## Mapping: Current Infrastructure → Harness Engineering Concepts

| Harness Engineering Concept | Your Implementation | Maturity |
|----------------------------|---------------------|----------|
| Context Engineering | CLAUDE.md + rules/ + beads + skills | **High** |
| Architectural Constraints | validate-bash.py + smoke-test.sh + test-architecture.sh + pre-commit | **High** |
| Entropy Management | gwt-cleanup + detect-drift.sh + validate-docs.sh | **Medium** |
| Agent State Derivation | agent-state.sh (zero-file-cache) | **High** |
| Failure Recovery | agent-triage.sh (START/WAKE/NUDGE) | **High** |
| Merge Serialization | merge-queue.sh | **High** |
| Session Continuity | beads + entire checkpoints | **High** |
| Telemetry Collection | JSONL logs (tool failures, notifications) | **Medium** |
| Telemetry Consumption | OTEL LGTM + Grafana + session-report --otel | **High** |
| Verification Loop | suggest-improvements.sh + verify-harness.sh (feature pass/fail tracking) | **Medium** |
| Documentation Drift Detection | validate-docs.sh (function table, rules, scripts cross-ref) | **Medium** |
| Structural Architecture Tests | test-architecture.sh (shebangs, Fish conventions, hooks, OTEL, paths) | **High** |
| Pre-Commit Enforcement | .githooks/pre-commit (ShellCheck, fish_indent, YAML, Python, secrets) | **High** |
| Periodic Health Agents | detect-drift.sh + suggest-improvements.sh (manual invocation) | **Low** |
| Metrics Aggregation | OTEL Prometheus (costs, tokens, tool durations, cache rates) | **High** |
| Observability Dashboard | Grafana LGTM + Claude Code dashboard + agent-dashboard.sh | **High** |
| Initializer Pattern | init.sh bootstraps harness (hooks, permissions, directories, verification) | **High** |
| Feature List Pattern | harness-features.json with pass/fail tracking via verify-harness.sh | **High** |

---

## Verdict

Your setup is **exceptionally strong** across all three harness engineering pillars.

**Context Engineering**: High maturity — CLAUDE.md hierarchy, beads memory, skills system, OTEL telemetry.

**Architectural Constraints**: High maturity — test-architecture.sh enforces shell/Fish conventions,
.githooks/pre-commit validates on every commit (ShellCheck, fish_indent, YAML, secrets), validate-bash.py
blocks dangerous commands at runtime.

**Entropy Management**: Medium maturity — detect-drift.sh checks stow integrity, PATH parity, theme
consistency, stale state files. validate-docs.sh cross-references CLAUDE.md against actual files.

**Verification Loop**: Medium maturity — suggest-improvements.sh analyzes failure telemetry and feature
status to produce actionable suggestions. verify-harness.sh tracks 10 harness capabilities with
pass/fail status in harness-features.json (Anthropic's feature_list.json pattern).

**Remaining gaps** (LOW priority):
1. Architecture tests and drift detection run manually, not in lifecycle hooks
2. No periodic cron-based health checks (entropy management is on-demand only)
3. Feedback loop could be tighter — suggestions are generated but not auto-applied
