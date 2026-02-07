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

Setup scripts run automatically: `.devcontainer/setup.sh` or `scripts/setup-worktree.sh`

### Claude Code Devcontainer Auto-Login
Auto-authenticates Claude Code inside devcontainers by bind-mounting the host's `~/.claude` directory directly.
All containers share the same config directory — credentials, plugins, settings, and hooks are all available. When any container refreshes OAuth tokens, all others see the update immediately.
- **Key File**: `scripts/devcontainer/export-claude-credentials.sh` (exports Keychain to `~/.claude`, idempotent, `--force` to overwrite)
- **Mount**: `~/.claude` (bind-mounted to `/home/node/.claude` in containers)
- **Test**: `scripts/devcontainer/test-claude-autologin.sh`

### Claude & Opencode Activity Watcher
Background daemon monitoring tmux windows for idle processes: `scripts/tmux/tmux-claude-watcher.sh`
- 🟢 = Claude idle, 🔵 = Opencode idle, 🟢🔵 = Both idle

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

### Ticket Queue (Rate-Limit-Aware Scheduling)
Queue tickets to auto-execute via `gwt-ticket` when Claude Code usage limits reset.

**Architecture**: Background daemon polls OAuth usage API → dispatches when utilization < threshold.

| Command | Description |
|---------|-------------|
| `gwt-queue add [KEY] <title> [desc] [--opts]` | Queue ticket for later execution |
| `gwt-queue list` / `ls` | List queued tickets |
| `gwt-queue remove <id>` | Remove ticket from queue |
| `gwt-queue start` | Start queue daemon |
| `gwt-queue stop` | Stop queue daemon |
| `gwt-queue status` | Show daemon + queue + usage |
| `gwt-queue usage` | Check Claude usage limits |
| `gwt-queue next` | Dispatch next ticket immediately |
| `gwt-queue log [N]` | Show daemon log |

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

**Usage checker**: `scripts/ticket-queue/claude-usage.sh` queries the undocumented OAuth usage API
(`/api/oauth/usage`) for 5-hour and 7-day utilization with exact reset timestamps.

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

Plugins are installed from three marketplaces:
- `anthropics/claude-code` (alias: `claude-code-plugins`) - Official Anthropic plugins
- `kenryu42/cc-marketplace` (alias: `cc-marketplace`) - Community safety plugins
- `antonbabenko/terraform-skill` (alias: `antonbabenko`) - Terraform/OpenTofu development skill

**Installation**: Plugins stored in `~/.claude/settings.json`. For cross-device consistency, installation commands are in `scripts/setup.sh`.

**Installed Plugins (13 total)**:

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
