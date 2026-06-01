# Claude Code Skills Reference

> Best sources for AI skills, marketplace guide, and migration from commands to skills.

## What Are Skills?

Skills are the primary extension mechanism for Claude Code (and other AI coding agents). A skill is a directory containing a `SKILL.md` file with YAML frontmatter and markdown instructions. Claude loads skill descriptions at startup and activates the full content when relevant or explicitly invoked via `/skill-name`.

As of Claude Code v2.1.3, **slash commands merged into skills**. `.claude/skills/` is the recommended activation format — skills support directories of supporting files, subagent execution (`context: fork`), and the cross-tool Agent Skills standard. In this repo, reusable skill source lives in `skills/`, while `.claude/skills/` is used for project-local skills and materialized manifest entries.

### Skill Locations

| Location | Scope | Purpose |
|----------|-------|---------|
| `skills/<category>/<name>/SKILL.md` | Dotfiles library | Reusable checked-in source for shared/personal/work skill bundles |
| `~/.claude/skills/<name>/SKILL.md` | Personal | Available in all projects |
| `.claude/skills/<name>/SKILL.md` | Project | Project-local or materialized skill for the active repo |
| `<plugin>/skills/<name>/SKILL.md` | Plugin | Installed via marketplace |
| `.claude/commands/<name>.md` | Legacy | Deprecated — migrate to skills format |

### SKILL.md Format

```yaml
---
name: my-skill
description: Brief description loaded at startup (~100 tokens)
argument-hint: "<required> [--optional flag]"
allowed-tools: Read, Write, Edit, Bash, WebFetch
user-invocable: true
---

# Skill Instructions

Full instructions loaded on activation (<5K tokens recommended).
Use $ARGUMENTS for user input, $1/$2 for positional args.
```

## Best Sources (Ranked)

### 1. anthropics/skills (Official)

**URL**: https://github.com/anthropics/skills

The official Anthropic skills repository. High quality, well-tested.

```bash
# Install as marketplace
/plugin marketplace add anthropics/skills
```

**Notable skills**: docx, pdf, pptx, xlsx (document processing), algorithmic-art, canvas-design, frontend-design, mcp-builder, skill-creator.

### 2. obra/superpowers (Community Framework)

**URL**: https://github.com/obra/superpowers

The most mature community skills framework. A complete software development methodology with 20+ battle-tested skills.

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

**Notable skills**: `/brainstorm`, `/write-plan`, `/execute-plan`, code review, parallel agents, git worktrees, skill creation tools.

Related repos:
- [obra/superpowers-lab](https://github.com/obra/superpowers-lab) — experimental skills
- [obra/superpowers-skills](https://github.com/obra/superpowers-skills) — community-editable skills

### 3. VoltAgent/awesome-agent-skills (Curated List)

**URL**: https://github.com/VoltAgent/awesome-agent-skills (7.6k stars)

**380+ skills** from official dev teams and community. Cross-compatible with Claude Code, Codex, Gemini CLI, and Copilot.

Includes skills from: **Vercel** (React, Next.js, React Native), **Cloudflare** (Workers, KV, R2, D1), **Google/Gemini Labs**, **Hugging Face**, **Trail of Bits** (security), **Microsoft** (Azure), **Stripe**, **Sentry**, **Expo**.

### 4. anthropics/claude-plugins-official (Curated Plugins)

**URL**: https://github.com/anthropics/claude-plugins-official

Anthropic's curated directory of high-quality plugins. Each plugin can bundle skills, commands, agents, hooks, and MCP configs.

```bash
/plugin install {name}@claude-plugin-directory
```

### 5. daymade/claude-code-skills (37 Skills)

**URL**: https://github.com/daymade/claude-code-skills

37 production-ready skills: skill-creator, github-ops, pdf-creator, mermaid-tools, ui-designer, ppt-creator, prompt-optimizer, deep-research, iOS-APP-developer, fact-checker, qa-expert, i18n-expert.

```bash
/plugin marketplace add daymade/claude-code-skills
```

### 6. hesreallyhim/awesome-claude-code (Ecosystem List)

**URL**: https://github.com/hesreallyhim/awesome-claude-code (24.5k stars)

Most comprehensive Claude Code ecosystem resource. Covers skills, hooks, slash commands, agent orchestrators, tooling, IDE integrations, usage monitors, orchestrators, config managers.

### 7. travisvn/awesome-claude-skills (Skills-Focused)

**URL**: https://github.com/travisvn/awesome-claude-skills

Focused specifically on skills. Visual directory at https://awesomeclaude.ai/awesome-claude-skills

### 8. Chat2AnyLLM/awesome-claude-plugins (Marketplace Index)

**URL**: https://github.com/Chat2AnyLLM/awesome-claude-plugins

Indexes **43 marketplaces and 834 plugins** with adoption metrics.

## Web-Based Marketplaces

| Marketplace | URL | Description |
|---|---|---|
| **SkillsMP** | https://skillsmp.com | Smart search, category filtering |
| **SkillHub** | https://www.skillhub.club | 7,000+ AI-evaluated skills |
| **ClaudeMarketplaces** | https://claudemarketplaces.com | Plugin marketplace |
| **AwesomeClaude** | https://awesomeclaude.ai/awesome-claude-skills | Visual directory |
| **Claude-Plugins.dev** | https://claude-plugins.dev | Skills and plugin browsing |
| **mcpservers.org** | https://mcpservers.org/claude-skills | Claude Skills Library |

## Agent Skills Open Standard

**URL**: https://agentskills.io/specification

Released December 2025 by Anthropic, adopted by OpenAI for Codex CLI. Skills written to this standard work across:

| Tool | Skill Location |
|------|---------------|
| Claude Code | `.claude/skills/` |
| Codex CLI | `.agents/skills/` |
| Gemini CLI | `.gemini/skills/` |

| GitHub Copilot | `.github/skills/` |
| Windsurf | `.windsurf/skills/` |

**Required fields**: `name` (1-64 chars, lowercase+hyphens), `description` (1-1024 chars).

**Optional fields**: `license`, `compatibility`, `metadata`, `allowed-tools`.

**Optional directories**: `scripts/`, `references/`, `assets/`.

Claude Code extends the standard with: `disable-model-invocation`, `user-invocable`, `model`, `context`, `agent`, `hooks`, `argument-hint`.

## Currently Installed (This Dotfiles)

### Project-Local And Reusable Skills

This repo intentionally has one checked-in canonical skill library and generated harness pickup surfaces:

- `skills/` is the reusable dotfiles library and source of truth.
- `.claude/skills/`, `.agents/skills/`, `.gemini/skills/`, and `.opencode/skills/` are generated symlink surfaces for Claude, Codex, Gemini, and OpenCode.
- `.claude/skill-manifest.toml` declares extra per-repo sources that are materialized alongside the central library.

Use `python3 scripts/validate-skills.py` to validate skills, `scripts/sync-skills-harnesses.sh --check` to detect harness drift, and `scripts/test-skills-profile.sh` to validate profiles, manifests, and Agent Skills metadata.

Core workflows include `start`, `wrap-up`, `ship`, `fix`, `session-review`, `continue-claude-work`, `ticket-execute`, `todo`, `jira`, `security-audit`, `gap-analysis`, `best-practice`, `research-spike`, `prompt-optimizer`, `context-health`, `morning-brief`, `dotfiles-sync`, `fish-reload`, `mcp-restart`, `git-config-fix`, `aws-profile`, `petlab-aws`, `confluence`, `diagram`, `article`, `youtube`, `cv-generate`, `jfdi`, `jfdi-sync`, `jfdi-extract`, `jfdi-recall`, `jfdi-synthesis`, `dream`, `careful`, `freeze`, `unfreeze`, `guard`, `capture-screen`, `cross-ref`, `macos-cleaner`, `claude-cleanup`, `s3-search`, `s3-upload`, `autoplan`, `fact-checker`, `retro`, and `commit-mode`.

Compatibility wrappers cover common external slash-command names that the screenshot expects: `commit`, `review-pr`, `full-review`, `deploy-check`, `build-fix`, `verify`, `handoff`, `ticket`, `checkpoint`, `rebase`, and `audit`.

### Plugin Skills (14 plugins)

code-review, pr-review-toolkit, hookify, feature-dev, frontend-design, plugin-dev, ralph-loop, agent-sdk-dev, explanatory-output-style, learning-output-style, code-simplifier, security-guidance, terraform-skill, beads.

### Plugin Marketplaces Configured

| Marketplace | Alias |
|-------------|-------|
| `anthropics/claude-code` | `claude-code-plugins` |
| `kenryu42/cc-marketplace` | `cc-marketplace` |
| `antonbabenko/terraform-skill` | `antonbabenko` |
| `steveyegge/beads` | `steveyegge` |

## Migration: Commands to Skills (Completed)

The repo's custom command surface has been migrated from `.claude/commands/` to `.claude/skills/`, and compatibility wrappers now preserve common slash-command names used by other Claude setups.

**What changed**: `commands/foo.md` → `skills/foo/SKILL.md`

**Skills advantages over commands**:
- Skills use `SKILL.md` in a directory (not a flat .md file)
- Skills support `context: fork` for subagent execution
- Skills support `scripts/`, `references/`, `assets/` subdirectories
- Skills follow the cross-tool Agent Skills standard

## Security Notes

- Always review `SKILL.md` and scripts before enabling untrusted skills
- Skills execute in the agent's context with access to tools
- The `allowed-tools` field restricts which tools a skill can use
- Community skills may contain prompt injections or unsafe patterns
- Prefer official (anthropics/) and well-starred community sources

## Quick Install Guide

```bash
# Add the top marketplaces
/plugin marketplace add anthropics/skills
/plugin marketplace add obra/superpowers-marketplace
/plugin marketplace add daymade/claude-code-skills

# Install specific skills/plugins
/plugin install superpowers@superpowers-marketplace
/plugin install skill-creator@anthropics/skills

# List what's available
/plugin search <keyword>

# Manage installed plugins
/plugin list
/plugin disable <name>
/plugin enable <name>
/plugin uninstall <name>
```
