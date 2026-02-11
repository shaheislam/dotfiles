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

**Subscription Profiles**: Multiple Claude Max subscriptions under one account. Managed via `claude-sub` (`csub`).

| Command | Alias | Description |
|---------|-------|-------------|
| `claude-sub setup <name>` | `csub setup` | Create profile with shared config, opens browser for OAuth |
| `claude-sub list` | `csub list` | List profiles with org/plan info |
| `claude-sub current` | `csub current` | Show active profile |
| `claude-sub login <name>` | `csub login` | Re-authenticate a profile |

- **Profile dirs**: `~/.claude-<name>/` with shared config symlinked from `~/.claude/`
- **Usage**: `gwtt "Fix bug" "Details" --sub personal` or `gwtc feature/auth --sub work`
- **Setup with org**: `claude-sub setup work --org-uuid c92a9a60-...`

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
Multi-agent lifecycle management inspired by Gastown's orchestration patterns.

**Agent State Derivation** (`scripts/agent-state.sh`):
Derives agent state from tmux + git + ralph-loop state files (ZFC pattern - derive from ground truth, don't cache).
```bash
agent-state.sh <worktree-path> --json    # JSON output
agent-state.sh --all                      # All active worktrees
```
States: `running` | `idle` | `stuck` | `completed` | `dead` | `none`

**Worktree Witness** (`scripts/worktree-witness.sh`):
Per-worktree lifecycle monitor, auto-spawned by `gwt-ticket`. Monitors ralph-loop progress, detects crashes, auto-retries (up to 3), submits to merge queue on completion.
```bash
worktree-witness.sh status <worktree>    # Check witness status
worktree-witness.sh stop <worktree>      # Stop monitoring
```

**Merge Queue** (`scripts/merge-queue.sh`):
Serializes merges to prevent conflicts when multiple agents complete simultaneously.
```bash
merge-queue.sh add <worktree>            # Queue for merge
merge-queue.sh daemon                     # Start queue processor
merge-queue.sh list                       # Show queue
merge-queue.sh stop                       # Stop daemon
```

**Agent Triage** (`scripts/agent-triage.sh`):
Intelligent decision system for agent problems. Actions: START (crash recovery), WAKE (nudge idle), NUDGE (restart stuck), NOTHING.
```bash
agent-triage.sh <worktree>               # Assess and act
agent-triage.sh <worktree> --dry-run     # Assess only
```

**Phase Gates** (`scripts/phase-gates.sh`):
Pause agents on external conditions (CI pipeline, PR review, human input, dependency).
```bash
phase-gates.sh create ci-pipeline <worktree>   # Create gate
phase-gates.sh check ci-pipeline <worktree>    # Check condition
phase-gates.sh signal <worktree>               # Signal human gate
phase-gates.sh list <worktree>                 # List gates
```

**Workflow Templates** (`templates/workflows/*.toml`):
Externalized prompt templates for `gwt-ticket`. Available: `implement`, `bugfix`, `refactor`, `test`.
```bash
gwt-ticket ENG-123 "Add auth" "OAuth2" --template implement
gwt-ticket BUG-456 "Fix crash" "NPE" --template bugfix
```

| Script | Purpose |
|--------|---------|
| `agent-state.sh` | Derive agent state from ground truth |
| `worktree-witness.sh` | Per-worktree lifecycle monitor |
| `merge-queue.sh` | Serialized merge processing |
| `agent-triage.sh` | Intelligent restart decisions |
| `phase-gates.sh` | Pause/resume on external conditions |

### Beads Agent Memory
Git-backed agent memory that persists across sessions. Auto-initialized in worktrees by `gwt-ticket`.
- **CLI**: `bd` (installed via Homebrew)
- **Hooks**: SessionStart (`bd prime`), PreCompact (`bd sync`) — no-ops if project has no `.beads/`
- **Per-worktree**: `gwt-ticket` runs `bd init --quiet` automatically
- **Completion**: `worktree-witness.sh` and `ticket-complete.sh` run `bd sync` before merge/PR
- **Commands**: `/beads:ready` (prime context), `/beads:create` (create issue)

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
Queue tickets to auto-execute via `gwt-ticket` when Claude Code usage limits reset.
Supports multiple subscription profiles - daemon auto-dispatches to whichever profile has capacity.

**Architecture**: Background daemon polls OAuth usage API per profile → dispatches with lowest-utilization profile.

| Command | Description |
|---------|-------------|
| `gwt-queue add [KEY] <title> [desc] [--opts]` | Queue ticket for later execution |
| `gwt-queue add "Fix bug" --sub personal` | Queue pinned to specific profile |
| `gwt-queue list` / `ls` | List queued tickets |
| `gwt-queue remove <id>` | Remove ticket from queue |
| `gwt-queue start` | Start queue daemon |
| `gwt-queue stop` | Stop queue daemon |
| `gwt-queue status` | Show daemon + queue + usage |
| `gwt-queue usage [--sub NAME]` | Check Claude usage (per profile) |
| `gwt-queue profiles` | List all subscription profiles + usage |
| `gwt-queue next` | Dispatch next ticket immediately |
| `gwt-queue log [N]` | Show daemon log |

**Multi-Sub Dispatching**:
- Tickets with `--sub NAME`: dispatched only when that profile has capacity
- Tickets without `--sub`: auto-dispatched to whichever profile has lowest 5-hour utilization
- Daemon checks all authenticated profiles each poll cycle

**Configuration** (env vars):
| Variable | Default | Purpose |
|----------|---------|---------|
| `QUEUE_POLL_INTERVAL` | `300` | Seconds between usage checks |
| `QUEUE_THRESHOLD` | `80` | Dispatch when utilization below this % |
| `QUEUE_COOLDOWN` | `600` | Min seconds between dispatches |

**Files**:
- Queue data: `~/.claude/ticket-queue.json`
- Daemon scripts: `scripts/ticket-queue/`
- Fish function: `.config/fish/functions/gwt-queue.fish`
- LaunchAgent: `Library/LaunchAgents/com.dotfiles.ticket-queue.plist` (optional auto-start)

**Usage checker**: `scripts/ticket-queue/claude-usage.sh` queries the undocumented OAuth usage API.
Supports `--config-dir ~/.claude-NAME` for per-profile usage checks.

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

### DNS Configuration
Cloudflare DNS (1.1.1.1, 1.0.0.1) configured in `scripts/setup/macos-defaults.sh` to bypass UK ISP DNS blocking.

### Pi-hole DNS Ad Blocking
Local DNS ad blocking via Colima + Docker. Location: `scripts/pihole/`. Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

### Keyboard Remapping
Karabiner-Elements: `.config/karabiner/karabiner.json` (stow managed). Caps Lock ↔ Escape swap. Edit via GUI app.

### Claude Code Plugins

Plugins are installed from four marketplaces:
- `anthropics/claude-code` (alias: `claude-code-plugins`) - Official Anthropic plugins
- `kenryu42/cc-marketplace` (alias: `cc-marketplace`) - Community safety plugins
- `antonbabenko/terraform-skill` (alias: `antonbabenko`) - Terraform/OpenTofu development skill
- `steveyegge/beads` - Git-backed agent memory and issue tracking

**Installation**: Plugins stored in `~/.claude/settings.json`. For cross-device consistency, installation commands are in `scripts/setup.sh`.

**Installed Plugins (14 total)**:

| Plugin | Command | Purpose |
|--------|---------|---------|
| **code-review** | `/code-review` | Automated PR review with 4 parallel agents, 80+ confidence filtering |
| **pr-review-toolkit** | Auto-triggered | 6 specialized reviewers (comments, tests, errors, types, quality, simplicity) |
| **hookify** | `/hookify` | Create hooks via markdown (also `/hookify:list`, `/hookify:configure`) |
| **feature-dev** | `/feature-dev` | 7-phase feature development workflow |
| **frontend-design** | Auto-activated | Production-grade UI generation, anti-AI aesthetics |
| **plugin-dev** | `/plugin-dev:create-plugin` | 7 skills + 8-phase plugin creation workflow |
| **ralph-wiggum** | `/ralph-wiggum:ralph-loop` | Autonomous iteration loops (also `/ralph-wiggum:cancel-ralph`) |
| **agent-sdk-dev** | `/new-sdk-app` | Claude Agent SDK project scaffolding |
| **explanatory-output-style** | SessionStart hook | Educational insights on implementation choices |
| **learning-output-style** | SessionStart hook | Interactive learning mode with code contribution prompts |
| **code-simplifier** | Auto-triggered | Identifies over-engineering, suggests simpler implementations |
| **security-guidance** | Auto-triggered | Security best practices, vulnerability detection, compliance guidance |
| **terraform-skill** | Auto-activated | Terraform/OpenTofu module development, testing frameworks, CI/CD workflows |
| **beads** | `/beads:ready`, `/beads:create` | Git-backed agent memory, in-repo issue tracking with DAG dependencies |

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`

**Token Cost Note**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.

**Environment Variables** (set in `config.fish`):
| Variable | Value | Purpose |
|----------|-------|---------|
| `FORCE_AUTOUPDATE_PLUGINS` | `1` | Auto-update plugins on every session start |
| `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | `1` | Load CLAUDE.md from `--add-dir` paths (used by gwt-ticket) |

**Settings** (`~/.claude.json`): `teammateMode: "auto"` (set by setup.sh via `jq` and `claude config set`).

**Auto-Compact**: Enabled (default). Long ralph-loop sessions benefit from mid-session compaction.

### Claude Code Agent Teams (Experimental)

**Purpose**: Coordinate multiple Claude Code instances with shared tasks, inter-agent messaging, and centralized management.

**Reference**: https://code.claude.com/docs/en/agent-teams

**Status**: Experimental (enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)

**Configuration** (set by `scripts/setup.sh` into `~/.claude/settings.json`):
- **Env var**: `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`
- **Display mode**: `teammateMode = "auto"` (auto-detects tmux for split panes)
- **CLI override**: `claude --teammate-mode in-process` for single-terminal mode

**Display Modes**:
| Mode | Description | Requirement |
|------|-------------|-------------|
| `auto` (default) | Split panes if tmux detected, in-process otherwise | tmux (already installed) |
| `in-process` | All teammates in main terminal, navigate with Shift+Up/Down | Any terminal |
| `tmux` | Each teammate in own pane | tmux or iTerm2 |

**When to Use**:
- **Agent Teams**: Same-repo work needing communication (code review, debugging, cross-layer features)
- **gwt-parallel**: Multi-branch isolated work where agents work independently
- **gwt-ticket + ralph-loop**: Autonomous single-ticket execution with iteration

**Key Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate mode, `Ctrl+T` task list

**Best Practices**:
- Assign different files to different teammates to avoid conflicts
- Use delegate mode to keep lead focused on coordination
- Provide specific context in spawn prompts (teammates don't inherit history)
- Target 5-6 tasks per teammate for optimal productivity

**Limitations**: No session resumption, one team per session, no nested teams, not in Ghostty

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

Chain Claude Code models in the terminal: pass reasoning output from one model as input to another.
Uses your existing Claude Code subscription (Max/Pro/Teams) - no API key needed.

**Fish Functions**: `claude-pipeline` (`cpipe`)

| Command | Description |
|---------|-------------|
| `claude-pipeline <prompt>` | Default: opus reasons → sonnet implements |
| `cpipe --preset review <prompt>` | opus → sonnet → haiku (3-stage with review) |
| `cpipe --preset cheap <prompt>` | sonnet → haiku (cost-effective) |
| `cpipe --preset local <prompt>` | ollama → sonnet (local reasoning → cloud implementation) |
| `cpipe --reason MODEL --execute MODEL` | Custom model selection |
| `cpipe --stages N` | 2-5 stages |
| `cpipe --save /tmp/out` | Save intermediate outputs |
| `cpipe --dry-run` | Show pipeline without executing |

**Pipe support**: `cat code.ts | cpipe 'refactor with better error handling'`

**How it works**: `claude -p --model opus "plan" | claude -p --model sonnet "implement"`

**In-TUI Alternative**: `/model opusplan` auto-switches opus (plan mode) → sonnet (execution) within a session.

**Docs**: `docs/claude-pipeline.md` | **Testing**: `scripts/test-claude-pipeline.sh` (`--live` for API tests)

### Self-Hosted LLM Infrastructure

**Purpose**: Local LLM stack as a resilience layer when cloud AI services (Claude, Codex, etc.) go down.

**Setup Script**: `scripts/setup-selfhost-llm.sh`

**Components**:
- **Ollama**: Local LLM runtime (runs models on your hardware)
- **Open WebUI**: Browser-based chat interface (ChatGPT/Claude replacement)
- **Fish functions**: CLI integration for quick model interaction

**Usage**:
```bash
# Install the full stack
./scripts/setup-selfhost-llm.sh

# Just pull/update models
./scripts/setup-selfhost-llm.sh --models-only

# Include large models (32GB+ RAM required)
./scripts/setup-selfhost-llm.sh --large-models

# Uninstall everything
./scripts/setup-selfhost-llm.sh --uninstall
```

**Fish Shell Commands**:
| Command | Description |
|---------|-------------|
| `llm <prompt>` | Quick query (default: llama3.1:8b) |
| `llm-code <prompt>` | Code-focused query (default: qwen2.5-coder:7b) |
| `llm-chat [model]` | Interactive chat session |
| `llm-status` | Check Ollama status and installed models |
| `llm-pull <model>` | Pull a new model from Ollama registry |
| `llm-web` | Launch Open WebUI in browser |

**Coding Agent Commands** (agentic experience with local models):
| Command | Description |
|---------|-------------|
| `opencode-local` | OpenCode + Ollama (primary - full agent with file editing, shell) |
| `claude-local` | Claude Code + Ollama (alternative - same env, different frontend) |
| `claude-local --model MODEL` | Use a specific Ollama model with Claude Code |

**Default Models**:
| Model | Size | Purpose |
|-------|------|---------|
| qwen3-coder | ~5GB | Agentic coding, 256K context (recommended for coding agents) |
| qwen2.5-coder:7b | ~4GB | Fast coding assistant |
| deepseek-coder-v2:16b | ~9GB | Deep reasoning for complex code |
| llama3.1:8b | ~4GB | Fast general-purpose |
| mistral:7b | ~4GB | Balanced all-rounder |

**Environment Variables**:
- `LLM_DEFAULT_MODEL`: Override default general model (default: llama3.1:8b)
- `LLM_CODE_MODEL`: Override default coding model (default: qwen2.5-coder:7b)
- `OPEN_WEBUI_PORT`: Override Open WebUI port (default: 8080)

**API Compatibility**: Ollama exposes an OpenAI-compatible API at `http://localhost:11434/v1`, allowing tools that support `OPENAI_API_BASE` to use local models.

**OpenCode Configuration**: `.config/opencode/opencode.json` configures Ollama as a provider with `qwen3-coder` as the default model. Managed via stow.

**Pipe Support**: Fish functions support piped input for context:
```bash
cat main.py | llm-code 'review this code for bugs'
git diff | llm-code 'write a commit message'
echo 'some text' | llm 'summarize this'
```

**Testing**: `scripts/test-selfhost-llm.sh` (config tests + coding agent tests, `--live` for runtime tests)

### Cross-Provider Reasoning Bridge
Stop hook that sends Claude's reasoning to an independent AI provider (Codex/OpenCode) for correlation-bias mitigation.
Iterative consensus: reviewer and Claude exchange feedback until agreement or max iterations.
Graceful fallback: Codex → OpenCode → silent continue (zero failures).

**Enable**: `CROSS_PROVIDER_BRIDGE=1 claude`

| Variable | Default | Purpose |
|----------|---------|---------|
| `CROSS_PROVIDER_BRIDGE` | `0` | Enable/disable the bridge |
| `CROSS_PROVIDER_ORDER` | `codex,opencode` | Provider priority order |
| `CROSS_PROVIDER_MAX_CHARS` | `4000` | Max context chars to send |
| `CROSS_PROVIDER_PROMPT` | *(built-in)* | Custom review prompt |
| `CROSS_PROVIDER_MAX_ITERATIONS` | `3` | Max consensus iterations (set `1` for single-shot) |

**Architecture**: Uses `type: "command"` Stop hook (not `prompt`/`agent` which use Anthropic models — same-provider defeats the purpose).
**Hook**: `.claude/hooks/cross-provider-bridge.sh` | **Testing**: `scripts/test-claude-pipeline.sh` (`--live` for E2E tests)

**Usage**:
```bash
# Autonomous ticket with cross-provider review
gwtt ENG-123 --bridge

# Ticket-free with bridge
gwtt "Fix auth bug" "Session tokens expire" --bridge

# Manual interactive session
CROSS_PROVIDER_BRIDGE=1 claude
```

### Recent Updates
- **2026-02-11**: Added gwt-doctor agent health check, activated Beads agent memory (phases 3-5)
- **2026-02-09**: Added Gastown agent orchestration patterns (agent-state, witness, merge-queue, triage, phase-gates, workflow templates)
- **2026-02-08**: Added Cross-Provider Reasoning Bridge (Stop hook for correlation-bias mitigation via Codex/OpenCode)
- **2026-02-08**: Added Claude Pipeline multi-model reasoning chains (claude-pipeline/cpipe - opus→sonnet piping)
- **2026-02-08**: Added Beads agent memory integration (steveyegge/beads - git-backed issue tracker for AI agents)
- **2026-02-07**: Added local coding agent integration (OpenCode + Claude Code via Ollama with qwen3-coder)
- **2026-02-05**: Added Self-Hosted LLM infrastructure (Ollama + Open WebUI + Fish functions)
- **2026-02-05**: Added Agentic Ticket Execution System (/todo, /ticket-execute, ralph-loop integration)
- **2026-01-25**: Added Cloudflare DNS configuration to macos-defaults.sh (bypasses UK ISP DNS blocking)
- **2026-01-25**: Added terraform-skill plugin from antonbabenko/terraform-skill for Terraform/OpenTofu development
- **2026-01-23**: Added Clawdbot AI assistant integration for WhatsApp/Telegram interface to Claude
- **2026-01-17**: Added Mobile Coding Setup script for remote development from mobile devices via Mosh + Tailscale
- **2026-01-14**: Added `autoCompactEnabled: false` to setup.sh for automatic context compaction control
- **2025-12-17**: Added 11 Claude Code plugins from anthropics/claude-code marketplace
- **2025-11-01**: Configured Opencode with transparent background using system theme (inherits terminal transparency)
- **2025-10-30**: Added Docker container testing framework for Linux compatibility validation
- **2025-10-30**: Fixed BAT_PAGING error in Fish and Zsh configs (prevents FZF preview file descriptor errors)
- **2025-01-26**: Aligned Fish and Zsh configurations for feature parity
- **2025-01-26**: Removed Powerlevel10k configs in favor of Starship-only setup
- **2025-10-05**: Added Kubernetes manifests directory with documentation requirements
