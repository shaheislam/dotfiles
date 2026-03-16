---
name: gap-analysis
description: Analyze external docs/repos via DeepWiki + WebFetch, perform gap analysis against current repo, and produce prioritized value-add recommendations
argument-hint: "<url> [url2...] [--focus topic] [--depth N] [--output file.md] [--no-discover]"
allowed-tools: WebFetch, WebSearch, Read, Write, Glob, Grep, Bash, AskUserQuestion, Agent, mcp__deepwiki__read_wiki_structure, mcp__deepwiki__read_wiki_contents, mcp__deepwiki__ask_question
---

# Gap Analysis Skill

Analyze external resources and compare against the current repo: $ARGUMENTS

## Step 1: Parse Arguments

Extract parameters from the input:

```
URLS = all URL arguments (one or more https://... URLs)
FOCUS = value after --focus flag (optional) — narrow analysis to specific area
DEPTH = value after --depth flag (default: 2, max: 3) — how deep to crawl sublinks
OUTPUT = value after --output flag (optional) — save report to file
NO_DISCOVER = true if --no-discover flag present — skip related source discovery
```

If no valid URL is provided, ask the user for one.

## Step 2: Gather Intelligence from External Resources

For each URL, determine its type and fetch content appropriately.

### GitHub Repository URLs

If the URL matches `https://github.com/{owner}/{repo}[/...]`:

1. **Get wiki structure**: Use `mcp__deepwiki__read_wiki_structure` with `repoName: "{owner}/{repo}"` to discover all documentation topics
2. **Get comprehensive docs**: Use `mcp__deepwiki__read_wiki_contents` with `repoName: "{owner}/{repo}"` for full repository documentation
3. **Ask targeted questions** (use `mcp__deepwiki__ask_question` with `repoName: "{owner}/{repo}"`):
   - "What are all the features, capabilities, and tools this project provides?"
   - "What are the key patterns, abstractions, and design decisions?"
   - If `--focus` was specified: "What does this project offer for {FOCUS}?"
4. **Also WebFetch** the README and any relevant docs/ links for additional context

### Documentation Site URLs

For non-GitHub URLs:

1. **WebFetch** the main page to extract:
   - Features and capabilities described
   - Configuration patterns and options
   - Integration points and APIs
   - Code examples and snippets
2. **Follow sublinks** (up to DEPTH levels):
   - DEPTH 1: up to 5 most relevant sublinks
   - DEPTH 2: up to 3 per page (max 12 total)
   - DEPTH 3: up to 2 per page (max 18 total)
   - Prioritize: setup guides, features lists, API references, integration docs

### For Each Resource, Extract a Feature Inventory

Build a structured list of what the external resource provides:

```
FEATURE_INVENTORY:
  - name: "Feature/capability name"
    description: "What it does"
    category: "Category (e.g., automation, testing, config, security, dx)"
    complexity: "low|medium|high"  # estimated implementation effort
    evidence: "URL or doc section where this was found"
```

## Step 2.5: Discover Related Resources (unless --no-discover)

Automatically find related sources that enrich the analysis. Skip this step if `--no-discover` is set.

### For GitHub Repos

1. **Ask DeepWiki**: Use `mcp__deepwiki__ask_question` with `repoName: "{owner}/{repo}"`:
   - "What other projects, libraries, or tools does this project reference, depend on, or recommend as companions?"
   - "Are there any official plugins, extensions, or ecosystem tools for this project?"
2. **Check repo metadata**: WebFetch the repo's main page to find:
   - "Awesome list" links (often `awesome-{tool}` repos)
   - Links in the README's "See Also", "Related Projects", "Alternatives", or "Ecosystem" sections
   - GitHub topics/tags that lead to similar repos

### For Documentation Sites

1. **WebSearch** for complementary resources:
   - `"{tool name}" best practices site:github.com`
   - `"{tool name}" alternatives comparison`
   - `"{tool name}" awesome list`
2. **Check the fetched pages** for "See Also", "Related", "Integrations", or "Ecosystem" sections

### Present Discoveries

Before proceeding, briefly list the discovered related sources:

```
Related sources found:
  1. [name] — [url] — [why it's relevant]
  2. ...

These will be included in the analysis. Use --no-discover to skip.
```

Fetch the top 3 most relevant discovered sources (using the same GitHub/docs logic from Step 2) and merge their features into FEATURE_INVENTORY. Tag each feature with its source for attribution.

## Step 3: Scan Current Repository

Systematically analyze the current repo to understand what already exists:

1. **Project structure discovery**:
   ```bash
   # Get project overview
   ls -la
   ls .claude/ .config/ scripts/ 2>/dev/null
   ```

2. **Use Glob** to find relevant config files, scripts, and implementations:
   - Search for files matching feature patterns from the inventory
   - Look for similar tool names, config patterns, imports

3. **Use Grep** to search for:
   - Feature names and related keywords from the inventory
   - Tool/library references
   - Configuration patterns that match external resource patterns

4. **Read key files** that appear to be related to the external resource's features

5. **Build a Current State Map**:
   ```
   CURRENT_STATE:
     - feature: "What exists"
       location: "file path(s)"
       completeness: "full|partial|absent"
       notes: "How it differs from the external resource"
   ```

## Step 4: Perform Gap Analysis

Compare FEATURE_INVENTORY against CURRENT_STATE to classify each feature:

### Classification Categories

| Status | Meaning | Icon |
|--------|---------|------|
| **Present** | Fully implemented in current repo | [checkmark] |
| **Partial** | Exists but incomplete or different approach | ~ |
| **Missing** | Not present in current repo | [x] |
| **N/A** | Not applicable to this project | - |

For each feature, determine:
- **Status**: Present / Partial / Missing / N/A
- **Current implementation**: What exists (if any) and where
- **Gap description**: What's missing or different
- **Value-add**: Why adopting this would help (be specific to this repo)

## Step 5: Score and Rank Opportunities

For each Missing or Partial feature, compute a **Value Score**:

```
VALUE_SCORE = IMPACT x FEASIBILITY

IMPACT (1-5):
  5 = Transforms workflow / eliminates major pain point
  4 = Significant improvement to daily workflow
  3 = Useful enhancement, nice-to-have
  2 = Minor improvement
  1 = Marginal benefit

FEASIBILITY (1-5):
  5 = Drop-in, < 30 minutes
  4 = Straightforward, < 2 hours
  3 = Moderate effort, < 1 day
  2 = Significant work, multi-day
  1 = Major undertaking, architectural change

VALUE_SCORE range: 1-25
  20-25: Quick Win / Must Do
  12-19: High Value
  6-11:  Consider
  1-5:   Low Priority / Defer
```

## Step 6: Generate Report

Present the complete gap analysis using this structure:

```markdown
# Gap Analysis: [Resource Name] vs [Current Repo]

**Source(s):** [URLs analyzed]
**Focus:** [FOCUS if specified, otherwise "Full analysis"]
**Date:** [Today's date]

---

## Executive Summary

[2-3 sentences: how many features analyzed, how many gaps found,
top 3 opportunities by value score]

---

## Feature Comparison Matrix

| # | Feature | Status | Value Score | Category |
|---|---------|--------|-------------|----------|
| 1 | Feature name | [checkmark]/~/[x]/- | 20 | category |
| 2 | ... | ... | ... | ... |

**Legend:** [checkmark] Present | ~ Partial | [x] Missing | - N/A

---

## Top Opportunities (Ranked by Value Score)

### 1. [Feature Name] — Score: [N]/25

**Status:** Missing/Partial
**Impact:** [N]/5 — [why this matters for YOUR repo]
**Feasibility:** [N]/5 — [effort estimate and approach]

**What the source does:**
[Brief description from external resource]

**Current state in this repo:**
[What exists now, if anything]

**Recommended implementation:**
[Specific files to create/modify, approach, dependencies]

**Quick start:**
```[language]
[Code snippet or config example to get started]
```

---

### 2. [Next Feature] — Score: [N]/25
[... same structure ...]

---

## Already Present (Validation)

Features from [resource] that this repo already implements:
- [checkmark] **Feature**: [where it lives] — [any differences noted]
- ...

---

## Implementation Roadmap

### Phase 1: Quick Wins (Score 20-25)
| Feature | Files to Change | Est. Effort |
|---------|----------------|-------------|
| ... | ... | ... |

### Phase 2: High Value (Score 12-19)
| Feature | Files to Change | Est. Effort |
|---------|----------------|-------------|
| ... | ... | ... |

### Phase 3: Consider (Score 6-11)
[Listed but not detailed unless --focus matches]

---

## Dependencies & Prerequisites

- [Any new tools, packages, or configurations needed]
- [Brewfile additions, setup.sh changes, etc.]
```

## Step 7: Output and Next Steps

### Default (no --output flag):
Display the report directly in the conversation.

### With --output flag:
Save the report to the specified file path, then confirm:
- File path saved
- Number of features analyzed
- Number of gaps found
- Top 3 quick wins

### Always end with:
Ask the user: "Would you like me to implement any of the top opportunities? You can say:
- `implement #1` — Start implementing the top-ranked opportunity
- `implement quick-wins` — Implement all Phase 1 items
- `deep-dive #N` — Get more detail on a specific opportunity
- `compare [url]` — Add another resource to the analysis"

## Multi-URL Handling

When multiple URLs are provided:
1. Process each URL independently through Steps 2-3
2. Merge feature inventories, deduplicating where features overlap
3. Note which source(s) each feature came from
4. Run a single unified gap analysis in Steps 4-6

## Examples

```
/gap-analysis https://github.com/obra/superpowers
  -> DeepWiki scans the superpowers repo
  -> Compares skill patterns, agents, hooks against current .claude/ setup
  -> Identifies missing skill patterns or agent workflows

/gap-analysis https://github.com/anthropics/claude-code --focus hooks
  -> DeepWiki fetches claude-code docs
  -> Focuses specifically on hook patterns
  -> Compares against .claude/hooks/ in current repo

/gap-analysis https://docs.astral.sh/ruff/ https://docs.astral.sh/uv/
  -> WebFetch both documentation sites
  -> Compares against current linting and package management setup
  -> Unified gap report covering both tools

/gap-analysis https://github.com/jesseduffield/lazygit --focus keybindings --output gaps.md
  -> DeepWiki analyzes lazygit repo
  -> Focuses on keybinding patterns
  -> Saves report to gaps.md

/gap-analysis https://github.com/tmux-plugins/tpm --depth 1
  -> Shallow analysis of TPM repo
  -> Compares against current tmux plugin setup

/gap-analysis https://github.com/charmbracelet/gum --no-discover
  -> DeepWiki analyzes gum repo only (skips related source discovery)
  -> No automatic search for awesome-gum or companion tools
  -> Faster, focused on just the provided URL
```

## Error Handling

- **Invalid URL**: Ask user to provide a valid URL
- **DeepWiki unavailable**: Fall back to WebFetch on GitHub README + docs/
- **Fetch failed**: Try WebSearch as fallback for cached/alternative sources
- **Paywall/login required**: Report limitation, suggest alternative sources
- **Empty feature inventory**: Ask user to provide --focus to narrow scope
- **Very large repos**: Use --focus to constrain analysis, or analyze most-starred/documented features first

Now analyze the resources and perform the gap analysis: $ARGUMENTS
