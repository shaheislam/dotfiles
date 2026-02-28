---
name: best-practice
description: Inspect a link and sublinks for best practices, then suggest integration into the current repo
argument-hint: "<url> [--depth N] [--focus topic]"
allowed-tools: WebFetch, WebSearch, Read, Glob, Grep, Bash, AskUserQuestion, Agent
---

# Best Practice Research & Integration

Research best practices from: $ARGUMENTS

## Step 1: Parse Arguments

Extract parameters from the input:

```
URL = first argument (the https://... URL)
DEPTH = value after --depth flag (default: 1, max: 3) — how many levels of sublinks to follow
FOCUS = value after --focus flag (optional) — narrow research to specific topic
```

If no valid URL is provided, ask the user for one.

## Step 2: Detect URL Type & Fetch Primary Content

First, determine the URL type:

### GitHub Repository Detection

If the URL matches a GitHub repo pattern (`https://github.com/{owner}/{repo}[/...]`), extract the `owner/repo` and use **DeepWiki** for superior AI-powered documentation:

1. **Get wiki structure**: Use `read_wiki_structure` with `repoName: "{owner}/{repo}"` to discover documentation topics
2. **Get full documentation**: Use `read_wiki_contents` with `repoName: "{owner}/{repo}"` for comprehensive repo docs
3. **Ask targeted questions**: If `--focus` was specified, use `ask_question` with `repoName: "{owner}/{repo}"` and a question like:
   - "What are the best practices for {FOCUS} in this project?"
   - "How should I configure and integrate {FOCUS}?"
   - "What are the recommended patterns for {FOCUS}?"
4. **Ask integration question**: Use `ask_question` to ask: "What are the key configuration patterns, setup steps, and integration best practices for this project?"

**Also use WebFetch** on the GitHub README and any docs/ directory links for additional context that DeepWiki might not cover.

### Standard URL (Non-GitHub)

For non-GitHub URLs, use WebFetch to retrieve the main page with this prompt:

> Extract the following from this page:
> 1. **Title**: The page title
> 2. **Summary**: A 2-3 sentence overview of what this page covers
> 3. **Key Concepts**: List of main best practices, patterns, or techniques described
> 4. **Sublinks**: List of internal links that contain related best practice content (URLs only, max 10 most relevant)
> 5. **Technologies/Tools**: Any specific tools, libraries, or frameworks mentioned
> 6. **Code Examples**: Any code snippets or configuration examples shown
>
> Format your response clearly with labeled sections.

## Step 3: Follow Sublinks

If DEPTH >= 1, fetch the most relevant sublinks identified in Step 2.

**Prioritize sublinks that**:
- Contain setup/installation/configuration guides
- Describe implementation patterns or architecture
- Provide code examples or templates
- Cover integration with tools already in the project

For each sublink, use WebFetch with this prompt:

> Extract best practices, code examples, configuration patterns, and integration guidance from this page.
> Focus on actionable items that a developer could implement.
> Include any CLI commands, config file snippets, or code examples.

**Limits**:
- DEPTH 1: Follow up to 5 sublinks
- DEPTH 2: Follow up to 3 sublinks per page (max 10 total)
- DEPTH 3: Follow up to 2 sublinks per page (max 15 total)

## Step 4: Analyze Current Repository

Understand the current project to contextualize the findings:

1. **Detect project type**:
   ```bash
   # Check for common project markers
   ls package.json pyproject.toml Cargo.toml go.mod Makefile Brewfile flake.nix .claude/ 2>/dev/null
   ```

2. **Identify existing patterns**: Use Glob and Grep to find related configurations, tools, or patterns already in the repo that relate to the fetched content.

3. **Check for conflicts**: Look for existing implementations that might conflict with or duplicate the best practices found.

4. **Map integration points**: Identify specific files and directories where changes would be needed.

## Step 5: Synthesize Findings

Compile all research into a structured report:

### Research Summary

Present the findings in this format:

```
## Best Practices Found

### [Topic/Pattern Name]
**Source**: [URL]
**Summary**: [1-2 sentence description]
**Key Takeaway**: [The most important actionable point]

#### Implementation Details
- [Specific steps or code examples]
- [Configuration patterns]
- [CLI commands]

#### Relevance to This Repo
- [How it applies to the current project]
- [Which files/areas it would affect]
- [Priority: High/Medium/Low]
```

## Step 6: Generate Integration Plan

Based on the analysis, produce a concrete integration plan:

### Integration Plan Format

```
## Integration Plan: [Title from source]

### Quick Wins (can apply immediately)
1. [Change] — [file path] — [what to do]
2. ...

### Moderate Changes (require some refactoring)
1. [Change] — [affected files] — [approach]
2. ...

### Larger Initiatives (significant effort)
1. [Change] — [scope] — [recommendation]
2. ...

### Files to Create/Modify
| File | Action | Description |
|------|--------|-------------|
| path/to/file | Create/Modify | What changes |

### Dependencies/Prerequisites
- [Any new tools, packages, or configurations needed]
- [Brewfile additions, setup.sh changes, etc.]

### Risks & Considerations
- [Potential breaking changes]
- [Compatibility concerns]
- [Migration steps if applicable]
```

## Step 7: Present Results

Present the complete report to the user with:
1. **Research Summary** — what was found across all pages
2. **Integration Plan** — concrete steps to apply the best practices
3. **Recommendation** — which items to prioritize and why

If `--focus` was specified, filter all output to only include findings related to that topic.

## Examples

```
/best-practice https://github.com/anthropics/claude-code
→ Uses DeepWiki to get AI-curated documentation
→ Asks about best practices for configuration, hooks, skills
→ Maps findings to current .claude/ setup and suggests improvements

/best-practice https://github.com/obra/superpowers --focus skills
→ Uses DeepWiki to understand the superpowers skill framework
→ Focuses specifically on skill authoring best practices
→ Suggests how to improve existing skills in this repo

/best-practice https://docs.astral.sh/ruff/configuration/
→ Uses WebFetch on standard docs site
→ Researches Ruff linting best practices
→ Suggests pyproject.toml config, pre-commit hooks, CI integration

/best-practice https://fish-shell.com/docs/current/ --focus completions
→ Deep-dives into Fish shell completion best practices
→ Checks existing Fish functions in .config/fish/
→ Suggests completion improvements

/best-practice https://github.com/junegunn/fzf --depth 2 --focus shell-integration
→ Uses DeepWiki for FZF repo docs + WebFetch for sublinks
→ Focuses on shell integration patterns
→ Checks current FZF config and suggests improvements

/best-practice https://stow.gnu.org/manual/ --focus symlinks --depth 1
→ Researches GNU Stow best practices via WebFetch
→ Checks current stow usage in dotfiles
→ Suggests improvements to symlink management
```

## Error Handling

- **Invalid URL**: Ask user to provide a valid URL
- **Fetch failed**: Try WebSearch as fallback to find cached/alternative versions
- **Paywall/login required**: Report limitation, suggest alternative sources via WebSearch
- **No relevant sublinks found**: Report findings from main page only
- **Large page**: Summarize key points, offer to deep-dive into specific sections

Now research the best practices from: $ARGUMENTS
