---
paths:
  - ".claude/skills/**"
  - ".claude/plugins/**"
  - ".claude/settings.json"
---

# Skills & Plugins

## Skills
The repo uses `skills/` (`shared/`, `personal/`, `work/`) as the canonical skill library. Harness pickup directories are generated symlink surfaces: `.claude/skills/` for Claude, `.agents/skills/` for Codex, `.gemini/skills/` for Gemini, and `.opencode/skills/` for OpenCode. See `docs/skills-reference.md`.

**Key locations**: Canonical library `skills/`, generated harness surfaces `.claude/skills/`, `.agents/skills/`, `.gemini/skills/`, `.opencode/skills/`, personal `~/.claude/skills/`
**Cross-tool standard**: [agentskills.io](https://agentskills.io/specification)

**Validation**:
- `python3 scripts/validate-skills.py` validates both `.claude/skills/` and the reusable `skills/` library.
- `scripts/sync-skills-harnesses.sh --check` validates that harness surfaces point back to the central library.
- `scripts/test-skills-profile.sh` validates profiles, manifests, and Agent Skills metadata across `skills/`.

## Slash Commands
Canonical source: `.claude/commands/*.md`. OpenCode and other harnesses get symlinks via `scripts/sync-agent-commands-personal.sh` — single edit propagates everywhere.

**Targets**: `.config/opencode/command/` (extend `TARGETS` array in the sync script to add Codex/Pi/Gemini when their command surfaces exist).

**Validation**:
- `scripts/sync-agent-commands-personal.sh` applies sync (idempotent).
- `scripts/sync-agent-commands-personal.sh --check` reports drift; wired into `scripts/test-filter.sh opencode`.

**Authoring**: write the command in `.claude/commands/<name>.md` with `description:` frontmatter (Claude ignores it; OpenCode requires it). Run the sync script. Harness-specific overrides allowed — if a real file (not a symlink) exists at the target, the sync skips it.

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
