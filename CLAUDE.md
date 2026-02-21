# Claude Code Rules for Dotfiles

> **Note**: This file extends the global DevOps rules in `~/.claude/CLAUDE.md`. Read both files for complete context.
> For detailed reference docs on specific features, see `docs/` directory.

## Core Development Principles

### 1. Setup Script Compatibility
- **ALWAYS** check if `scripts/setup.sh` requires modification when adding new tools, packages, or configurations
- **ALWAYS** verify new dependencies are included in the Brewfile and setup script
- **ALWAYS** test setup script changes for compatibility with fresh macOS installations
- **ALWAYS** ensure PATH configurations are added to both Fish and Zsh configs in setup script

### 2. File Location Constraints
- **NEVER** create or modify files outside of `~/dotfiles` directory (EXCEPT `~/neovim` for Neovim config)
- **ALWAYS** keep all configurations within the dotfiles repository structure
- **ALWAYS** use relative paths within the dotfiles directory structure
- **ALWAYS** ensure all tools and configs can be installed via stow or setup script
- **CRITICAL**: The tmux configuration must ONLY exist at `~/dotfiles/.tmux.conf` - NEVER create tmux.conf in `.config/tmux/` or any other location to avoid conflicts
- **EXCEPTION**: Neovim configuration lives in `~/neovim` (separate repository) and is NOT part of dotfiles

### 3. Symlink Management
- **ALWAYS** use GNU Stow for all configuration file symlinking
- **NEVER** manually create symlinks or copy configuration files to home directory
- **ALWAYS** ensure new configurations are stow-compatible (proper directory structure)
- **ALWAYS** test stow operations before considering changes complete
- **CRITICAL**: All dotfiles must be symlinked from `~/dotfiles` to home directory via `stow` command

## Project Overview

- **Purpose**: Personal macOS development environment configuration
- **Structure**: Modular dotfiles with stow-based symlinking and automated setup
- **Key Tools**: Fish shell (primary), Zsh (secondary), Neovim (LazyVim), tmux, Homebrew
- **Theme**: Tokyo Night consistent across all applications

### Architecture
- **Package Management**: Homebrew with centralized Brewfile (`homebrew/`)
- **Shell**: Fish as primary, Zsh as secondary with Oh My Zsh
- **Editor**: Neovim at `~/neovim` (separate repo, symlinked to `~/.config/nvim`)
- **LSP Management**: Nix-based global LSPs via `nix/global/` (see `nix/README.md`)
- **Terminal**: Ghostty, WezTerm, iTerm2
- **Multiplexer**: tmux with extensive plugin system
- **Configs**: `.config/` subdirectories, shell configs at root, scripts in `scripts/`

### Neovim
- **Location**: `~/neovim` (separate Git repository, NOT part of dotfiles)
- **Symlink**: `~/.config/nvim` → `~/neovim` (manual, not managed by stow)
- **LSP Config**: `~/neovim/lua/plugins/lsp.lua`
- **Setup**: `NVIM_REPO=git@github.com:user/neovim.git ./scripts/setup.sh` or see `docs/neovim-setup.md`

### LSP Management
- **ALWAYS** refer to `nix/README.md` for LSP architecture and inheritance patterns
- **ALWAYS** use Nix flakes for project-specific LSP versions (not Mason.nvim)
- **ALWAYS** test LSP inheritance with `scripts/test-lsp-inheritance.sh`
- **CRITICAL**: Three-tier system: Global baseline → Project override → Neovim detection
- See `nix/README.md`, `nix/TESTING.md`, `nix/QUICK_START.md` for details

## Development Standards

### Configuration Management
- **ALWAYS** add new packages to `homebrew/Brewfile`
- **ALWAYS** update `scripts/setup.sh` when adding new tools
- **ALWAYS** maintain consistent theming (Tokyo Night) across applications
- **ALWAYS** use Fish shell syntax for primary shell configurations
- **ALWAYS** include Zsh compatibility for broader system support

### Tool Integration Patterns
- **PATH Management**: Add new tool paths to both Fish and setup script
- **Plugin Management**: Fisher for Fish, TPM for tmux, LazyVim for Neovim
- **Font Requirements**: Ensure Nerd Fonts are available for icon support
- **Theme Consistency**: Apply Tokyo Night theme to all applicable tools

### File Organization
- Application configs → `.config/` subdirectories
- Shell configs → dotfiles root level
- Scripts → `scripts/` directory
- Package management → `homebrew/` directory

### Adding New Tools
**CLI Tools**: Brewfile → Fish PATH → setup.sh → aliases/functions → Zsh compatibility
**GUI Apps**: Brewfile cask → setup.sh check → `.config/` subdirectory → Tokyo Night theme
**Plugins**: Fish=Fisher, tmux=TPM, Neovim=LazyVim (in `~/neovim`)

## Key Subsystems

### Worktree + Devcontainer Integration
Isolated parallel dev environments: worktree name = devcontainer instance name → automatic volume isolation.

**Core Functions** (`.config/fish/functions/`):
| Function | Alias | Description |
|----------|-------|-------------|
| `gwt-dev` | `gwtd` | Create worktree with isolated devcontainer |
| `gwt-claude` | `gwtc` | Launch Claude Code in worktree's devcontainer |
| `gwt-parallel` | - | Launch multiple worktrees in tmux windows |
| `gwt-status` | `gwts` | Show worktree + devcontainer status table |
| `gwt-cleanup` | `gwtclean` | Remove stale devcontainer instances |
| `gwt-ticket` | - | Autonomous ticket execution (worktree + ralph-loop) |
| `gwt-doctor` | `gwtdoc` | Agent orchestration health check |

Setup scripts run automatically: `.devcontainer/setup.sh` or `scripts/setup-worktree.sh`

**Subscription Profiles**: Multiple Claude Max subscriptions via `claude-sub` (`csub`). Profile dirs: `~/.claude-<name>/`. Usage: `gwtt --sub personal`, `gwtc --sub work`.

### Claude Code Devcontainer Auto-Login
Auto-authenticates Claude Code inside devcontainers by bind-mounting the host's `~/.claude` directory directly.
All containers share the same config directory — credentials, plugins, settings, and hooks are all available. When any container refreshes OAuth tokens, all others see the update immediately.
- **Key File**: `scripts/devcontainer/export-claude-credentials.sh` (exports Keychain to `~/.claude`, idempotent, `--force` to overwrite)
- **Mount**: `~/.claude` (bind-mounted to `/home/node/.claude` in containers)
- **Test**: `scripts/devcontainer/test-claude-autologin.sh`

### Claude & Opencode Activity Watcher
Background daemon monitoring tmux windows for idle processes: `scripts/tmux/tmux-claude-watcher.sh`
- ● = Claude idle, ◆ = Opencode idle, ●◆ = Both idle
- ⚠ = Ralph-loop stuck (iteration unchanged for >10min, GUPP violation detection)

### Agent Orchestration (Gastown Patterns)
Multi-agent lifecycle management. Scripts in `scripts/`, each supports `--help`.

**Core Scripts**: `agent-state.sh` (derive state from ground truth, ZFC pattern), `worktree-witness.sh` (lifecycle monitor, auto-spawned by gwt-ticket), `merge-queue.sh` (serialized merges), `agent-triage.sh` (intelligent restart: START/WAKE/NUDGE/NOTHING), `phase-gates.sh` (pause on external conditions).

**Agent States**: `running` | `idle` | `stuck` | `completed` | `dead` | `none`

**Workflow Templates** (`templates/workflows/*.toml`): `implement`, `bugfix`, `refactor`, `test` — used via `gwt-ticket --template`.

**Higher-Level Orchestration**:
- **Convoys** (`convoy.sh`): Batch work tracking, group related tickets. JSONL at `~/.claude/convoys.jsonl`.
- **Molecules** (`molecule.sh`): Durable multi-step workflows with checkpoints and resume.
- **Town Beads** (`town-beads.sh`): Cross-project memory sync. **On by default** in gwt-ticket (`--no-town` to disable).
- **Mayor** (`gwt-mayor.sh`): Global coordinator daemon, LaunchAgent at `com.dotfiles.gwt-mayor.plist`.
- **Dashboard** (`agent-dashboard.sh`): Web dashboard at `http://127.0.0.1:8787`.

**gwt-ticket orchestration flags**: `--convoy NAME|ID`, `--plan NAME [specs]`, `--molecule [id]`, `--town` (default on), `--no-town`, `--mayor`, `--no-mayor`.

**Plan Orchestration** (`gwtt --plan`): Spawn multiple gwtt runs as a convoy. Sources: inline specs, `--file tasks.md`, or `--decompose "goal"`. Options: `--stagger N`, `--dry-run`. Resume: `gwtt-plan resume <name>`. Queue: `gwt-queue add-plan <name> --file tasks.md`.

### Beads Agent Memory
Git-backed agent memory that persists across sessions. Auto-initialized in worktrees by `gwt-ticket`.
- **CLI**: `bd` (installed via Homebrew)
- **Hooks**: SessionStart (`bd prime`), PreCompact (`bd sync`) — no-ops if project has no `.beads/`
- **Per-worktree**: `gwt-ticket` runs `bd init --quiet` automatically
- **Completion**: `worktree-witness.sh` and `ticket-complete.sh` run `bd sync` before merge/PR
- **Commands**: `/beads:ready` (prime context), `/beads:create` (create issue)

### Checkpoints (Session Context ↔ Git Commits)
Links session transcript slices to commit SHAs on `checkpoints/v1` orphan branch. CLI: `ckpt` (Fish wrapper for `scripts/checkpoints.sh`). Run `ckpt --help` for commands.

- **Hooks**: UserPromptSubmit (pre-prompt state), Stop (capture transcript slice)
- **Per-worktree**: `gwt-ticket` runs `checkpoints enable` automatically (`--no-checkpoints` to opt out)
- **Key commands**: `ckpt enable`, `ckpt show <sha>`, `ckpt resume`, `ckpt context`, `ckpt search`, `ckpt doctor`
- **Coexistence**: Complements Beads (issue-level) — different granularity, no conflict.

### MCP Server Integration

**CRITICAL MCP Configuration Parity Rule**:
- **ALWAYS** ensure MCP servers are configured in BOTH Claude Desktop AND Claude Code CLI
- **ALWAYS** maintain parity between both configurations
- **ALWAYS** update both simultaneously when adding/removing MCP servers

**MCP Configuration Locations**:
1. **Claude Desktop**: `~/dotfiles/Library/Application Support/Claude/claude_desktop_config.json` (stow symlink)
2. **Claude Code CLI**: `claude mcp add` commands in `scripts/setup.sh` (Phase 4)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

**Adding New MCP Servers**:
1. Add to Claude Desktop config (`claude_desktop_config.json`)
2. Add to setup script via `claude mcp add` command
3. Verify: restart Claude Desktop, run `claude mcp list`
4. Test MCP server functionality in both environments

**MCP Server Types**:
- **Browser-Based** (browser-tools, drawio): Require browser extension, add to Brewfile, version-specific packages
- **AWS**: `uvx awslabs.<server-name>@latest`, ensure GraphViz installed, both configs required
- **Python**: `pipx run mcp-server-<name>` in setup script
- **API-based**: Disable by default, document API key requirements

**Verify Parity**: `claude mcp list` and `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers | keys'`

### Agentic Ticket Execution System
Autonomously execute tickets from Linear/Jira using devcontainers + ralph-loop.

| Command | Description |
|---------|-------------|
| `/todo <desc>` | Create ticket in Linear/Jira (auto-detected) |
| `/ticket-execute [KEY]` | Execute ticket autonomously |
| `gwt-ticket` | Core function: worktree + tmux + ralph-loop |
| `ticket-execute` / `tex` | High-level orchestrator |

**Ticketing detection**: `.claude/settings.local.json` → `.linear.toml` → git remote patterns → default Linear.
See `gwt-ticket --help` for full options.

### Ticket Queue (Rate-Limit-Aware Multi-Sub Scheduling)
Queue tickets for auto-execution when usage limits reset. Daemon auto-dispatches to lowest-utilization subscription profile.

**Commands**: `gwt-queue add|list|remove|start|stop|status|usage|profiles|next|log`. Fish: `.config/fish/functions/gwt-queue.fish`.
**Multi-Sub**: `--sub NAME` pins to profile; without it, auto-dispatches to lowest 5-hour utilization.
**Config env vars**: `QUEUE_POLL_INTERVAL` (300s), `QUEUE_THRESHOLD` (80%), `QUEUE_COOLDOWN` (600s).
**Files**: Queue data at `~/.claude/ticket-queue.json`, scripts at `scripts/ticket-queue/`.

### Docker Container Testing for Linux Compatibility
Test dotfiles on Linux distributions via Colima + Docker. Location: `scripts/docker/`. See `scripts/docker/README.md`.
- **ALWAYS** test cross-platform changes in containers (start with Ubuntu)
- **ALWAYS** verify stow operations and shell configs load without errors
- **NEVER** skip container testing when making cross-platform changes

### Mobile Coding Setup (Personal Devices Only)
Remote dev from mobile via Mosh + Tailscale. **Personal devices only** - separate from setup.sh.
Script: `scripts/setup-mobile-coding.sh`. Mobile tmux layout: `scripts/tmux/tmux-mobile-session.sh`

### Clawdbot AI Assistant (Optional)
WhatsApp/Telegram interface to Claude. Installed via `scripts/setup-mobile-coding.sh` or `npm install -g clawdbot@latest`.

### OpenClaw AI Assistant Platform
Self-hosted multi-channel AI inbox (Telegram, Slack, Discord, WhatsApp, Signal, WebChat). Docs: `docs/openclaw-setup.md`.

**Commands**: `openclaw start|stop|status|doctor|send|audit|pair|agent` (alias: `claw`). Fish: `.config/fish/functions/openclaw.fish`.
**Security**: Loopback binding, token auth, DM pairing, sandbox for non-main sessions. Config: `scripts/openclaw/openclaw-base.json`.
**Notifications**: `oc_notify()` in `scripts/openclaw/notify.sh` for gwt-ticket, ralph-loop, merge-queue integration.
**Runtime state**: `~/.openclaw/` (NOT in git). Tests: `scripts/test-filter.sh openclaw`.

### DNS Configuration
Cloudflare DNS (1.1.1.1, 1.0.0.1) configured in `scripts/setup/macos-defaults.sh` to bypass UK ISP DNS blocking.

### Pi-hole DNS Ad Blocking
Local DNS ad blocking via Colima + Docker. Location: `scripts/pihole/`. Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

### Keyboard Remapping
Karabiner-Elements: `.config/karabiner/karabiner.json` (stow managed). Caps Lock ↔ Escape swap. Edit via GUI app.

### Claude Code Hooks

Lifecycle hooks for deterministic control over Claude Code behavior. See `docs/claude-code-hooks.md` for complete reference.

**Hook Events Configured** (`.claude/settings.json`):

| Event | Hooks | Purpose |
|-------|-------|---------|
| **SessionStart** | `fix-hookify-imports.sh`, `bd prime`, `lsp-status.sh` | Plugin fixes, Beads memory, LSP context |
| **PreToolUse** (Bash) | `use_bun.py`, `validate-bash.py` | Bun enforcement, dangerous command blocking |
| **PostToolUse** (Read) | `deepwiki-context.py` | Language-aware DeepWiki repo suggestions |
| **PreCompact** | `bd sync` | Beads memory sync before compaction |
| **Notification** | `macos_notification.py`, `log-notification.sh` | Desktop alerts, audit logging |
| **UserPromptSubmit** | `checkpoint-pre-prompt.sh` | Checkpoint pre-prompt state capture |
| **Stop** | `checkpoint-capture.sh`, `cross-provider-bridge.sh` | Checkpoint capture, cross-provider review |

**Hook Types**: Command (shell scripts), Prompt (LLM yes/no), Agent (multi-turn with tools)

**Hook Scripts**: `.claude/hooks/` (Python/Bash scripts, symlinked via stow)

**Testing**: `scripts/test-filter.sh hooks` (44 tests: permissions, syntax, wiring, functional). Standalone: `scripts/test-hooks.sh` for detailed output.

**Adding New Hooks**:
1. Create script in `.claude/hooks/` (make executable)
2. Wire in `.claude/settings.json` under appropriate event
3. Add tests in `scripts/test-hooks.sh`
4. Update `docs/claude-code-hooks.md`

### Claude Code Plugins
14 plugins from 4 marketplaces + 9 LSP plugins from `boostvolt/claude-code-lsps`. Stored in `~/.claude/settings.json`, installation commands in `scripts/setup.sh`.

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Cost**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.
**Env vars**: `FORCE_AUTOUPDATE_PLUGINS=1`, `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (set in `config.fish`).
**Settings**: `teammateMode: "auto"` in `~/.claude.json`. Auto-Compact enabled (default).

### Claude Code LSP Integration
Native LSP servers for Claude Code — real-time diagnostics, go-to-definition, find-references without IDE dependency. Docs: `docs/claude-code-lsp.md`.

**Marketplace**: `boostvolt/claude-code-lsps` (22 languages). Installed via `scripts/setup.sh`.
**Installed plugins**: pyright (Python), typescript (TS/JS), gopls (Go), rust-analyzer (Rust), bash-lsp (Bash), yaml-lsp (YAML), terraform (HCL), lua-lsp (Lua), nix-lsp (Nix).
**LSP binaries**: Reuses Nix global devShell binaries (`nix/global/`). Same binaries serve both Neovim and Claude Code.
**Fish command**: `cc-lsp status|install|doctor` — check/manage LSP integration.
**SessionStart hook**: `lsp-status.sh` injects available LSP servers into Claude's context.
**LSP tool operations**: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`.
**Tests**: `scripts/test-filter.sh lsp`

### Claude Code Agent Teams (Experimental)
Coordinate multiple Claude Code instances with shared tasks and messaging. Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

**Config**: `teammateMode = "auto"` (tmux split panes), override: `claude --teammate-mode in-process`.
**Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate, `Ctrl+T` task list.
**When to use**: Same-repo collaborative work. Use `gwt-parallel` for isolated multi-branch, `gwt-ticket` for autonomous single-ticket.
**Best practices**: Assign different files per teammate, provide specific context (no inherited history), 5-6 tasks per teammate.

## Quality Assurance

### Before Committing
- Verify setup script works, stow completes, theme consistency maintained
- Validate Fish and Zsh configurations work correctly

### Troubleshooting
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Stow Conflicts**: Resolve symlink conflicts before deployment

## Continuous Improvement

### Rule Evolution
- Update rules when new patterns emerge
- Deprecate outdated configurations
- Maintain compatibility with latest tool versions
- Document architectural decisions in this file

### Kubernetes Manifests
- **ALWAYS** place manifests in `scripts/manifests/` with descriptive filenames
- **ALWAYS** update `scripts/manifests/README.md` with: filename, purpose, namespace, container details, usage, and use case

## Agent Workflow Guidance

### AGENTS.md
Practical agent rules in root `AGENTS.md` - concrete rules based on observed bad behaviors. See also `scripts/test-filter.sh` for filtered test runner.

### Background Agent Patterns
- **Slam dunks**: `gwt-ticket` or `ralph-loop` for well-defined tasks
- **Research**: Surveying fields, producing comparison summaries
- **Parallel exploration**: `gwt-parallel` for vague ideas
- **Single Agent Rule**: One background agent at a time

### When NOT to Use Agents
- Karabiner-Elements config (use GUI), Brewfile organization, tmux plugin installation (TPM)
- Theme consistency verification, 1Password/SSH setup, stow conflict resolution
- LazyVim plugin config (lives in `~/neovim`)

### Claude Pipeline (Multi-Model Reasoning Chains)
Chain models in terminal: `claude-pipeline` / `cpipe`. Default: opus→sonnet. Docs: `docs/claude-pipeline.md`.

**Presets**: `review` (opus→sonnet→haiku), `cheap` (sonnet→haiku), `local` (ollama→sonnet), `council`, `redteam`.
**Custom**: `--reason MODEL --execute MODEL`, `--stages N`, `--save /tmp/out`, `--dry-run`. Supports piped input.
**In-TUI**: `/model opusplan` auto-switches opus (plan) → sonnet (execution) within a session.

### Self-Hosted LLM Infrastructure
Local LLM stack (Ollama + Open WebUI) as resilience layer. Setup: `scripts/setup-selfhost-llm.sh`.

**Fish commands**: `llm`, `llm-code`, `llm-chat`, `llm-status`, `llm-pull`, `llm-web`. Coding agents: `opencode-local`, `claude-local`.
**Default models**: qwen3-coder (coding agents), qwen2.5-coder:7b, llama3.1:8b, mistral:7b. Env overrides: `LLM_DEFAULT_MODEL`, `LLM_CODE_MODEL`.
**API**: OpenAI-compatible at `http://localhost:11434/v1`. OpenCode config: `.config/opencode/opencode.json` (stow managed).
**Testing**: `scripts/test-selfhost-llm.sh` (`--live` for runtime tests)

### Cross-Provider Reasoning Bridge
Stop hook for correlation-bias mitigation — sends reasoning to independent AI providers. Iterative consensus with graceful fallback chain.

**Enable**: `CROSS_PROVIDER_BRIDGE=1 claude` | **Providers**: Codex, Gemini, Ollama, DeepSeek, Claude, OpenCode
**Key env vars**: `CROSS_PROVIDER_ORDER` (default: `codex,opencode`), `CROSS_PROVIDER_MODE` (`review|redteam|steelman|assumptions`), `CROSS_PROVIDER_MAX_ITERATIONS` (default: 3).
**Hook**: `.claude/hooks/cross-provider-bridge.sh` (command type, not prompt/agent — same-provider defeats purpose)
**gwt-ticket**: `--bridge [N]`, `--bridge-providers P`, `--bridge-verbose`, `--bridge-model M`, `--bridge-timeout S`, `--bridge-log FILE`
**Testing**: `scripts/test-claude-pipeline.sh` (`--live` for E2E)

### Decision Quality System (DQS)
Multi-perspective plan evaluation. Docs: `docs/decision-quality-system.md`.

**Three paths**: Council (`cpipe --preset council`), Red Team (`CROSS_PROVIDER_MODE=redteam`), First Principles (`CROSS_PROVIDER_MODE=assumptions`).
**Pipeline presets**: `--preset council` (opus→sonnet→opus), `--preset redteam` (opus→sonnet).
**Plan template**: `templates/workflows/plan-review.toml`.
