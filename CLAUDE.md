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

2. **Claude Code CLI**: Managed via `claude mcp add` commands in setup script
   - Located in `scripts/setup.sh` (Phase 4: Cloud & Infrastructure Tools)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

**Adding New MCP Servers (Required Steps)**:
1. Add to Claude Desktop config (`claude_desktop_config.json`)
2. Add to setup script via `claude mcp add` command
3. Verify both configurations with:
   - Restart Claude Desktop app
   - Run `claude mcp list` to verify Claude Code CLI
4. Test MCP server functionality in both environments

**Browser-Based MCP Servers** (e.g., browser-tools, drawio):
- Require browser extension installation
- Add packages to Brewfile if needed
- Document manual browser extension installation steps
- Use version-specific packages when required (v1.1.0 for Claude Desktop, v1.2.0 for Claude Code)

**AWS MCP Servers**:
- Use `uvx awslabs.<server-name>@latest` command
- Add environment variables as needed (e.g., `FASTMCP_LOG_LEVEL`, `AWS_DOCUMENTATION_PARTITION`)
- Ensure GraphViz is installed for aws-diagram-mcp-server
- All AWS MCPs must be in both Claude Desktop and Claude Code CLI configs

**Python MCP Servers**:
- Install via `pipx` and configure with appropriate paths
- Use `pipx run mcp-server-<name>` in setup script

**API-based MCPs**:
- Add to config but disable by default
- Document API key requirements in comments
- Provide setup instructions for users who want to enable them

**MCP Parity Verification**:
```bash
# Verify Claude Code CLI MCPs
claude mcp list

# Check Claude Desktop config
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers | keys'
```

## Quality Assurance

### Before Committing Changes
- Verify setup script runs successfully on clean system
- Check that all new tools are properly integrated
- Ensure theme consistency across all applications
- Test stow operations complete without conflicts
- Validate Fish and Zsh configurations work correctly

### Troubleshooting Common Issues
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Setup Script Failures**: Test on clean macOS installation
- **Stow Conflicts**: Resolve symlink conflicts before deployment

## Continuous Improvement

### Rule Evolution
- Update rules when new patterns emerge
- Deprecate outdated configurations
- Maintain compatibility with latest tool versions
- Document architectural decisions in this file
- Keep setup script updated with latest best practices

### Knowledge Management
- Maintain this file as the single source of truth
- Document new tools and their integration patterns
- Keep track of deprecated configurations
- Record solutions to common problems
- Update workflow documentation as processes evolve

### Kubernetes Manifests Management
- **ALWAYS** place Kubernetes manifest files in `scripts/manifests/` directory
- **ALWAYS** update `scripts/manifests/README.md` when adding new manifest files
- **ALWAYS** include in the README: filename, purpose, namespace, container details, usage, and use case
- **ALWAYS** use descriptive filenames for manifests (e.g., `test-shell-deployment.yaml` not `test.yaml`)

### Docker Container Testing for Linux Compatibility
- **Purpose**: Test dotfiles installation on Linux distributions without requiring a full VM
- **Location**: All testing infrastructure in `scripts/docker/` directory
- **Runtime**: Uses Colima (already installed) for container management

**Testing Workflow**:
1. **Start Colima**: `./scripts/docker/colima-setup.sh start`
2. **Build Test Image**: `docker build -f scripts/docker/dockerfiles/ubuntu.Dockerfile -t dotfiles-test:ubuntu .`
3. **Run Tests**: `docker run --rm dotfiles-test:ubuntu /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh`
4. **Interactive Testing**: `docker run -it --rm dotfiles-test:ubuntu`

**What Gets Tested**:
- ✅ Package manager detection (apt/dnf/pacman)
- ✅ GNU Stow symlink operations
- ✅ Fish and Zsh shell configurations
- ✅ Environment variables (including BAT_PAGING fix)
- ✅ CLI tool configurations
- ✅ PATH configurations
- ⚠️ Homebrew packages (translated to Linux equivalents)
- ❌ macOS-specific tools (skipped)

**Key Files**:
- `scripts/docker/README.md` - Comprehensive testing documentation
- `scripts/docker/colima-setup.sh` - Colima management helper
- `scripts/docker/dockerfiles/ubuntu.Dockerfile` - Ubuntu 22.04 test environment
- `scripts/docker/scripts/run-all-tests.sh` - Main test orchestrator
- `scripts/docker/scripts/test-*.sh` - Individual test suites

**Best Practices**:
- **ALWAYS** test dotfiles changes in containers before deploying to production Linux
- **ALWAYS** start with Ubuntu tests (most common Linux distribution)
- **ALWAYS** verify stow operations complete successfully
- **ALWAYS** check shell configs load without errors
- **NEVER** skip testing when making cross-platform changes

**Development Mode**:
```bash
# Mount local dotfiles for live testing
docker run -it --rm -v ~/dotfiles:/home/testuser/dotfiles dotfiles-test:ubuntu
```

**Troubleshooting**:
- **Colima issues**: Run `./scripts/docker/colima-setup.sh restart`
- **Build failures**: Check `scripts/docker/.dockerignore` and rebuild with `--no-cache`
- **Test failures**: Review test output in `/tmp/dotfiles-test-results/*.log` inside container
- **BAT_PAGING errors**: Ensure the fix is in both `.config/fish/config.fish` and `.zshrc`

**Future Enhancements**:
- Multi-distribution support (Debian, Fedora, Arch, Alpine)
- Docker Compose for parallel multi-distro testing
- Automated Brewfile translation to Linux package managers
- CI/CD integration for continuous testing

### Mobile Coding Setup (Personal Devices Only)

**Purpose**: Enable remote development from mobile devices (phone/tablet) via Mosh + Tailscale.

**IMPORTANT**: This is a SEPARATE script from `setup.sh` to avoid installing remote access tools on work devices. Only run on personal machines.

**Setup Script**: `scripts/setup-mobile-coding.sh`

**What It Installs/Configures**:
- **Mosh**: Mobile shell with connection persistence (survives WiFi/cellular switches)
- **Tailscale**: Zero-config VPN (no port forwarding needed)
- **SSH**: Key-only authentication (works with 1Password)
- **Sleep**: Disabled for 24/7 accessibility
- **Firewall**: Opens Mosh UDP ports (60000-61000)
- **tmux**: Mobile-optimized session layout

**Usage**:
```bash
# Install (personal devices only!)
./scripts/setup-mobile-coding.sh

# With verbose output
./scripts/setup-mobile-coding.sh --verbose

# Uninstall everything
./scripts/setup-mobile-coding.sh --uninstall
```

**Phone Setup (after running script)**:
1. Install Tailscale app, sign in with same account
2. Install Termius app, create host with Tailscale hostname
3. Enable Mosh in Termius host settings
4. Import SSH key from 1Password into Termius
5. Connect and run: `tmux-mobile-session.sh`

**Mobile tmux Session**: `scripts/tmux/tmux-mobile-session.sh`
```
┌─────────────────────────────────┐
│          claude (main)          │  ← 70% height
├─────────────────────────────────┤
│    editor    │      shell       │  ← 30% height
└─────────────────────────────────┘
```

**Quick Access**: Add to `.tmux.conf`:
```bash
bind M run-shell '~/dotfiles/scripts/tmux/tmux-mobile-session.sh'
```
Then use: `prefix + M` to launch mobile session.

### Clawdbot AI Assistant (Optional)

**Purpose**: WhatsApp/Telegram interface to Claude on your Mac, complementing Termius + Claude Code workflow.

**Value Proposition**:
- Quick queries without opening Termius
- Voice messages to Claude while walking
- Photo → codebase-aware response
- Scheduled automation with delivery notifications
- Async tasks ("message me when done")

**Comparison with Termius**:
| Use Case | Best Tool |
|----------|-----------|
| Development work | Termius + Claude Code |
| Quick questions | Clawdbot (WhatsApp/Telegram) |
| Scheduled tasks | Clawdbot (cron jobs) |
| Voice/photo input | Clawdbot |

**Installation** (requires Node.js >= 22):
```bash
# Installed automatically by mobile coding setup script
./scripts/setup-mobile-coding.sh

# Or install manually
npm install -g clawdbot@latest
```

**Post-Install Setup**:
```bash
# 1. Install daemon
clawdbot onboard --install-daemon

# 2. Connect messaging channel
clawdbot channels login whatsapp  # Scan QR with phone

# 3. Enable Tailscale (uses your existing setup)
clawdbot tailscale serve
```

**Configuration**: `~/.clawdbot/clawdbot.json`
```json
{
  "agent": { "model": "anthropic/claude-sonnet-4-20250514" },
  "workspace": "~/clawd",
  "tailscale": { "mode": "serve" }
}
```

**Scheduled Tasks** (cron example):
```yaml
cron:
  jobs:
    - jobId: morning-brief
      schedule: { cron: "0 8 * * *" }
      payload:
        message: "Summarize my git activity and calendar for today"
      delivery:
        channel: whatsapp
        target: "+yourphone"
```

**Skills System**: Teach Claude about your dotfiles at `~/clawd/skills/dotfiles-manager/SKILL.md`

**Note**: Clawdbot complements (doesn't replace) your Termius workflow. Use Termius for development, Clawdbot for quick interactions and automation.

### Claude Code Plugins

Plugins are installed from three marketplaces:
- `anthropics/claude-code` (alias: `claude-code-plugins`) - Official Anthropic plugins
- `kenryu42/cc-marketplace` (alias: `cc-marketplace`) - Community safety plugins
- `antonbabenko/terraform-skill` (alias: `antonbabenko`) - Terraform/OpenTofu development skill

**Installation**: Plugins are stored in `~/.claude/settings.json` and available in all sessions on the device. For cross-device consistency, installation commands are in `scripts/setup.sh`.

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

**Managing Plugins**:
```bash
# Install a plugin
claude plugin install plugin-name@claude-code-plugins

# Disable a plugin (saves tokens for session hooks)
claude plugin disable explanatory-output-style@claude-code-plugins

# Enable a disabled plugin
claude plugin enable explanatory-output-style@claude-code-plugins

# Uninstall a plugin
claude plugin uninstall plugin-name@claude-code-plugins
```

**Token Cost Note**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks that increase token usage. Disable when not needed.

**Environment Variables** (set in `config.fish`):
| Variable | Value | Purpose |
|----------|-------|---------|
| `FORCE_AUTOUPDATE_PLUGINS` | `1` | Auto-update plugins on every session start |
| `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | `1` | Load CLAUDE.md from `--add-dir` paths (used by gwt-ticket) |

**Undocumented Settings** (`~/.claude.json`):
| Setting | Value | Purpose |
|---------|-------|---------|
| `teammateMode` | `"auto"` | Agent teams display mode: split panes in tmux, in-process otherwise |

These are set automatically by `scripts/setup.sh` using `jq` and `claude config set`.

**Auto-Compact**: Enabled (default). Previously disabled via `autoCompactEnabled: false` workaround for [#6689](https://github.com/anthropics/claude-code/issues/6689), but 2.1.21 fixed early triggering. Long ralph-loop sessions benefit from mid-session compaction.

### Claude Code Agent Teams (Experimental)

**Purpose**: Coordinate multiple Claude Code instances working together as a team with shared tasks, inter-agent messaging, and centralized management.

**Status**: Experimental (enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)

**How It Differs from Existing Workflows**:
| Capability | Our gwt-parallel | Agent Teams |
|-----------|-------------------|-------------|
| **Coordination** | Manual (separate tmux windows) | Built-in lead + teammates |
| **Communication** | None (independent sessions) | Peer-to-peer messaging + mailbox |
| **Task Management** | Per-session (ralph-loop) | Shared task list with dependencies |
| **Display** | Custom 3-pane layout | In-process or tmux split panes |
| **File Ownership** | Per-worktree isolation | Same repo, file-level ownership |

**Configuration** (set by `scripts/setup.sh` into `~/.claude/settings.json`):
```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "tmux"
}
```

**When to Use Agent Teams vs gwt-parallel**:
- **Agent Teams**: Same-repo work where teammates need to communicate (code review, competing hypotheses debugging, cross-layer features)
- **gwt-parallel**: Multi-branch isolated work where each agent works independently on separate features
- **gwt-ticket + ralph-loop**: Autonomous single-ticket execution with iteration

**Usage**:
```bash
# Tell Claude to create a team (natural language)
"Create an agent team to refactor the auth module. Spawn three teammates:
one for the backend API, one for the frontend hooks, one for tests."

# Navigate teammates
Shift+Up/Down    # Select teammate (in-process mode)
Shift+Tab        # Toggle delegate mode (lead coordinates only)
Ctrl+T           # Toggle task list

# Direct interaction with any teammate
Shift+Down → type message → Enter
```

**Best Practices**:
- Assign different files to different teammates to avoid conflicts
- Use delegate mode (`Shift+Tab`) to keep lead focused on coordination
- Provide specific context in spawn prompts (teammates don't inherit conversation history)
- Target 5-6 tasks per teammate for optimal productivity
- Start with research/review tasks before parallel implementation
- Always use lead for team cleanup

**Limitations**:
- No session resumption for in-process teammates
- One team per session, no nested teams
- Split panes require tmux (already configured) or iTerm2
- Higher token cost than subagents (each teammate is a separate Claude instance)
- Not supported in Ghostty's tmux integration

**Relationship to Gastown**: Claude Code Agent Teams is Anthropic's native implementation of multi-agent orchestration patterns similar to [Gastown](https://github.com/steveyegge/gastown). Key Gastown features NOT yet in Agent Teams: persistent work ledger (Beads), merge queue processing (Refinery), health monitoring daemon (Deacon/Daemon), agent CVs/capability matching, cross-project coordination. Consider Gastown for enterprise-scale multi-agent workflows requiring audit trails and automated health monitoring.

### Agent Teams (Experimental)

**Purpose**: Coordinate multiple Claude Code instances working as a team with shared tasks, inter-agent messaging, and centralized management.

**Reference**: https://code.claude.com/docs/en/agent-teams

**Status**: Experimental - enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var.

**Configuration**:
- **Env var**: Set in `.claude/settings.json` → `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`
- **Display mode**: Set in `~/.claude.json` → `teammateMode = "auto"` (auto-detects tmux for split panes)
- **CLI override**: `claude --teammate-mode in-process` for single-terminal mode

**Display Modes**:
| Mode | Description | Requirement |
|------|-------------|-------------|
| `auto` (default) | Split panes if tmux detected, in-process otherwise | tmux (already installed) |
| `in-process` | All teammates in main terminal, navigate with Shift+Up/Down | Any terminal |
| `tmux` | Each teammate in own pane | tmux or iTerm2 |

**Architecture**:
- **Team lead**: Main session that creates the team and coordinates work
- **Teammates**: Separate Claude Code instances working on assigned tasks
- **Task list**: Shared at `~/.claude/tasks/{team-name}/`
- **Team config**: Stored at `~/.claude/teams/{team-name}/config.json`

**Usage**:
```
Create an agent team to review this codebase from different angles:
- One teammate on security
- One on performance
- One on test coverage
```

**Key Controls**:
- `Shift+Up/Down` - Navigate between teammates (in-process mode)
- `Shift+Tab` - Toggle delegate mode (lead coordinates only, no coding)
- `Ctrl+T` - Toggle task list view

**Best Use Cases**:
- Parallel code review with different focus areas
- Debugging with competing hypotheses
- Cross-layer coordination (frontend + backend + tests)
- Research and investigation from multiple angles

**Not Recommended For**:
- Sequential tasks with many dependencies
- Same-file edits (causes conflicts)
- Simple tasks where coordination overhead exceeds benefit

**Limitations**:
- No session resumption with in-process teammates
- One team per session
- No nested teams (teammates can't spawn sub-teams)
- Split panes not supported in VS Code terminal or Ghostty
||||||| 4f0c32d
2. **Claude Code CLI**: Managed via `claude mcp add` commands in setup script
   - Located in `scripts/setup.sh` (Phase 4: Cloud & Infrastructure Tools)
   - Use `bunx` instead of `npx` (per hook requirements)
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx run` for other Python MCPs

**Adding New MCP Servers (Required Steps)**:
1. Add to Claude Desktop config (`claude_desktop_config.json`)
2. Add to setup script via `claude mcp add` command
3. Verify both configurations with:
   - Restart Claude Desktop app
   - Run `claude mcp list` to verify Claude Code CLI
4. Test MCP server functionality in both environments

**Browser-Based MCP Servers** (e.g., browser-tools, drawio):
- Require browser extension installation
- Add packages to Brewfile if needed
- Document manual browser extension installation steps
- Use version-specific packages when required (v1.1.0 for Claude Desktop, v1.2.0 for Claude Code)

**AWS MCP Servers**:
- Use `uvx awslabs.<server-name>@latest` command
- Add environment variables as needed (e.g., `FASTMCP_LOG_LEVEL`, `AWS_DOCUMENTATION_PARTITION`)
- Ensure GraphViz is installed for aws-diagram-mcp-server
- All AWS MCPs must be in both Claude Desktop and Claude Code CLI configs

**Python MCP Servers**:
- Install via `pipx` and configure with appropriate paths
- Use `pipx run mcp-server-<name>` in setup script

**API-based MCPs**:
- Add to config but disable by default
- Document API key requirements in comments
- Provide setup instructions for users who want to enable them

**MCP Parity Verification**:
```bash
# Verify Claude Code CLI MCPs
claude mcp list

# Check Claude Desktop config
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers | keys'
```

## Quality Assurance

### Before Committing Changes
- Verify setup script runs successfully on clean system
- Check that all new tools are properly integrated
- Ensure theme consistency across all applications
- Test stow operations complete without conflicts
- Validate Fish and Zsh configurations work correctly

### Troubleshooting Common Issues
- **Missing PATH**: Add to both Fish config and setup script
- **Theme Inconsistency**: Check Tokyo Night theme application
- **Plugin Failures**: Verify plugin managers are properly configured
- **Setup Script Failures**: Test on clean macOS installation
- **Stow Conflicts**: Resolve symlink conflicts before deployment

## Continuous Improvement

### Rule Evolution
- Update rules when new patterns emerge
- Deprecate outdated configurations
- Maintain compatibility with latest tool versions
- Document architectural decisions in this file
- Keep setup script updated with latest best practices

### Knowledge Management
- Maintain this file as the single source of truth
- Document new tools and their integration patterns
- Keep track of deprecated configurations
- Record solutions to common problems
- Update workflow documentation as processes evolve

### Kubernetes Manifests Management
- **ALWAYS** place Kubernetes manifest files in `scripts/manifests/` directory
- **ALWAYS** update `scripts/manifests/README.md` when adding new manifest files
- **ALWAYS** include in the README: filename, purpose, namespace, container details, usage, and use case
- **ALWAYS** use descriptive filenames for manifests (e.g., `test-shell-deployment.yaml` not `test.yaml`)

### Docker Container Testing for Linux Compatibility
- **Purpose**: Test dotfiles installation on Linux distributions without requiring a full VM
- **Location**: All testing infrastructure in `scripts/docker/` directory
- **Runtime**: Uses Colima (already installed) for container management

**Testing Workflow**:
1. **Start Colima**: `./scripts/docker/colima-setup.sh start`
2. **Build Test Image**: `docker build -f scripts/docker/dockerfiles/ubuntu.Dockerfile -t dotfiles-test:ubuntu .`
3. **Run Tests**: `docker run --rm dotfiles-test:ubuntu /home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh`
4. **Interactive Testing**: `docker run -it --rm dotfiles-test:ubuntu`

**What Gets Tested**:
- ✅ Package manager detection (apt/dnf/pacman)
- ✅ GNU Stow symlink operations
- ✅ Fish and Zsh shell configurations
- ✅ Environment variables (including BAT_PAGING fix)
- ✅ CLI tool configurations
- ✅ PATH configurations
- ⚠️ Homebrew packages (translated to Linux equivalents)
- ❌ macOS-specific tools (skipped)

**Key Files**:
- `scripts/docker/README.md` - Comprehensive testing documentation
- `scripts/docker/colima-setup.sh` - Colima management helper
- `scripts/docker/dockerfiles/ubuntu.Dockerfile` - Ubuntu 22.04 test environment
- `scripts/docker/scripts/run-all-tests.sh` - Main test orchestrator
- `scripts/docker/scripts/test-*.sh` - Individual test suites

**Best Practices**:
- **ALWAYS** test dotfiles changes in containers before deploying to production Linux
- **ALWAYS** start with Ubuntu tests (most common Linux distribution)
- **ALWAYS** verify stow operations complete successfully
- **ALWAYS** check shell configs load without errors
- **NEVER** skip testing when making cross-platform changes

**Development Mode**:
```bash
# Mount local dotfiles for live testing
docker run -it --rm -v ~/dotfiles:/home/testuser/dotfiles dotfiles-test:ubuntu
```

**Troubleshooting**:
- **Colima issues**: Run `./scripts/docker/colima-setup.sh restart`
- **Build failures**: Check `scripts/docker/.dockerignore` and rebuild with `--no-cache`
- **Test failures**: Review test output in `/tmp/dotfiles-test-results/*.log` inside container
- **BAT_PAGING errors**: Ensure the fix is in both `.config/fish/config.fish` and `.zshrc`

**Future Enhancements**:
- Multi-distribution support (Debian, Fedora, Arch, Alpine)
- Docker Compose for parallel multi-distro testing
- Automated Brewfile translation to Linux package managers
- CI/CD integration for continuous testing

### Mobile Coding Setup (Personal Devices Only)

**Purpose**: Enable remote development from mobile devices (phone/tablet) via Mosh + Tailscale.

**IMPORTANT**: This is a SEPARATE script from `setup.sh` to avoid installing remote access tools on work devices. Only run on personal machines.

**Setup Script**: `scripts/setup-mobile-coding.sh`

**What It Installs/Configures**:
- **Mosh**: Mobile shell with connection persistence (survives WiFi/cellular switches)
- **Tailscale**: Zero-config VPN (no port forwarding needed)
- **SSH**: Key-only authentication (works with 1Password)
- **Sleep**: Disabled for 24/7 accessibility
- **Firewall**: Opens Mosh UDP ports (60000-61000)
- **tmux**: Mobile-optimized session layout

**Usage**:
```bash
# Install (personal devices only!)
./scripts/setup-mobile-coding.sh

# With verbose output
./scripts/setup-mobile-coding.sh --verbose

# Uninstall everything
./scripts/setup-mobile-coding.sh --uninstall
```

**Phone Setup (after running script)**:
1. Install Tailscale app, sign in with same account
2. Install Termius app, create host with Tailscale hostname
3. Enable Mosh in Termius host settings
4. Import SSH key from 1Password into Termius
5. Connect and run: `tmux-mobile-session.sh`

**Mobile tmux Session**: `scripts/tmux/tmux-mobile-session.sh`
```
┌─────────────────────────────────┐
│          claude (main)          │  ← 70% height
├─────────────────────────────────┤
│    editor    │      shell       │  ← 30% height
└─────────────────────────────────┘
```

**Quick Access**: Add to `.tmux.conf`:
```bash
bind M run-shell '~/dotfiles/scripts/tmux/tmux-mobile-session.sh'
```
Then use: `prefix + M` to launch mobile session.

### Clawdbot AI Assistant (Optional)

**Purpose**: WhatsApp/Telegram interface to Claude on your Mac, complementing Termius + Claude Code workflow.

**Value Proposition**:
- Quick queries without opening Termius
- Voice messages to Claude while walking
- Photo → codebase-aware response
- Scheduled automation with delivery notifications
- Async tasks ("message me when done")

**Comparison with Termius**:
| Use Case | Best Tool |
|----------|-----------|
| Development work | Termius + Claude Code |
| Quick questions | Clawdbot (WhatsApp/Telegram) |
| Scheduled tasks | Clawdbot (cron jobs) |
| Voice/photo input | Clawdbot |

**Installation** (requires Node.js >= 22):
```bash
# Installed automatically by mobile coding setup script
./scripts/setup-mobile-coding.sh

# Or install manually
npm install -g clawdbot@latest
```

**Post-Install Setup**:
```bash
# 1. Install daemon
clawdbot onboard --install-daemon

# 2. Connect messaging channel
clawdbot channels login whatsapp  # Scan QR with phone

# 3. Enable Tailscale (uses your existing setup)
clawdbot tailscale serve
```

**Configuration**: `~/.clawdbot/clawdbot.json`
```json
{
  "agent": { "model": "anthropic/claude-sonnet-4-20250514" },
  "workspace": "~/clawd",
  "tailscale": { "mode": "serve" }
}
```

**Scheduled Tasks** (cron example):
```yaml
cron:
  jobs:
    - jobId: morning-brief
      schedule: { cron: "0 8 * * *" }
      payload:
        message: "Summarize my git activity and calendar for today"
      delivery:
        channel: whatsapp
        target: "+yourphone"
```

**Skills System**: Teach Claude about your dotfiles at `~/clawd/skills/dotfiles-manager/SKILL.md`

**Note**: Clawdbot complements (doesn't replace) your Termius workflow. Use Termius for development, Clawdbot for quick interactions and automation.

### Claude Code Plugins

Plugins are installed from three marketplaces:
- `anthropics/claude-code` (alias: `claude-code-plugins`) - Official Anthropic plugins
- `kenryu42/cc-marketplace` (alias: `cc-marketplace`) - Community safety plugins
- `antonbabenko/terraform-skill` (alias: `antonbabenko`) - Terraform/OpenTofu development skill

**Installation**: Plugins are stored in `~/.claude/settings.json` and available in all sessions on the device. For cross-device consistency, installation commands are in `scripts/setup.sh`.

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
| **claude-opus-4-5-migration** | Natural language | Model migration helper ("Migrate to Opus 4.5") |
| **explanatory-output-style** | SessionStart hook | Educational insights on implementation choices |
| **learning-output-style** | SessionStart hook | Interactive learning mode with code contribution prompts |
| **code-simplifier** | Auto-triggered | Identifies over-engineering, suggests simpler implementations |
| **security-guidance** | Auto-triggered | Security best practices, vulnerability detection, compliance guidance |
| **terraform-skill** | Auto-activated | Terraform/OpenTofu module development, testing frameworks, CI/CD workflows |

**Managing Plugins**:
```bash
# Install a plugin
claude plugin install plugin-name@claude-code-plugins

# Disable a plugin (saves tokens for session hooks)
claude plugin disable explanatory-output-style@claude-code-plugins

# Enable a disabled plugin
claude plugin enable explanatory-output-style@claude-code-plugins

# Uninstall a plugin
claude plugin uninstall plugin-name@claude-code-plugins
```

**Token Cost Note**: `explanatory-output-style` and `learning-output-style` add SessionStart hooks that increase token usage. Disable when not needed.

**Undocumented Settings** (`~/.claude.json`):
| Setting | Value | Purpose |
|---------|-------|---------|
| `autoCompactEnabled` | `false` | Disables automatic context compaction ([#6689](https://github.com/anthropics/claude-code/issues/6689)) |
| `teammateMode` | `"auto"` | Agent teams display mode: split panes in tmux, in-process otherwise |

These are set automatically by `scripts/setup.sh` using `jq` and `claude config set`.

### Claude Code Agent Teams (Experimental)

**Purpose**: Coordinate multiple Claude Code instances working together as a team with shared tasks, inter-agent messaging, and centralized management.

**Status**: Experimental (enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)

**How It Differs from Existing Workflows**:
| Capability | Our gwt-parallel | Agent Teams |
|-----------|-------------------|-------------|
| **Coordination** | Manual (separate tmux windows) | Built-in lead + teammates |
| **Communication** | None (independent sessions) | Peer-to-peer messaging + mailbox |
| **Task Management** | Per-session (ralph-loop) | Shared task list with dependencies |
| **Display** | Custom 3-pane layout | In-process or tmux split panes |
| **File Ownership** | Per-worktree isolation | Same repo, file-level ownership |

**Configuration** (set by `scripts/setup.sh` into `~/.claude/settings.json`):
```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "tmux"
}
```

**When to Use Agent Teams vs gwt-parallel**:
- **Agent Teams**: Same-repo work where teammates need to communicate (code review, competing hypotheses debugging, cross-layer features)
- **gwt-parallel**: Multi-branch isolated work where each agent works independently on separate features
- **gwt-ticket + ralph-loop**: Autonomous single-ticket execution with iteration

**Usage**:
```bash
# Tell Claude to create a team (natural language)
"Create an agent team to refactor the auth module. Spawn three teammates:
one for the backend API, one for the frontend hooks, one for tests."

# Navigate teammates
Shift+Up/Down    # Select teammate (in-process mode)
Shift+Tab        # Toggle delegate mode (lead coordinates only)
Ctrl+T           # Toggle task list

# Direct interaction with any teammate
Shift+Down → type message → Enter
```

**Best Practices**:
- Assign different files to different teammates to avoid conflicts
- Use delegate mode (`Shift+Tab`) to keep lead focused on coordination
- Provide specific context in spawn prompts (teammates don't inherit conversation history)
- Target 5-6 tasks per teammate for optimal productivity
- Start with research/review tasks before parallel implementation
- Always use lead for team cleanup

**Limitations**:
- No session resumption for in-process teammates
- One team per session, no nested teams
- Split panes require tmux (already configured) or iTerm2
- Higher token cost than subagents (each teammate is a separate Claude instance)
- Not supported in Ghostty's tmux integration

**Relationship to Gastown**: Claude Code Agent Teams is Anthropic's native implementation of multi-agent orchestration patterns similar to [Gastown](https://github.com/steveyegge/gastown). Key Gastown features NOT yet in Agent Teams: persistent work ledger (Beads), merge queue processing (Refinery), health monitoring daemon (Deacon/Daemon), agent CVs/capability matching, cross-project coordination. Consider Gastown for enterprise-scale multi-agent workflows requiring audit trails and automated health monitoring.

### Agent Teams (Experimental)

**Purpose**: Coordinate multiple Claude Code instances working as a team with shared tasks, inter-agent messaging, and centralized management.

**Reference**: https://code.claude.com/docs/en/agent-teams

**Status**: Experimental - enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var.

**Configuration**:
- **Env var**: Set in `.claude/settings.json` → `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"`
- **Display mode**: Set in `~/.claude.json` → `teammateMode = "auto"` (auto-detects tmux for split panes)
- **CLI override**: `claude --teammate-mode in-process` for single-terminal mode

**Display Modes**:
| Mode | Description | Requirement |
|------|-------------|-------------|
| `auto` (default) | Split panes if tmux detected, in-process otherwise | tmux (already installed) |
| `in-process` | All teammates in main terminal, navigate with Shift+Up/Down | Any terminal |
| `tmux` | Each teammate in own pane | tmux or iTerm2 |

**Architecture**:
- **Team lead**: Main session that creates the team and coordinates work
- **Teammates**: Separate Claude Code instances working on assigned tasks
- **Task list**: Shared at `~/.claude/tasks/{team-name}/`
- **Team config**: Stored at `~/.claude/teams/{team-name}/config.json`

**Usage**:
```
Create an agent team to review this codebase from different angles:
- One teammate on security
- One on performance
- One on test coverage
```

**Key Controls**:
- `Shift+Up/Down` - Navigate between teammates (in-process mode)
- `Shift+Tab` - Toggle delegate mode (lead coordinates only, no coding)
    - `Ctrl+T` - Toggle task list view

    **Best Use Cases**:
    - Parallel code review with different focus areas
    - Debugging with competing hypotheses
    - Cross-layer coordination (frontend + backend + tests)
    - Research and investigation from multiple angles

    **Not Recommended For**:
    - Sequential tasks with many dependencies
    - Same-file edits (causes conflicts)
    - Simple tasks where coordination overhead exceeds benefit

    **Limitations**:
    - No session resumption with in-process teammates
    - One team per session
    - No nested teams (teammates can't spawn sub-teams)
    - Split panes not supported in VS Code terminal or Ghostty

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
