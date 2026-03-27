# Claude Code Rules for Dotfiles

> Extends `~/.claude/CLAUDE.md`. Subsystem docs in `.claude/rules/` (loaded on-demand by path).

## Core Rules

### Setup Script Compatibility
- ALWAYS check if `scripts/setup.sh` needs modification when adding new tools
- ALWAYS verify new dependencies are in the Brewfile and setup script
- ALWAYS ensure PATH configs are added to both Fish and Zsh configs

### File Location Constraints
- NEVER create or modify files outside `~/dotfiles` (EXCEPT `~/neovim` for Neovim config)
- ALWAYS ensure tools/configs can be installed via stow or setup script
- CRITICAL: tmux config must ONLY exist at `~/dotfiles/.tmux.conf` — never `.config/tmux/`
- Neovim config lives in `~/neovim` (separate repo, NOT part of dotfiles)

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
| `gwt-ticket` | `gwtt` | Autonomous ticket execution (worktree + ralph-loop). Supports `--codex` for Codex CLI, `--bridge` for iterative Codex→Claude review |
| `gwt-doctor` | `gwtdoc` | Agent orchestration health check (detects Claude + Codex) |
| `codex-accounts` | - | Manage Codex CLI OAuth account profiles (`add`, `remove`, `list`, `status`, `1p-push`, `1p-pull`, `1p-list`, `1p-sync`) |
| `codex-rotate` | - | Codex wrapper with round-robin account rotation + usage-limit failover |
| `pinchtab-ctl` | `ptctl` | PinchTab Chrome orchestrator management (start/stop/status/dashboard/profiles) |

**Subscription Profiles**: `claude-sub` (`csub`). Profile dirs: `~/.claude-<name>/`. Usage: `gwtt --sub personal`, `gwtc --sub work`.

### Devcontainer Auto-Login
Bind-mounts `~/.claude` into containers. Key file: `scripts/devcontainer/export-claude-credentials.sh`. Details in `.claude/rules/worktree-devcontainer.md`.

### Activity Watcher
`scripts/tmux/tmux-claude-watcher.sh` — monitors tmux for idle Claude/Opencode processes.

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
`/todo` creates tickets, `/ticket-execute` runs them, `gwt-ticket` orchestrates worktree + ralph-loop. Queue: `gwt-queue add|list|start|stop|status`. Details in `.claude/rules/ticket-execution.md`.

### Docker Container Testing
Test cross-platform via Colima + Docker. Location: `scripts/docker/`. ALWAYS test cross-platform changes in containers.

### OpenClaw AI Platform
Multi-channel AI inbox. CLI: `openclaw` / `claw`. Config: `scripts/openclaw/openclaw-base.json`. Docs: `docs/openclaw-setup.md`.

### Browser Automation
Four browser tools for AI agents, each with different strengths:
- **PinchTab**: Multi-instance Chrome orchestrator. Fish: `pinchtab-ctl` (`ptctl`). Config: `.config/pinchtab/config.json`. MCP: `pinchtab mcp`.
- **agent-browser**: Single-daemon ref-based CLI. Config: `.agent-browser/config.json`. Skill: `.claude/skills/agent-browser/`.
- **Playwright MCP**: Structured MCP tool calls. Via `bunx @playwright/mcp@latest`.
- **ClaudeCodeBrowser**: Firefox MCP. Fish: `ccb`. Install: `scripts/setup.sh`.

### Peripheral Tools
- **Mobile Coding**: Mosh + Tailscale (`scripts/setup-mobile-coding.sh`)
- **Clawdbot**: WhatsApp/Telegram interface (`npm install -g clawdbot@latest`)
- **DNS**: Cloudflare (1.1.1.1) in `scripts/setup/macos-defaults.sh`
- **Pi-hole**: `scripts/pihole/`, Fish wrapper: `pihole start|stop|dns-on|dns-off|status`
- **Karabiner**: `.config/karabiner/karabiner.json` (Caps Lock ↔ Escape, edit via GUI)
- **K8s Manifests**: ALWAYS in `scripts/manifests/` with README updates

### Claude Code Settings & Security

**Settings Hierarchy** (higher overrides lower): Managed → Local (`.claude/settings.local.json`) → Project (`.claude/settings.json`) → User (`~/.claude/settings.json`)

**CLAUDE.md Hierarchy**: Claude Code walks UP from CWD, loading all `CLAUDE.md` / `.claude/CLAUDE.md` files. Does NOT require a git repo. A shared `~/work/CLAUDE.md` applies to all projects within `~/work/`; deeper files override shallower ones. `@import` supports up to 5 hops. Exclude with `claudeMdExcludes` in settings. Guide: `docs/claudemd-hierarchy.md`. Template: `templates/workspace-CLAUDE.md`.

**Key configs** (`~/.claude.json`):
- Sandbox: `autoAllowBashIfSandboxed: true`, `excludedCommands: ["docker", "colima"]`
- Attribution: `commit: ""`, `pr: ""` (suppress AI trailers)
- Permission rules: deny → ask → allow (first match wins)

**Model**: Opus 4.6 default, `CLAUDE_CODE_EFFORT_LEVEL=max`, `--effort max` CLI flag on all launch commands, `/model opusplan` for plan→execute split.

### Claude Code Hooks
Lifecycle hooks in `.claude/hooks/`. Details in `.claude/rules/hooks.md` and `docs/claude-code-hooks.md`.

**Adding hooks**: Create executable in `.claude/hooks/` → wire in `.claude/settings.json` → add tests → update docs.

**Settings Edit Workaround** ([#37029](https://github.com/anthropics/claude-code/issues/37029)): `--dangerously-skip-permissions` still prompts for edits to `~/.claude/settings*.json`. A PreToolUse hook (`settings-edit-redirect.py`) blocks Edit/Write on these files and redirects to `jq` via Bash. When modifying Claude settings, ALWAYS use Bash + jq instead of Edit.

### Skills, Plugins & Subagents
- **Skills**: 38 in `.claude/skills/`. Guide: `docs/skills-reference.md`. Details in `.claude/rules/skills-plugins.md`. Workflow: `/start` (pick next task) and `/wrap-up` (validate + commit).
- **Plugins**: 15 plugins from 5 marketplaces + 9 LSP plugins. Managed via `claude plugin install|disable|enable|uninstall`. Includes `pua@pua-skills` for AI debugging persistence (L0-L4 pressure escalation).
- **Subagents**: 15 agents in `.claude/agents/` (12 domain + 3 project-specific). Reference: `.claude/AGENTS.md`.

### LSP Integration
9 LSP servers via `boostvolt/claude-code-lsps` (pyright, typescript, gopls, rust-analyzer, bash, yaml, terraform, lua, nix). Reuses Nix devShell binaries. Fish: `cc-lsp status|install|doctor`. Details in `.claude/rules/lsp-nix.md`.

### Neovim-Claude Bridge
Neovim state → `/tmp/nvim-claude-bridge/` → `UserPromptSubmit` hook. Fish: `cc-bridge status|cat|clean`. Docs: `docs/nvim-claude-bridge.md`.

### Remote Control & Agent Teams
- **Remote Control**: `cc-rc start|interactive|status|enable|disable`. Launch commands use `--remote-control` flag for deterministic per-session enablement. Config fallback via `enableRemoteControl` in `~/.claude.json`.
- **Agent Teams**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `teammateMode: "auto"`. Use for same-repo collaboration; use `gwt-parallel` for isolated multi-branch.

### Claude Pipeline & Cross-Provider Bridge
- **Pipeline**: `claude-pipeline` / `cpipe`. Presets: `review`, `cheap`, `local`, `council`, `redteam`. Docs: `docs/claude-pipeline.md`.
- **Cross-Provider Bridge**: `CROSS_PROVIDER_BRIDGE=1 claude`. Providers: Codex, Gemini, Ollama, DeepSeek. Details in `.claude/rules/cross-provider.md`.
- **Codex Bridge Review**: `gwtt --codex --bridge TICKET-123` runs iterative Codex→Claude review loop. Config: `.codex/config.toml`. Script: `scripts/codex-bridge-review.sh`.
- **Codex Account Rotation**: `codex-rotate` wraps codex with round-robin rotation across multiple OAuth accounts. Profiles in `~/.codex/accounts/<name>/auth.json` (machine-local, gitignored). Enroll: `codex-accounts add <name>`. `gwt-ticket --codex` uses `codex-rotate` automatically.
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
- Karabiner-Elements config (use GUI), Brewfile organization, tmux plugin installation (TPM)
- Theme consistency verification, 1Password/SSH setup, stow conflict resolution
- LazyVim plugin config (lives in `~/neovim`)
