---
name: fact-checker
description: Verify factual claims in documents using web search and authoritative sources. Use when fact-checking content, verifying technical specifications, checking version numbers, validating statistics, or auditing documentation accuracy. Triggers on "fact check", "verify claims", "check accuracy", "is this correct", or "audit this document".
argument-hint: "<file-path-or-text> [--strict] [--auto-fix]"
allowed-tools: WebSearch, WebFetch, Read, Edit, Grep, Glob, Bash
---

# Fact Checker

Verify factual claims in documents using web search and authoritative sources.

## Arguments

- `$ARGUMENTS` - Required:
  - File path to check, OR inline text to verify
  - `--strict` - Flag unverifiable claims as errors (default: warnings)
  - `--auto-fix` - Apply corrections after user approval (default: report only)

## Step 1: Extract Factual Claims

Read the target document and identify verifiable statements:

**Check these claim types:**
- Technical specifications (context windows, token limits, API capabilities)
- Version numbers and release dates
- Statistics and numerical data
- API endpoint URLs and parameter names
- Library/tool capabilities and compatibility
- Performance benchmarks and comparisons
- Dates, timelines, and historical facts

**Skip these (subjective/opinion):**
- Comparative adjectives without metrics ("faster", "better")
- Design opinions and preferences
- Future predictions and roadmaps
- Internal team decisions

For each claim, record:
1. The exact text
2. Its location (file:line or paragraph reference)
3. The claim category (spec, version, stat, URL, etc.)

## Step 2: Search Authoritative Sources

For each claim, search in priority order:

| Source Priority | Examples |
|----------------|---------|
| 1. Official product pages | anthropic.com, openai.com, docs.github.com |
| 2. API documentation | Official API refs, SDK docs |
| 3. Official blog posts | Release announcements, changelogs |
| 4. GitHub releases | Release notes, package versions |
| 5. Standards bodies | IETF RFCs, W3C specs, ISO standards |

**Search tips:**
- Include date context: "Claude Opus 4.5 context window 2026"
- Use site-specific searches: "site:docs.anthropic.com context window"
- Cross-reference multiple sources for critical claims

**Do NOT rely on:**
- Third-party blog posts without citations
- Stack Overflow answers (may be outdated)
- AI-generated content from other models
- Wikipedia without checking cited sources

## Step 3: Compare and Classify

Create a comparison table for each claim:

| # | Location | Claim | Status | Source | Correction |
|---|----------|-------|--------|--------|------------|
| 1 | line 45 | "Claude has 200K context" | INCORRECT | docs.anthropic.com | 1M tokens (Opus 4.6) |
| 2 | line 67 | "Released in March 2025" | CORRECT | anthropic.com/news | - |
| 3 | line 89 | "Supports function calling" | OUTDATED | API docs | Now called "tool use" |
| 4 | line 102 | "99.9% uptime SLA" | UNVERIFIABLE | No public SLA found | - |

### Status Codes

- **CORRECT** - Claim matches authoritative source
- **INCORRECT** - Claim contradicts authoritative source
- **OUTDATED** - Was correct but information has changed
- **UNVERIFIABLE** - No authoritative source found
- **IMPRECISE** - Partially correct but missing nuance

## Step 4: Generate Report

```markdown
## Fact Check Report: [filename]
Date: [today]
Claims checked: [N]

### Summary
- CORRECT: X claims
- INCORRECT: X claims (requires fix)
- OUTDATED: X claims (requires update)
- UNVERIFIABLE: X claims (flagged)
- IMPRECISE: X claims (suggested improvement)

### Corrections Needed

#### [Claim 1 - INCORRECT]
- **Location**: file.md:45
- **Current**: "Claude has a 200K token context window"
- **Correct**: "Claude Opus 4.6 has a 1M token context window"
- **Source**: https://docs.anthropic.com/...
- **Impact**: High - misleading technical spec

#### [Claim 2 - OUTDATED]
...

### Unverifiable Claims
[List claims that couldn't be verified, with search attempts noted]
```

## Step 5: Apply Corrections (if --auto-fix)

If `--auto-fix` is specified:

1. Show the full report first
2. Ask for user confirmation: "Apply N corrections? [y/N]"
3. On confirmation, use Edit tool for each correction
4. After edits, show a summary of changes made

If `--auto-fix` is NOT specified:
- Present the report only
- Suggest: "Run with --auto-fix to apply corrections"

## Quality Standards

Before completing:
- [ ] All claims have been checked against at least one authoritative source
- [ ] Sources are current (within last 12 months for fast-moving tech)
- [ ] Corrections include source URLs
- [ ] Numerical precision matches source accuracy
- [ ] Temporal context is noted (e.g., "as of March 2026")
- [ ] User approval obtained before any edits
