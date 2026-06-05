# Skills Library

Canonical skill library for all AI harnesses used by this repo.

## Directory Structure

```
skills/
├── profiles/           # Device/context profile definitions
│   ├── personal.toml   # Personal MacBook skills
│   ├── work.toml       # Work laptop skills
│   └── server.toml     # Headless server skills
├── shared/             # Skills available to all profiles
│   ├── dotfiles-sync/
│   │   └── SKILL.md
│   └── fish-reload/
│       └── SKILL.md
├── personal/           # Personal-device-only skills
│   └── article/
│       └── SKILL.md
└── work/               # Work-device-only skills
    └── jira/
        └── SKILL.md
```

## How It Works

1. **Central library** (`skills/`): The source of truth for checked-in skills.
2. **Harness surfaces**: Generated symlinks let each tool discover the same skill files.
3. **Profiles** (`skills/profiles/*.toml`): Named skill sets for machine-wide personal Claude skills.
4. **Per-repo manifest** (`.claude/skill-manifest.toml`): Extra repo-specific skill sources.

Generated harness surfaces:

| Harness | Generated path | Notes |
|---------|----------------|-------|
| Claude Code | `.claude/skills/` | Native project skills |
| Codex CLI | `.agents/skills/` | Agent Skills standard |
| Gemini CLI | `.gemini/skills/` | Agent Skills standard |
| OpenCode | `.opencode/skills/` | Bridge surface plus `/skill` command |

## Commands

```bash
# Sync central skills into every repo harness surface
scripts/sync-skills-harnesses.sh

# Check harness surfaces for drift
scripts/sync-skills-harnesses.sh --check

# Activate a profile (symlinks into ~/.claude/skills/)
skills-profile activate personal

# List available profiles
skills-profile list

# Show current active profile and skills
skills-profile status

# Health check
skills-profile doctor

# Deactivate all profile skills
skills-profile deactivate
```

## Profile Format (TOML)

```toml
[profile]
name = "personal"
description = "Skills for personal MacBook"

[skills]
# Categories from the skills library to include
include = ["shared", "personal"]

[skills.external]
# External skills to symlink (from other locations)
vercel-react = "~/.agents/skills/vercel-react-best-practices"
```

## Per-Repo Skill Manifest

Repos can declare skill dependencies in `.claude/skill-manifest.toml`:

```toml
[manifest]
description = "Skills needed for this project"

[sources]
# From dotfiles skill library
dotfiles-sync = "dotfiles:shared/dotfiles-sync"
fish-reload = "dotfiles:shared/fish-reload"

# From external path
custom-skill = "path:~/my-skills/custom-skill"
```

Run `skills-manifest sync` inside a repo to materialize central and manifest skills into all harness pickup directories.

## Adding New Skills

1. Create `skills/<category>/<skill-name>/SKILL.md`.
2. Add to relevant profile(s) in `skills/profiles/` if it should be machine-wide.
3. Run `scripts/sync-skills-harnesses.sh` to refresh project harness surfaces.
4. Run `skills-profile activate <profile>` only when updating personal `~/.claude/skills/`.

## AGENTS.md Realignment

Use `agents-md-realign` to refresh hierarchical `AGENTS.md` guidance and local-ignore policy across `~/dotfiles`, `~/neovim`, and `~/work/*` repos:

```bash
scripts/tools/realign-agents-md.sh --dry-run --all
scripts/tools/realign-agents-md.sh --apply --all
```

For deeper repo-specific refactors, invoke the skill with `--agentic`. The skill discovers target repos and uses isolated subagents to propose per-repo `AGENTS.md` changes before the main agent applies reviewed edits.

## Cross-Tool Compatibility

Skills follow the [Agent Skills standard](https://agentskills.io/specification).
They work across Claude Code, Codex CLI, Gemini CLI, and Copilot.
