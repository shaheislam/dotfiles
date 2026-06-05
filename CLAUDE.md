# Claude Code Rules for Dotfiles

> Extends `~/.claude/CLAUDE.md`. Subsystem docs in `.claude/rules/` (loaded on-demand by path).

## Core Rules

### Setup Script Compatibility
- ALWAYS check if `scripts/setup.sh` needs modification when adding new tools
- ALWAYS verify new dependencies are in the Brewfile and setup script
- ALWAYS ensure PATH configs are added to both Fish and Zsh configs

### Fish Shell First
- Fish is the primary shell for this repo and this machine; default to Fish-compatible guidance for shell commands
- Do not suggest `unset` for interactive shell usage; use `set -e VAR` in Fish
- One-off env removal with `env -u VAR command` is still valid and works from Fish
- If Bash/Zsh syntax is required for a command example, label it explicitly instead of presenting it as the default

### File Location Constraints
- NEVER create or modify files outside `~/dotfiles` (EXCEPT `~/neovim` for Neovim config)
- ALWAYS ensure tools/configs can be installed via stow or setup script
- CRITICAL: tmux config must ONLY exist at `~/dotfiles/.tmux.conf` — never `.config/tmux/`
- Neovim config lives in `~/neovim` (separate repo, NOT part of dotfiles)

### Canonical Data Strategy
- Before creating or improving any workflow, config, script, prompt, template, hook, skill, or integration, ask whether the improvement should persist across devices
- If it should persist, implement the durable source of truth in `~/dotfiles` so it travels via git, stow, and setup scripts
- Avoid one-off changes in `~`, third-party repos, local app state, or machine-specific paths unless they are runtime-only or explicitly temporary
- If a runtime repo needs the improvement, generate or sync it from `~/dotfiles` rather than making that repo the source of truth
- Keep user-owned canonical data, reusable templates, and integration scripts in `~/dotfiles`
- Treat third-party repos (for example `~/career-ops`) as disposable runtime engines that are recloned and repopulated from dotfiles
- Prefer env-driven sync/generation into external repos over cross-repo symlinks so workflows remain portable across machines and worktrees

### Symlink Management
- ALWAYS use GNU Stow for all configuration symlinking
- NEVER manually create symlinks or copy config files to home directory
- ALWAYS test stow operations before considering changes complete

## Project Overview

- **Purpose**: Personal macOS dev environment (dotfiles + stow + automated setup)
- **Shell**: Fish (primary), Zsh (secondary with Oh My Zsh)
- **Editor**: Neovim (LazyVim) at `~/neovim`, symlinked to `~/.config/nvim`
- **Terminal**: Ghostty, WezTerm, iTerm2 | **Multiplexer**: tmux with TPM
- **Packages**: Homebrew (`homebrew/Brewfile`) | **LSPs**: Nix-based (`nix/global/`)
- **Theme**: Tokyo Night consistent across all applications

### File Organization
- Application configs → `.config/` subdirectories
- Shell configs → dotfiles root level
- Scripts → `scripts/` directory
- Package management → `homebrew/` directory
- Agent context → `.claude/context/` (theme specs, workflows)
- Convention rules → `.claude/rules/conventions-*.md` (shell style, testing, commits)

### Adding New Tools
- **CLI Tools**: Brewfile → Fish PATH → setup.sh → aliases/functions → Zsh compatibility
- **GUI Apps**: Brewfile cask → setup.sh check → `.config/` subdirectory → Tokyo Night theme
- **Plugins**: Fish=Fisher, tmux=TPM, Neovim=LazyVim (in `~/neovim`)

## Development Standards

- ALWAYS add new packages to `homebrew/Brewfile`
- ALWAYS update `scripts/setup.sh` when adding new tools
- ALWAYS maintain consistent theming (Tokyo Night) across applications
- ALWAYS use Fish shell syntax for primary shell configurations
- ALWAYS include Zsh compatibility for broader system support
- PATH management: add new tool paths to both Fish and setup script

**Core Functions** (`.config/fish/functions/`):
| Function | Alias | Description |
|----------|-------|-------------|
| `gwt-dev` | `gwtd` | Create worktree with isolated devcontainer |
| `gwt-claude` | `gwtc` | Launch Claude Code in worktree's devcontainer |
| `gwt-parallel` | - | Launch multiple worktrees in tmux windows |
| `gwt-status` | `gwts` | Show worktree + devcontainer status table |
| `gwt-cleanup` | `gwtclean` | Remove stale devcontainer instances |
| `gwt-ticket` | `gwtt` | Autonomous ticket execution (worktree + OpenCode + nvim). OpenCode is default; use `--claude` for Claude Code fallback and `--bridge` for adversarial review |
| `gwt-doctor` | `gwtdoc` | Agent orchestration health check (detects Claude + Codex) |
| `codex-accounts` | - | Manage Codex CLI OAuth account profiles (`add`, `remove`, `list`, `status`, `1p-push`, `1p-pull`, `1p-list`, `1p-sync`) |
| `codex-rotate` | - | Codex wrapper with round-robin account rotation + usage-limit failover |

**Subscription Profiles**: `claude-sub` (`csub`). Profile dirs: `~/.claude-<name>/`. Usage: `gwtt --sub personal`, `gwtc --sub work`.

### Devcontainer Auto-Login
Bind-mounts `~/.claude` into containers. Key file: `scripts/devcontainer/export-claude-credentials.sh`. Details in `.claude/rules/worktree-devcontainer.md`.

### Agent Window Status
Tmux window colors are event-driven. Claude wrapper/hooks and OpenCode `tmux-open.sh` set window-scoped `@wname_style`; OpenCode session metadata is exposed through `.config/opencode/plugin/session-env.ts`.

### Agent Orchestration (Gastown Patterns)
Multi-agent lifecycle management. Details in `.claude/rules/agent-orchestration.md`. Core scripts: `agent-state.sh`, `worktree-witness.sh`, `merge-queue.sh`, `agent-triage.sh`, `phase-gates.sh`. Higher-level: convoys, molecules, town-beads, mayor, dashboard.

### Beads Agent Memory
Git-backed memory via `bd` CLI. Hooks: SessionStart (`bd prime`), PreCompact (`bd prime`). Commands: `/beads:ready`, `/beads:create`.

### Checkpoints
Managed by `entire` CLI. Fish alias: `ckpt`. Key commands: `entire enable|status|explain|resume|rewind|doctor`. Per-worktree: `gwt-ticket` runs `entire enable` automatically.

### Living Plan
Per-worktree `.plan.md` — a living document that persists session state across context compactions. Lives at project root (not `.claude/`) to avoid self-edit permission prompts. Initialized by `gwt-ticket` at launch with ticket details and structured sections (Objective, Approach, Progress, Decisions, Next Steps, Metrics). Hooks: `plan-persist.sh` (PreCompact) re-injects plan before compaction; `plan-resume.sh` (SessionStart) loads plan on session start. Update the plan at natural checkpoints during work.

**Success Criteria Validation**: `plan-validate-criteria.sh` reads `## Success Criteria` from plan.md and runs any embedded `bash` code blocks as test oracles. Use `--summary` for one-line output. Criteria without code blocks are tagged `MANUAL`.

### Session Changelog
Per-worktree `.claude/CHANGELOG.md` — append-only progress log complementing plan.md. Plan.md is a mutable snapshot (current state); CHANGELOG.md is immutable history (what happened, when, and why). Initialized by `gwt-ticket`. Entry types: PROGRESS, DECISION, FAILED, METRIC, DISCOVERY. Hooks: `changelog-persist.sh` (PreCompact) injects last 15 entries; `changelog-resume.sh` (SessionStart) shows last 10. Append via `changelog-append.sh <type> "message"` or edit directly. FAILED entries are dead ends — never retry them.

### MCP Server Integration
**CRITICAL**: ALWAYS maintain parity between Claude Desktop (`claude_desktop_config.json`) and CLI (`claude mcp add` in `setup.sh`). Use `bunx` not `npx`, `uvx` for AWS MCPs, `pipx run` for Python MCPs. Details in `.claude/rules/mcp-servers.md`.

### Ticket Execution & Queue
`/todo` creates tickets, `/ticket-execute` runs them, `gwt-ticket` orchestrates worktree + OpenCode + nvim by default. Queue: `gwt-queue add|list|start|stop|status`. Details in `.claude/rules/ticket-execution.md`.

### Docker Container Testing
Test cross-platform via Colima + Docker. Location: `scripts/docker/`. ALWAYS test cross-platform changes in containers.

### OpenClaw AI Platform
Multi-channel AI inbox. CLI: `openclaw` / `claw`. Config: `scripts/openclaw/openclaw-base.json`. Docs: `docs/openclaw-setup.md`.

### Browser Automation
Browser automation uses targeted tools instead of a local browser daemon:
- **Playwright MCP**: Structured MCP tool calls. Via `bunx @playwright/mcp@latest`.
- **ClaudeCodeBrowser**: Firefox MCP. Fish: `ccb`. Install: `scripts/setup.sh`.
- **PinchTab**: Preferred for ref-based persistent-profile browser work when available.

### Peripheral Tools
- **Mobile Coding**: Mosh + Tailscale (`scripts/setup-mobile-coding.sh`)
- **Clawdbot**: WhatsApp/Telegram interface (`npm install -g clawdbot@latest`)
- **DNS**: Cloudflare (1.1.1.1) in `scripts/setup/macos-defaults.sh`
- **Pi-hole**: `scripts/pihole/`, Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

- **K8s Manifests**: ALWAYS in `scripts/manifests/` with README updates

### Claude Code Settings & Security

**Settings Hierarchy** (higher overrides lower): Managed → Local (`.claude/settings.local.json`) → Project (`.claude/settings.json`) → User (`~/.claude/settings.json`)

**CLAUDE.md Hierarchy**: Claude Code walks UP from CWD, loading all `CLAUDE.md` / `.claude/CLAUDE.md` files. Does NOT require a git repo. A shared `~/work/CLAUDE.md` applies to all projects within `~/work/`; deeper files override shallower ones. `@import` supports up to 5 hops. Exclude with `claudeMdExcludes` in settings. Guide: `docs/claudemd-hierarchy.md`. Template: `templates/workspace-CLAUDE.md`.

**Key configs** (`~/.claude.json`):
- Sandbox: `autoAllowBashIfSandboxed: true`, `excludedCommands: ["docker", "colima"]`
- Attribution: `commit: ""`, `pr: ""` (suppress AI trailers)
- Permission rules: deny → ask → allow (first match wins)

**Model**: Opus 4.7 default via project settings (`model: claude-opus-4-7`), `CLAUDE_CODE_EFFORT_LEVEL=max`, `--effort max` CLI flag on launch commands, `/model opusplan` for plan→execute split.
**Fullscreen Stability**: Default `CLAUDE_CODE_NO_FLICKER` to `0` in host shells and devcontainers to avoid redraw issues from inherited environments. Enable fullscreen rendering per session with `/tui fullscreen`, or flip `CLAUDE_CODE_NO_FLICKER=1` only as a temporary troubleshooting override on older Claude Code versions.
  - tmux: keep `set -g mouse on` (already in `.tmux.conf`) so wheel scrolling reaches Claude Code. Fullscreen rendering is not supported inside `tmux -CC` (iTerm2 integration mode), so stick to regular tmux sessions when launching Claude in fullscreen.
  - Native selection: when mouse capture is disruptive (copy-on-select workflows, tmux copy-mode, etc.) combine fullscreen rendering with `CLAUDE_CODE_DISABLE_MOUSE=1` so the terminal keeps native selection.

### Agent Harness Hooks
Lifecycle hooks live in `.claude/hooks/` for Claude Code compatibility and are also reused by OpenCode through `.config/opencode/plugin/harness-compat.ts`. Details in `.claude/rules/hooks.md`, `docs/claude-code-hooks.md`, and `docs/opencode-hook-parity.md`.

**Adding hooks**: Create executable in `.claude/hooks/` → wire Claude in `.claude/settings.json` and OpenCode in `.config/opencode/plugin/harness-compat.ts` when relevant → add tests → update docs.

**Settings Edit Workaround** ([#37029](https://github.com/anthropics/claude-code/issues/37029)): `--dangerously-skip-permissions` still prompts for edits to `~/.claude/settings*.json`. A PreToolUse hook (`settings-edit-redirect.py`) blocks Edit/Write on these files and redirects to `jq` via Bash. When modifying Claude settings, ALWAYS use Bash + jq instead of Edit.

### Skills, Plugins & Subagents
- **Skills**: canonical source in `skills/`, materialized into `.claude/skills/` and other harness surfaces. Guide: `docs/skills-reference.md`. Details in `.claude/rules/skills-plugins.md`. Workflow: `/start` (pick next task) and `/wrap-up` (validate + commit).
- **Plugins**: 18 plugins from 9 marketplaces + 9 LSP plugins. Managed via `claude plugin install|disable|enable|uninstall`. Includes `pua@pua-skills` for AI debugging persistence (L0-L4 pressure escalation) and `codex@openai-codex` for cross-provider code review and task delegation (`/codex:review`, `/codex:rescue`, `/codex:setup`).
- **Subagents**: 15 agents in `.claude/agents/` (12 domain + 3 project-specific). Reference: `.claude/AGENTS.md`.

### LSP Integration
9 LSP servers via `boostvolt/claude-code-lsps` (pyright, typescript, gopls, rust-analyzer, bash, yaml, terraform, lua, nix). Reuses Nix devShell binaries. Fish: `cc-lsp status|install|doctor`. Details in `.claude/rules/lsp-nix.md`.

### Neovim Agent Bridge
Neovim state → `/tmp/nvim-claude-bridge/` → `UserPromptSubmit`-compatible hook. OpenCode consumes it via `harness-compat.ts`; Claude Code consumes it via `.claude/settings.json`. Fish: `cc-bridge status|cat|clean`. Docs: `docs/nvim-claude-bridge.md`.

### Remote Control & Agent Teams
- **Remote Control**: `cc-rc start|interactive|status|enable|disable`. Launch commands use `--remote-control` flag for deterministic per-session enablement. Config fallback via `enableRemoteControl` in `~/.claude.json`.
- **Agent Teams**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `teammateMode: "auto"`. Use for same-repo collaboration; use `gwt-parallel` for isolated multi-branch.

### Claude Pipeline & Cross-Provider Bridge
- **Pipeline**: `claude-pipeline` / `cpipe`. Presets: `review`, `cheap`, `local`, `council`, `redteam`. Docs: `docs/claude-pipeline.md`.
- **Cross-Provider Bridge**: `CROSS_PROVIDER_BRIDGE=1 claude`. Providers: Codex, Gemini, Ollama, DeepSeek. Details in `.claude/rules/cross-provider.md`.
- **OpenCode Bridge Review**: `gwtt --bridge TICKET-123` runs OpenCode with an OpenCode sidecar reviewer model by default. OpenAI executors review with Anthropic; Anthropic executors review with OpenAI. Concerns are injected back into OpenCode context through `.config/opencode/plugin/harness-compat.ts`; use `--bridge-mode redteam` for hostile review or `--bridge-providers` for external harnesses.
- **Codex Account Rotation**: `codex-rotate` wraps codex with round-robin rotation across multiple OAuth accounts. Profiles in `~/.codex/accounts/<name>/auth.json` (machine-local, gitignored). Enroll: `codex-accounts add <name>`. OpenCode bridge review can use Codex as an adversarial reviewer.
- **Codex 1Password Sync**: `codex-accounts 1p-push|1p-pull|1p-list|1p-sync [--vault VAULT] [--force]`. Stores auth tokens as 1Password Secure Notes (tag: `codex-account`, vault: `Private`). Conflict detection via `.1p-meta` (content hash + remote timestamp). `1p-sync` is local-first: pushes local, pulls remote-only.
- **DQS**: Council (`cpipe --preset council`), Red Team, First Principles. Docs: `docs/decision-quality-system.md`.

### OpenTelemetry Observability
OTEL LGTM stack (`grafana/otel-lgtm`) — single container with OTEL Collector, Prometheus, Loki, Tempo, Pyroscope, and Grafana. Claude Code sends native telemetry (costs, tokens, tool durations, cache rates) via OTLP HTTP. Fish: `otel start|stop|status|open|doctor`. Config: `scripts/otel/`. Dashboard: `scripts/otel/grafana/dashboards/claude-code.json`. Details in `.claude/rules/otel-observability.md`.

### Self-Hosted LLM
Ollama + Open WebUI. Setup: `scripts/setup-selfhost-llm.sh`. Fish: `llm`, `llm-code`, `llm-chat`, `llm-status`.

### Documentation Merge Driver
Union merge for CLAUDE.md/AGENTS.md via `scripts/merge-driver-union.sh`. Prevents worktree merge conflicts.

## Quality Assurance

### Before Committing
- Verify setup script works, stow completes, theme consistency maintained
- Validate Fish and Zsh configurations work correctly

### Troubleshooting
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Stow Conflicts**: Resolve symlink conflicts before deployment

## Agent Workflow Guidance

- Practical agent rules in root `AGENTS.md`
- **Slam dunks**: `gwt-ticket` or `ralph-loop` for well-defined tasks
- **Single Agent Rule**: One background agent at a time

### When NOT to Use Agents
- Brewfile organization, tmux plugin installation (TPM)
- Theme consistency verification, 1Password/SSH setup, stow conflict resolution
- LazyVim plugin config (lives in `~/neovim`)


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
