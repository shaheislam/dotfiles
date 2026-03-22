# Skills Library

Curated skill library with device and repo-specific profiles.

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

1. **Skill Library** (`skills/`): All available skills organized by category
2. **Profiles** (`skills/profiles/*.toml`): Named skill sets for different contexts
3. **Activation**: `skills-profile activate <name>` symlinks skills into `~/.claude/skills/`
4. **Per-Repo**: `.claude/skill-manifest.toml` declares repo-specific skill sources

## Commands

```bash
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

Run `skills-manifest sync` inside a repo to materialize these into `.claude/skills/`.

## Adding New Skills

1. Create `skills/<category>/<skill-name>/SKILL.md`
2. Add to relevant profile(s) in `skills/profiles/`
3. Run `skills-profile activate <profile>` to refresh

## Cross-Tool Compatibility

Skills follow the [Agent Skills standard](https://agentskills.io/specification).
They work across Claude Code, Codex CLI, Gemini CLI, and Copilot.
