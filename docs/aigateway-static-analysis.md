# AI Gateway: Static Analysis for AI Agents

> Research findings on SonarQube, AST, LSP and how they can drive AI coding agents.
> Exploratory work — proof-of-concept implementations in `scripts/aigateway/`.

## Executive Summary

Three complementary technologies can feed structured code intelligence to AI agents:

| Technology | Strength | Speed | Agent Integration |
|-----------|----------|-------|-------------------|
| **LSP** | Real-time diagnostics, navigation, type info | Fast (live) | Already integrated via Claude Code LSP plugins |
| **AST (tree-sitter/ast-grep/semgrep)** | Structural pattern matching, custom rules | Fast (local) | New — `scripts/aigateway/` PoC |
| **SonarQube** | Comprehensive quality profiles, tech debt tracking | Slow (server) | Future — requires SonarQube server |

The key insight: **static analysis tools produce machine-readable findings that become actionable agent context**. Instead of the agent guessing what's wrong, it gets structured diagnostics with fix guidance.

## 1. LSP (Language Server Protocol)

### Current State

Already deeply integrated. 9 LSP servers active (see `docs/claude-code-lsp.md`):

```
Claude Code → LSP Tool → {goToDefinition, findReferences, hover, documentSymbol, workspaceSymbol}
              ↑
              Auto-diagnostics after Edit/Write
```

### What LSP Provides to Agents

| Capability | How Agents Use It |
|-----------|------------------|
| **Diagnostics** | Type errors, unused imports, unreachable code — surfaced immediately after edits |
| **Go-to-definition** | Agent navigates to implementation instead of grepping |
| **Find references** | Agent understands blast radius before refactoring |
| **Hover** | Type signatures and documentation without reading source |
| **Workspace symbols** | Find functions/classes across the project by name |

### Gap Analysis

What LSP currently **doesn't** provide to agents:
- **Code actions**: LSP has `textDocument/codeAction` (quick fixes, refactors) but Claude Code doesn't expose this yet
- **Rename refactoring**: LSP supports `textDocument/rename` for project-wide renames — not exposed
- **Formatting**: LSP `textDocument/formatting` could auto-format after agent edits
- **Call hierarchy**: `callHierarchy/incomingCalls` shows who calls a function

### LSP as First-Class Gateway Input

LSP diagnostics are already the highest-quality signal for many issue classes
(type errors, unused variables, unreachable code) because they're language-aware
with very low false positives. Rather than treating LSP as a separate system,
it should be a first-class input in the AI Gateway pipeline:

```
LSP diagnostics → normalize → unified finding format → agent context
```

**Advantages over semgrep/shellcheck for some classes**:
- **Type errors**: LSP has full type inference; semgrep has pattern matching
- **Unused code**: LSP tracks actual references; linters use heuristics
- **Import resolution**: LSP resolves real module graphs

**Current limitation**: Claude Code auto-injects LSP diagnostics after edits,
but these go through a separate channel (not the AI Gateway). Future work
should unify these into a single findings stream so agents see one coherent
list rather than split feedback from two systems.

### LSP → Gateway Integration Contract

To treat LSP as a first-class gateway input, diagnostics must map to the
unified schema. Here is the concrete mapping:

```
LSP Diagnostic → Gateway Finding
─────────────────────────────────
diagnostic.source        → tool: "lsp-{source}" (e.g., "lsp-pyright")
diagnostic.code          → rule: "{source}/{code}" (e.g., "pyright/reportMissingImports")
diagnostic.range.start   → file: from textDocument.uri, line: range.start.line + 1
diagnostic.range.end     → end_line: range.end.line + 1
diagnostic.severity      → severity: 1=error, 2=warning, 3=info, 4=info
diagnostic.message       → message
diagnostic.codeAction    → fix (if available via textDocument/codeAction)
diagnostic.data          → tool_native
```

**Precedence vs other tools**: LSP diagnostics take precedence over
semgrep/shellcheck for the same file:line because they have:
- Full type inference context (not pattern matching)
- Actual reference tracking (not heuristic)
- Lower false positive rate for type/import errors

**Rollout plan**:
1. **Phase 1** (current): LSP diagnostics flow through Claude Code's built-in
   auto-diagnostic channel, separate from the gateway
2. **Phase 2**: Create `scripts/aigateway/lsp-bridge.sh` that reads LSP
   diagnostic JSON from Claude Code's internal format and normalizes to
   gateway schema. Wire as an additional tool in analyze.sh
3. **Phase 3**: Expose LSP code actions through the gateway so agents can
   apply LSP-suggested fixes programmatically

**Blocker for Phase 2**: Claude Code does not currently expose LSP diagnostic
JSON in a machine-readable format accessible to hooks. This requires either
a Claude Code plugin API extension or reading from the LSP server directly.

### Recommendation

These unexposed LSP capabilities would multiply agent effectiveness:
1. **Code Actions** — Let agents apply LSP-suggested fixes directly
2. **Rename** — Safe project-wide renames via LSP instead of find-and-replace
3. **Call Hierarchy** — Understand calling patterns before modifying functions

## 2. AST (Abstract Syntax Trees)

### Tool Landscape

| Tool | Approach | Rule Format | Languages | Speed |
|------|----------|-------------|-----------|-------|
| **tree-sitter** | Parser generator | S-expression queries | 200+ | Very fast |
| **semgrep** | Pattern matching | YAML with code patterns | 30+ | Fast |
| **ast-grep** | Structural search | YAML with AST patterns | 20+ | Very fast |
| **comby** | Structural diff | Template patterns | Language-agnostic | Fast |

### tree-sitter

Universal AST parser. Already installed (`tree-sitter 0.25.10`).

**Query language** uses S-expressions:
```scheme
;; Find all function definitions with more than 3 parameters
(function_definition
  name: (identifier) @func-name
  parameters: (parameters
    (identifier) @param) (#match? @func-name ".*"))
```

**Agent use case**: Parse code into AST, identify structural patterns, query for anti-patterns.

**Limitation**: Low-level — you're writing tree queries, not code patterns. Better as a building block than a direct agent tool.

### semgrep

Pattern-based code search that understands code structure. Already installed.

**Key innovation**: Rules are written as code patterns, not regex:
```yaml
rules:
  - id: python-subprocess-shell-true
    pattern: subprocess.$FUNC(..., shell=True, ...)
    languages: [python]
    severity: ERROR
    message: "shell=True is dangerous"
    fix: subprocess.$FUNC([...], shell=False)
```

**Agent integration design**:
1. Define rules with `metadata.agent_guidance` — instructions for the AI on HOW to fix
2. Run semgrep → get JSON findings with line numbers, code snippets, and fix guidance
3. Inject findings into agent context as structured prompts
4. Agent reads guidance and applies fix

**PoC implementation**: `scripts/aigateway/semgrep-agent-rules.yaml`

**Semgrep also has**:
- **SARIF output** — Universal static analysis format, compatible with GitHub Code Scanning
- **Auto-fix** — Some rules include `fix:` that can be applied automatically
- **Custom rules registry** — Share rules across projects
- **MCP server** — Semgrep now ships with MCP support (`semgrep mcp`) for direct LLM integration

### ast-grep

Newer tool, fast structural code search. Uses tree-sitter under the hood.

**Key differentiator**: Pattern syntax is the target language itself:
```yaml
id: go-defer-in-loop
language: go
rule:
  pattern: |
    for $$$INIT {
        $$$BEFORE
        defer $EXPR
        $$$AFTER
    }
```

**PoC implementation**: `scripts/aigateway/ast-patterns/rules/`

**When to use ast-grep vs semgrep**:
- ast-grep: When you need **fast structural search** (grep-like speed) with AST awareness
- semgrep: When you need **comprehensive analysis** with taint tracking, data flow

### Tool Overlap & Precedence

Running both semgrep and ast-grep on the same code can produce duplicate or
contradictory findings. The gateway uses this precedence strategy:

| Concern | Owner | Rationale |
|---------|-------|-----------|
| Security (injection, secrets) | **semgrep** | Taint tracking, CWE mapping |
| Structural patterns (defer-in-loop, missing ctx) | **ast-grep** | Faster, native syntax |
| Style/convention | **semgrep** | Broader language support |
| Quick search (ad-hoc investigation) | **ast-grep** | Interactive, grep-like |

**Deduplication**: When both tools report the same file+line+category, the
gateway should prefer the finding with higher confidence and richer metadata.
Currently this is not implemented — it's a known limitation of the PoC.
The `tool` field in findings lets consumers filter by source tool.

**Rule ownership**: Each rule ID is prefixed with the tool name in the
unified schema (e.g., `semgrep/python-subprocess-shell-true`), so there's
no ambiguity about which tool produced the finding.

### Defining Custom Rules for Agents

The pattern across all AST tools: **rules are YAML files with metadata**.

This means we can create a **rule library** specifically for AI agents:

```yaml
# Rule with agent-specific metadata
rules:
  - id: security-sql-injection
    pattern: f"SELECT ... {$VAR} ..."
    metadata:
      agent_guidance: |
        Use parameterized queries:
        cursor.execute("SELECT ... WHERE id = ?", (var,))
      auto_fixable: true
      confidence: high
      priority: P0
```

**Architecture for agent-consumable rules**:
```
rules/
  ├── security/       # CWE-mapped security rules
  ├── reliability/    # Error handling, resource management
  ├── performance/    # N+1 queries, unnecessary allocations
  └── style/          # Project-specific conventions
```

### Rule Governance

`agent_guidance` is powerful but can encode unsafe or incorrect fixes.
Each rule should include:

- **`confidence`**: `high` / `medium` / `low` — agents should only auto-apply `high`
- **`version`**: Semantic version for the rule (track guidance changes)
- **`tested`**: Whether the guidance has been validated against real codebases

Rules with `confidence: low` should be surfaced as suggestions, not directives.
When guidance conflicts with project standards (e.g., project uses a specific
error handling pattern), the project `.claude/CLAUDE.md` takes precedence.

**Testing rule quality**: Run rules against known-good codebases and verify
that agent guidance produces correct fixes. Example test approach:
```bash
# Create a file with the anti-pattern
echo 'f = open("test.txt")' > /tmp/test_rule.py
# Run semgrep, verify it matches
semgrep --config semgrep-agent-rules.yaml /tmp/test_rule.py
# Verify agent_guidance is actionable (manual review or LLM eval)
```

**Fallback behavior**: If agent_guidance is absent or inapplicable, agents
should fall back to the rule's `message` field and their own judgment.

## 3. SonarQube

### Overview

SonarQube is a **centralized code quality platform** with:
- 5000+ built-in rules across 30+ languages
- Quality Gate policies (pass/fail thresholds)
- Technical debt tracking
- Security vulnerability detection (OWASP, CWE)

### API for Agent Integration

SonarQube exposes a comprehensive REST API:
```
GET /api/issues/search?componentKeys=project&types=BUG,VULNERABILITY
GET /api/rules/search?languages=py&types=BUG
GET /api/qualitygates/project_status?projectKey=myproject
```

**Agent workflow**:
1. Trigger SonarQube scan (via sonar-scanner CLI)
2. Poll API for results
3. Fetch issues with context (file, line, rule, effort estimate)
4. Feed to agent as prioritized fix list

### SonarLint (Local Alternative)

SonarLint runs the same rules **locally** without a server:
- IDE plugins (VS Code, IntelliJ)
- No CLI mode currently — but rules can be extracted
- Connected mode syncs quality profiles from server

### When SonarQube Makes Sense for Agents

| Scenario | Tool Choice |
|----------|-------------|
| Real-time feedback during edits | LSP diagnostics |
| Pre-commit structural checks | semgrep/ast-grep |
| CI/CD quality gates | SonarQube |
| Tech debt tracking across sprints | SonarQube |
| Custom project rules | semgrep + ast-grep |
| Security scanning | SonarQube + semgrep |

**Recommendation**: SonarQube is best for **CI/CD integration and project-wide quality tracking**, not for real-time agent feedback. For real-time, use LSP + semgrep.

## 4. Integration Architecture

### The AI Gateway Pattern

```
┌─────────────────────────────────────────────────────┐
│                    AI Gateway                        │
│  scripts/aigateway/analyze.sh                        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │shellcheck│  │  ruff    │  │ semgrep  │          │
│  │(bash)    │  │(python)  │  │(multi)   │          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       │              │              │                │
│       ▼              ▼              ▼                │
│  ┌──────────────────────────────────────────┐       │
│  │       Normalize → Unified + Native       │       │
│  │   Common: tool, rule, file, line,        │       │
│  │           severity, message              │       │
│  │   Native: tool_native (raw tool output)  │       │
│  │   Agent:  metadata.agent_guidance        │       │
│  └──────────────┬───────────────────────────┘       │
│                 │                                    │
│     ┌───────────┼───────────┐                       │
│     ▼           ▼           ▼                       │
│  [JSON]     [Prompt]     [SARIF]                    │
│  (API)      (Agent)      (GitHub)                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Schema Design: Unified + Lossless

The normalized schema has common fields for cross-tool queries, but preserves
tool-native data to avoid lossy flattening:

```json
{
  "tool": "semgrep",
  "rule": "python-subprocess-shell-true",
  "file": "src/main.py",
  "line": 42,
  "end_line": 42,
  "severity": "error",
  "message": "shell=True is dangerous",
  "fix": null,
  "metadata": {"agent_guidance": "...", "confidence": "high"},
  "tool_native": { "dataflow_trace": null, "metavars": null, "engine_kind": "OSS" },
  "dedup_key": "src/main.py:42",
  "duplicates_removed": 0
}
```

#### Field-Level Contracts

| Field | Type | Guarantee | When to use `tool_native` instead |
|-------|------|-----------|-----------------------------------|
| `tool` | string | Always present. Enum: `semgrep`, `shellcheck`, `ruff` | — |
| `rule` | string | Tool-prefixed rule ID (e.g., `SC2034`, `E501`) | — |
| `file` | string | Relative path from project root | — |
| `line` | int | 1-indexed start line | For column-level precision (shellcheck) |
| `end_line` | int | 1-indexed end line. Same as `line` for single-line | For SARIF region with endColumn |
| `severity` | string | Normalized to `error`/`warning`/`info` | For original severity (e.g., shellcheck `style`) |
| `message` | string | Human-readable description from tool | — |
| `fix` | object/null | Tool-specific fix structure (NOT normalized) | Always use tool_native for fix application |
| `metadata` | object | Preserved from rule definition. May contain `agent_guidance`, `confidence`, `cwe`, `version` | — |
| `tool_native` | object | Tool-specific fields not captured above | For taint traces, fix replacements, column info |
| `dedup_key` | string | `file:line` identity key (added by dedup pass) | — |
| `duplicates_removed` | int | Count of findings merged into this one | — |

**Critical consumer rule**: For fix application (auto-fix, code actions),
always use `tool_native.fix` — the top-level `fix` field is for presence
detection only, not for mechanical application.

**Known lossy mappings** (documented, not hidden):
- shellcheck `style` severity → normalized to `info` (original in `tool_native.original_level`)
- Semgrep taint findings lose dataflow trace in common fields (preserved in `tool_native.dataflow_trace`)
- Multiline code snippets truncated in prompt format (full in JSON)
- SARIF output does not include `taxonomies`, `invocations`, or `threadFlowLocations`

### Deduplication Policy

When multiple tools report findings at the same `file:line`:

1. **Identity key**: `file:line` (coarse) — intentionally simple for the PoC
2. **Winner selection**: higher severity wins. On tie, first tool in pipeline order
3. **Conflict annotation**: `duplicates_removed` field tracks how many findings were merged
4. **Future**: finer-grained key (`file:line:category`) once category is reliably extractable from all tools

### Hook Integration Points

| Hook Event | Tool | Purpose |
|-----------|------|---------|
| `PostToolUse` (Edit/Write) | shellcheck, ruff | Immediate feedback on edited files |
| `UserPromptSubmit` | semgrep (full) | Pre-task analysis of relevant files |
| `Stop` | ast-grep | Final scan before agent completes |
| `PreCompact` | — | Save analysis state before context compaction |

### Implementation: `.claude/hooks/static-analysis-context.sh`

A PostToolUse hook runs lightweight analysis after each Edit/Write:
- Shell files → shellcheck (single-file, sub-second)
- Python files → ruff (single-file, sub-second)
- Only injects findings when issues are found
- Skips semgrep in hook context (multi-second startup cost)
- Debounces rapid edits via lockfile (see hook implementation)

**Note**: Actual latency depends on file size, warm cache, and system load.
Run `scripts/aigateway/analyze.sh --benchmark` on your target files to measure.
Anecdotal single-file runs show shellcheck and ruff completing under 200ms,
but this is not a guarantee — profile before relying on it in tight loops.

## 5. Security & Privacy

### Path Redaction

The PostToolUse hook strips absolute paths to project-relative paths before
injecting into agent context. This prevents leaking full filesystem structure
(e.g., `/Users/shahe/dotfiles-aigateway/scripts/...` → `scripts/...`).

### Severity Gating

Only findings at `warning` or above are injected by default. Configure via:
```bash
export AIGATEWAY_MIN_SEVERITY=error  # Only surface errors
```

### Code Snippet & Content Redaction

Tool findings may include code snippets in messages. Controls:

| Control | Default | Environment Variable |
|---------|---------|---------------------|
| Path redaction (absolute → relative) | **on** | Always applied |
| Snippet redaction (strip code blocks) | **off** | `AIGATEWAY_REDACT_SNIPPETS=true` |
| Severity gate (minimum level) | warning | `AIGATEWAY_MIN_SEVERITY=error` |

When `AIGATEWAY_REDACT_SNIPPETS=true`, the hook strips indented code blocks
from prompt output. The JSON format always retains full data — redaction only
applies to what enters agent context via hooks.

### Audit Logging

Set `AIGATEWAY_AUDIT_LOG=/path/to/audit.log` to enable logging of every
finding injection. Each entry records timestamp, file, tool, and line count.
This provides an audit trail of what static analysis context was injected
into agent conversations.

### Third-Party Rule Content

Custom semgrep rules in `semgrep-agent-rules.yaml` are project-owned and reviewed.
The `--config auto` flag in analyze.sh also pulls community rules from Semgrep Registry.

**Trust model**:
- Local rules (`semgrep-agent-rules.yaml`): trusted, version-controlled, tested
- Semgrep Registry (`--config auto`): third-party, messages visible to agent
- ast-grep rules: local only, no registry

For sensitive repos, disable auto-config and use only local rules:
```bash
# In analyze.sh, remove: rule_args+=(--config "auto")
```

**Rule message sanitization**: Third-party rule messages are passed through
as-is. They could theoretically contain prompt injection attempts. The
severity gating provides partial mitigation (low-severity third-party rules
are filtered by default). For high-security contexts, disable `--config auto`.

## 6. Known Limitations (PoC)

- **Dedup is coarse-grained**: Uses `file:line` identity key. Two different issues on the same line will be merged. Future: add category to key.
- **LSP not yet in gateway pipeline**: LSP diagnostics flow through a separate Claude Code channel. Phase 2 requires Claude Code to expose diagnostic JSON to hooks. See LSP integration contract above.
- **Semgrep broken on this system**: Python pydantic version conflict. Needs `brew reinstall semgrep`.
- **SARIF output is minimal**: Missing `taxonomies`, `invocations`, and `threadFlowLocations` from full SARIF spec.
- **Benchmark is single-run**: Use `--benchmark` for indicative numbers only. Not suitable for architectural decisions without repeated measurement.

## 7. Phase Gate: Static Analysis (Future)

A new phase gate type for `phase-gates.sh`:

```bash
# Create a static-analysis gate
phase-gates.sh create static-analysis /path/to/worktree

# Gate checks: run analyze.sh, fail if errors > 0
phase-gates.sh check static-analysis /path/to/worktree
```

This would block agent merges until static analysis passes — ensuring code quality
before merge-queue.sh accepts the work.

## 8. Future Directions

### Short-term (Implementable Now)
- [x] Gateway script (`analyze.sh`) with unified output
- [x] Semgrep rules with agent guidance metadata
- [x] ast-grep patterns for structural code search
- [x] PostToolUse hook for real-time feedback
- [ ] Wire hook into `.claude/settings.json` (opt-in)
- [ ] Add `static-analysis` gate type to `phase-gates.sh`
- [ ] Install ast-grep via Brewfile

### Medium-term
- [ ] Semgrep MCP server integration (expose rules as tools)
- [ ] Tree-sitter query library for common refactoring patterns
- [ ] SARIF output for GitHub Code Scanning integration
- [ ] Quality trend tracking (findings over time per project)

### Long-term
- [ ] SonarQube integration for CI/CD quality gates
- [ ] Agent-authored rules (AI discovers and proposes new rules)
- [ ] Cross-project rule sharing via git-backed rule registry
- [ ] LSP code actions exposed as agent tools

## 9. Files Created

| File | Purpose |
|------|---------|
| `scripts/aigateway/analyze.sh` | Main gateway — runs analysis, dedup, formats output (JSON/SARIF/prompt) |
| `scripts/aigateway/semgrep-agent-rules.yaml` | Custom rules with agent_guidance, confidence, version |
| `scripts/aigateway/test-rules.sh` | Rule validation: schema, pattern matching, guidance quality |
| `scripts/aigateway/ast-patterns/sgconfig.yml` | ast-grep configuration |
| `scripts/aigateway/ast-patterns/rules/*.yml` | Structural patterns for Python, TypeScript, Go |
| `.claude/hooks/static-analysis-context.sh` | PostToolUse hook with debounce/TTL/dedup/redaction/audit |
| `docs/aigateway-static-analysis.md` | This document |

## References

- [Semgrep Rules Registry](https://semgrep.dev/r) — 5000+ community rules
- [ast-grep Playground](https://ast-grep.github.io/playground.html) — Interactive pattern testing
- [tree-sitter Queries](https://tree-sitter.github.io/tree-sitter/using-parsers/queries) — Query syntax reference
- [SARIF Spec](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html) — Static Analysis Results Interchange Format
- [SonarQube Web API](https://docs.sonarsource.com/sonarqube-server/latest/extension-guide/web-api/) — REST API docs
- [Claude Code Hooks](../docs/claude-code-hooks.md) — Hook lifecycle reference
