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

### Recommendation

These LSP capabilities would multiply agent effectiveness if exposed:
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
│  │        Normalize → Unified JSON          │       │
│  │   {tool, rule, file, line, severity,     │       │
│  │    message, fix, metadata.agent_guidance} │       │
│  └──────────────┬───────────────────────────┘       │
│                 │                                    │
│     ┌───────────┼───────────┐                       │
│     ▼           ▼           ▼                       │
│  [JSON]     [Prompt]     [SARIF]                    │
│  (API)      (Agent)      (GitHub)                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Hook Integration Points

| Hook Event | Tool | Purpose |
|-----------|------|---------|
| `PostToolUse` (Edit/Write) | shellcheck, ruff | Immediate feedback on edited files |
| `UserPromptSubmit` | semgrep (full) | Pre-task analysis of relevant files |
| `Stop` | ast-grep | Final scan before agent completes |
| `PreCompact` | — | Save analysis state before context compaction |

### Implementation: `.claude/hooks/static-analysis-context.sh`

A PostToolUse hook runs lightweight analysis after each Edit/Write:
- Shell files → shellcheck (fast, ~50ms)
- Python files → ruff (fast, ~30ms)
- Only injects findings when issues are found
- Skips semgrep in real-time (too slow for hooks, ~2-5s)

## 5. Phase Gate: Static Analysis

A new phase gate type for `phase-gates.sh`:

```bash
# Create a static-analysis gate
phase-gates.sh create static-analysis /path/to/worktree

# Gate checks: run analyze.sh, fail if errors > 0
phase-gates.sh check static-analysis /path/to/worktree
```

This would block agent merges until static analysis passes — ensuring code quality
before merge-queue.sh accepts the work.

## 6. Future Directions

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

## 7. Files Created

| File | Purpose |
|------|---------|
| `scripts/aigateway/analyze.sh` | Main gateway script — runs analysis, formats output |
| `scripts/aigateway/semgrep-agent-rules.yaml` | Custom semgrep rules with agent fix guidance |
| `scripts/aigateway/ast-patterns/sgconfig.yml` | ast-grep configuration |
| `scripts/aigateway/ast-patterns/rules/*.yml` | Structural patterns for Python, TypeScript, Go |
| `.claude/hooks/static-analysis-context.sh` | PostToolUse hook for real-time feedback |
| `docs/aigateway-static-analysis.md` | This document |

## References

- [Semgrep Rules Registry](https://semgrep.dev/r) — 5000+ community rules
- [ast-grep Playground](https://ast-grep.github.io/playground.html) — Interactive pattern testing
- [tree-sitter Queries](https://tree-sitter.github.io/tree-sitter/using-parsers/queries) — Query syntax reference
- [SARIF Spec](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html) — Static Analysis Results Interchange Format
- [SonarQube Web API](https://docs.sonarsource.com/sonarqube-server/latest/extension-guide/web-api/) — REST API docs
- [Claude Code Hooks](../docs/claude-code-hooks.md) — Hook lifecycle reference
