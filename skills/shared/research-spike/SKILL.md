---
name: research-spike
description: Conduct structured AI-driven research spikes for tool evaluations, migration assessments, and technology decisions. Gathers evidence, analyzes trade-offs, and produces actionable recommendations.
argument-hint: "<question-or-tool> [--migrate-from current] [--migrate-to target] [--output file.md] [--depth quick|standard|deep]"
allowed-tools: WebFetch, WebSearch, Read, Glob, Grep, Bash, Agent, mcp__deepwiki__read_wiki_structure, mcp__deepwiki__read_wiki_contents, mcp__deepwiki__ask_question
---

# Research Spike Skill

Conduct a structured research spike: $ARGUMENTS

## Step 1: Parse Arguments

Extract parameters:

```
QUESTION = the research question or tool name (required)
MIGRATE_FROM = current tool (optional, for migration spikes)
MIGRATE_TO = target tool (optional, for migration spikes)
OUTPUT = file path to save report (optional)
DEPTH = quick|standard|deep (default: standard)
```

**Spike types** (auto-detected from arguments):
- **Tool evaluation**: Single tool name provided (e.g., `research-spike zellij`)
- **Migration assessment**: Both `--migrate-from` and `--migrate-to` provided
- **Open question**: A question string provided (e.g., `"should we switch from tmux to zellij?"`)

## Step 2: Gather Evidence

### For Tool Evaluations

1. **Identify the tool's GitHub repo**: WebSearch `"{TOOL}" site:github.com`
2. **Get comprehensive docs**: Use `mcp__deepwiki__read_wiki_contents` with `repoName`
3. **Ask targeted questions** via `mcp__deepwiki__ask_question`:
   - "What are the main features and capabilities?"
   - "What are the known limitations or issues?"
   - "How does this compare to alternatives?"
   - "What is the installation and configuration process?"
4. **Check community health**: WebFetch the GitHub repo page for stars, recent activity, open issues
5. **Check current repo**: Grep for any existing references to this tool

### For Migration Assessments

1. Gather evidence for BOTH tools (as above)
2. **Map current usage**: Run `dep-trace --json {MIGRATE_FROM}` to understand current footprint
3. **Check migration guides**: WebSearch `"migrate from {MIGRATE_FROM} to {MIGRATE_TO}"`
4. **Identify breaking changes**: What current workflows would break?

### For Open Questions

1. **Extract tool/topic names** from the question
2. **WebSearch** for relevant comparisons, benchmarks, and discussions
3. **Gather data** for each tool mentioned using DeepWiki

### Depth Control

| Depth | Evidence Sources | Time Budget |
|-------|-----------------|-------------|
| quick | 1 DeepWiki + 1 WebSearch per tool | ~2 min |
| standard | DeepWiki + 3 WebSearches + dep-trace | ~5 min |
| deep | DeepWiki + 5 WebSearches + dep-trace + sublinks | ~10 min |

## Step 3: Analyze Against Current Setup

1. **Read relevant config files**: Based on the tool category, read existing configs
2. **Check Brewfile**: Is the current tool in the Brewfile? Would the new one be?
3. **Check Fish/Zsh**: Are there shell functions, aliases, or PATH entries affected?
4. **Check setup.sh**: Would the setup script need changes?
5. **Check theme compatibility**: Does the new tool support Tokyo Night?

## Step 4: Produce Recommendation

Generate a structured report:

```markdown
# Research Spike: {QUESTION}

**Date:** {today}
**Type:** Tool Evaluation | Migration Assessment | Open Question
**Depth:** {DEPTH}

## Summary

[2-3 sentence executive summary with clear recommendation]

## Evidence Gathered

| Source | Key Finding |
|--------|-------------|
| DeepWiki | ... |
| GitHub | ... |
| Community | ... |

## Current State

[What exists in this repo today — files, configs, dependencies]

## Assessment

### Pros
- [Evidence-backed advantages]

### Cons
- [Evidence-backed disadvantages]

### Risks
- [What could go wrong, with likelihood]

## Recommendation

**Verdict:** Adopt / Evaluate Further / Skip / Defer
**Confidence:** High / Medium / Low
**Effort Estimate:** {hours or days}

### If Adopting

**Files to change:**
| File | Change | Effort |
|------|--------|--------|
| ... | ... | ... |

**Brewfile additions/removals:**
```
brew "new-tool"
# Remove: brew "old-tool"
```

**Setup script changes:**
[Specific lines to add/modify]

**Migration steps:**
1. [Ordered steps]
2. ...

## Open Questions

- [Things that couldn't be resolved from available evidence]
```

## Step 5: Output

### Default (no --output flag):
Display the report in the conversation.

### With --output flag:
Save to the specified file path and confirm.

### Always end with:
"Would you like me to:
- `implement` — Start implementing the recommendation
- `deep-dive <topic>` — Research a specific aspect further
- `compare <alt-tool>` — Add another tool to the comparison"

## Examples

```
/research-spike zellij
  -> Evaluates zellij as a terminal multiplexer
  -> Compares against current tmux setup
  -> Produces adoption recommendation

/research-spike --migrate-from tmux --migrate-to zellij
  -> Full migration assessment
  -> Maps current tmux usage via dep-trace
  -> Produces migration plan with file changes

/research-spike "should we add atuin for shell history?"
  -> Open question research
  -> Checks atuin features, community health
  -> Analyzes against current Fish history setup

/research-spike starship --depth quick
  -> Quick evaluation of starship prompt
  -> Minimal evidence gathering
  -> Brief recommendation
```

## Error Handling

- **Tool not found on GitHub**: Try WebSearch with broader terms, check if it's a non-GitHub project
- **DeepWiki unavailable**: Fall back to WebFetch on README
- **dep-trace not available**: Fall back to manual grep searches
- **Ambiguous question**: Ask user to clarify the specific decision they're facing
