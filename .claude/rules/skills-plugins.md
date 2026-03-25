---
paths:
  - ".claude/skills/**"
  - ".claude/plugins/**"
  - ".claude/settings.json"
---

# Skills & Plugins

## Skills
All custom commands migrated to `.claude/skills/` (24 skills). See `docs/skills-reference.md`.

**Key locations**: Personal `~/.claude/skills/`, Project `.claude/skills/`
**Cross-tool standard**: [agentskills.io](https://agentskills.io/specification)

## Plugins (14 total)
Stored in `~/.claude/settings.json`, installation commands in `scripts/setup.sh`.

**Marketplaces**: `anthropics/claude-code`, `kenryu42/cc-marketplace`, `antonbabenko/terraform-skill`, `steveyegge/beads`

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | PR review with 4 parallel agents |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers |
| **hookify** | `/hookify` | Create hooks via markdown |
| **feature-dev** | `/feature-dev` | 7-phase feature development |
| **ralph-loop** | `/ralph-loop:ralph-loop` | Autonomous iteration loops |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
