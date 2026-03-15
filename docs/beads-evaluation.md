# Beads Evaluation: Integration into Dotfiles/AI Setup

**Date**: 2026-02-08
**Status**: Evaluation Complete
**Verdict**: **YES - Worth Integrating** (with caveats)

## What is Beads?

[Beads](https://github.com/steveyegge/beads) is Steve Yegge's git-backed, agent-optimized issue tracker. It stores issues as JSONL in `.beads/` within your repo, creating a DAG (directed acyclic graph) with dependency tracking, auto-ready task detection, and semantic memory decay.

**Key stats**: 15.2k GitHub stars, 892 forks, v0.49.4 (active development), MIT license, 2,037 brew installs in last 30 days.

## How It Works

1. **Install**: `brew install beads` (already in Homebrew core)
2. **Init per-project**: `bd init --quiet` (creates `.beads/` directory)
3. **Claude Code integration**: `bd setup claude` installs SessionStart/PreCompact hooks
4. **Optional plugin**: Install via `claude plugin install beads@steveyegge/beads`
5. **Agent workflow**: `bd prime` injects ~1-2k tokens of context at session start; `bd ready --json` finds unblocked tasks; `bd prime` re-injects context before compaction

## Your Current System vs. Beads

| Aspect | Your Current Setup | Beads |
|--------|-------------------|-------|
| **Issue storage** | External (Linear/Jira) | In-repo (`.beads/issues.jsonl`) |
| **Scope** | Organization-level | Per-repository |
| **Agent memory** | None (fresh each session) | Persistent across sessions |
| **Task dependencies** | None (flat ticket list) | DAG with blocking/related edges |
| **Auto-ready detection** | Manual (pick ticket, execute) | `bd ready` finds unblocked work |
| **Git integration** | Separate from code | Issues branch/merge with code |
| **Collaboration** | Via Linear/Jira UI | Via git (PR-based) |
| **Session context** | CLAUDE.md + hooks | `bd prime` (1-2k tokens) |

## Why It's Worth It

### 1. Solves the "50 First Dates" Problem
Your `ralph-loop` and `gwt-ticket` give agents autonomous execution, but each session starts fresh. Beads gives agents persistent memory of what was done, what's blocked, and what's next. This directly improves `ralph-loop` quality.

### 2. Complements (Doesn't Replace) Your Existing Pipeline
- **Linear/Jira** → High-level tickets, team coordination, sprint planning
- **Beads** → Implementation-level subtasks, agent memory, dependency tracking
- Flow: Linear ticket → `gwt-ticket` → agent uses Beads for sub-task tracking → PR

### 3. Minimal Integration Effort
- One `brew install beads` + Brewfile entry
- `bd setup claude` auto-configures hooks
- Optional: plugin install for slash commands
- No changes to existing `gwt-ticket`/`ralph-loop`/`tex` workflow

### 4. Git-Native = Worktree Compatible
Since `.beads/` is in-repo, it works naturally with your `gwt-dev` worktree isolation. Each worktree gets its own beads state.

### 5. Active Development & Community
15k+ stars, Homebrew core, 49 releases, active maintenance. Not a flash-in-the-pan.

## Caveats

### 1. Context Window Cost
`bd prime` adds ~1-2k tokens per session. With your already substantial CLAUDE.md framework (~30k+ tokens of instructions), monitor context usage. The `--uc` flag and auto-compact help, but watch for pressure.

### 2. Dual Issue Tracking Friction
Teams using Linear/Jira won't see beads issues. Beads is best for **personal/agent-level** sub-task tracking, not team coordination. Keep Linear/Jira as the source of truth for team work.

### 3. Go Dependency
Beads requires `icu4c@78` as a runtime dependency. Already available via Homebrew, but adds to the dependency chain.

### 4. MCP Server Adds Complexity
The optional MCP server (via `beads-mcp` Python package) adds another MCP server to manage parity for (per your MCP Configuration Parity Rule). Consider whether hooks-only (`bd setup claude`) is sufficient vs. the full plugin+MCP approach.

## Recommended Integration Plan

### Phase 1: Install & Brewfile (Minimal)
```bash
# Add to homebrew/Brewfile
brew "beads"
```

### Phase 2: Setup Script Update
Add to `scripts/setup.sh`:
```bash
# Phase: Beads (Agent Memory)
if command -v bd &>/dev/null; then
    echo "Beads CLI available: $(bd version)"
else
    echo "Install beads: brew install beads"
fi
```

### Phase 3: Claude Code Plugin (Optional)
Add to setup.sh plugin installation section:
```bash
claude plugin install beads@steveyegge/beads
```

### Phase 4: Fish Shell Integration (Optional)
Create convenience functions for `bd` workflows.

### Phase 5: gwt-ticket Enhancement (Future)
Modify `gwt-ticket` to auto-run `bd init --quiet` in new worktrees and inject beads context into ralph-loop prompts.

## Decision Matrix

| Factor | Score (1-5) | Notes |
|--------|-------------|-------|
| Usefulness for agent workflows | 5 | Directly solves agent memory problem |
| Integration complexity | 4 | Minimal - brew + hooks |
| Overlap with existing tools | 4 | Complementary, not duplicative |
| Community & maintenance | 5 | 15k stars, active dev, Homebrew core |
| Context window impact | 3 | 1-2k tokens per session |
| Worktree compatibility | 5 | Git-native, works out of the box |
| **Overall** | **4.3/5** | **Strong recommend** |

## Sources

- [Beads GitHub Repository](https://github.com/steveyegge/beads)
- [Beads Installation Guide](https://github.com/steveyegge/beads/blob/main/docs/INSTALLING.md)
- [Claude Code Plugin Docs](https://github.com/steveyegge/beads/blob/main/docs/PLUGIN.md)
- [Claude Code Integration Guide](https://steveyegge.github.io/beads/integrations/claude-code)
- [BetterStack Guide: Beads Issue Tracker for AI Agents](https://betterstack.com/community/guides/ai/beads-issue-tracker-ai-agents/)
- [Steve Yegge: The Beads Revolution (Medium)](https://steve-yegge.medium.com/the-beads-revolution-how-i-built-the-todo-system-that-ai-agents-actually-want-to-use-228a5f9be2a9)
- [Steve Yegge: Introducing Beads (Medium)](https://steve-yegge.medium.com/introducing-beads-a-coding-agent-memory-system-637d7d92514a)
