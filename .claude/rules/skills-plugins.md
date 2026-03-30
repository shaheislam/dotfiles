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

## Plugins (18 total)
Stored in `~/.claude/settings.json`, installation commands in `scripts/setup.sh`.

**Marketplaces**: `anthropics/claude-code`, `kenryu42/cc-marketplace`, `antonbabenko/terraform-skill`, `anthropics/skills`, `obra/superpowers-marketplace`, `steveyegge/beads`, `tanweai/pua`, `boostvolt/claude-code-lsps`, `openai/codex-plugin-cc`

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | PR review with 4 parallel agents |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers |
| **hookify** | `/hookify` | Create hooks via markdown |
| **feature-dev** | `/feature-dev` | 7-phase feature development |
| **ralph-loop** | `/ralph-loop:ralph-loop` | Autonomous iteration loops |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory |
| **pua** | `/pua`, `/pua:p7`, `/pua:loop` | AI debugging persistence (L0-L4 pressure escalation) |
| **codex** | `/codex:review`, `/codex:rescue` | Cross-provider code review and task delegation via Codex |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
