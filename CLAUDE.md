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
Auto-authenticates Claude Code inside devcontainers via macOS Keychain credential export/import.
- **Key Files**: `scripts/devcontainer/export-claude-credentials.sh`, `import-claude-credentials.sh`
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

**Rules**: Use `bunx` not `npx` for Node MCPs (hook enforced). Use `uvx` for AWS MCPs. Use `pipx run` for Python MCPs. All AWS MCPs must be in both configs.
**Verify**: `claude mcp list` after changes to confirm parity.

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

### Agent Teams (Experimental)
Coordinate multiple Claude Code instances with shared tasks and messaging.
- **Config**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`
- **Display**: `teammateMode = "auto"` (tmux split panes or in-process)
- **Controls**: `Shift+Up/Down` navigate, `Shift+Tab` delegate mode, `Ctrl+T` task list
- **When to use**: Same-repo work needing communication (vs `gwt-parallel` for isolated multi-branch)
- **Limitations**: No session resumption, one team per session, no nested teams, not in Ghostty

### Claude Code Plugins (14 installed)
Installed from: `anthropics/claude-code`, `kenryu42/cc-marketplace`, `antonbabenko/terraform-skill`

Key plugins: code-review, pr-review-toolkit, hookify, feature-dev, ralph-wiggum, plugin-dev, agent-sdk-dev, frontend-design, code-simplifier, security-guidance, terraform-skill

**Managing**: `claude plugin install|disable|enable|uninstall plugin-name@marketplace`
**Token Note**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks. Disable when not needed.

**Settings** (`~/.claude.json`): `autoCompactEnabled: false`, `teammateMode: "auto"` (set by setup.sh)

### DNS Configuration
Cloudflare DNS (1.1.1.1, 1.0.0.1) configured in `scripts/setup/macos-defaults.sh` to bypass UK ISP DNS blocking.

### Pi-hole DNS Ad Blocking
Local DNS ad blocking via Colima + Docker. Location: `scripts/pihole/`. Fish wrapper: `pihole start|stop|dns-on|dns-off|status`

### Mobile Coding Setup
Remote dev from mobile via Mosh + Tailscale. **Personal devices only** - separate from setup.sh.
Script: `scripts/setup-mobile-coding.sh`. Mobile tmux layout: `scripts/tmux/tmux-mobile-session.sh`

### Clawdbot AI Assistant (Optional)
WhatsApp/Telegram interface to Claude. Installed via `scripts/setup-mobile-coding.sh` or `npm install -g clawdbot@latest`.

### Docker Container Testing
Linux compatibility testing via Colima + Docker. Location: `scripts/docker/`. See `scripts/docker/README.md`.
- **ALWAYS** test cross-platform changes in containers (start with Ubuntu)
- **ALWAYS** verify stow operations and shell configs load without errors
- **NEVER** skip container testing when making cross-platform changes

### Kubernetes Manifests
- **ALWAYS** place manifests in `scripts/manifests/` with descriptive filenames
- **ALWAYS** update `scripts/manifests/README.md` with: filename, purpose, namespace, container details, usage, and use case

### Keyboard Remapping
Karabiner-Elements: `.config/karabiner/karabiner.json` (stow managed). Caps Lock ↔ Escape swap. Edit via GUI app.

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
