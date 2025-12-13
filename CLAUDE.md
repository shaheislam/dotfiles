# Claude Code Rules for Dotfiles

> **Note**: This file extends the global DevOps rules in `~/.claude/CLAUDE.md`. Read both files for complete context.

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

## Dotfiles Project Memory Bank

### Project Overview
- **Purpose**: Personal macOS development environment configuration
- **Structure**: Modular dotfiles with stow-based symlinking and automated setup
- **Key Tools**: Fish shell, Neovim (LazyVim), tmux, Homebrew, various CLI tools
- **Theme**: Tokyo Night consistent across all applications

### Architecture
- **Package Management**: Homebrew with centralized Brewfile
- **Shell**: Fish as primary, Zsh as secondary with Oh My Zsh
- **Editor**: Neovim (managed separately in ~/neovim repository)
- **LSP Management**: Nix-based global LSPs via ~/dotfiles/nix/global
- **Terminal**: Multiple options (Ghostty, WezTerm, iTerm2)
- **Multiplexer**: tmux with extensive plugin system
- **Automation**: Comprehensive setup script for new installations

### Core Components
- **homebrew/**: Brewfile for package management
- **scripts/**: Setup and utility scripts
- **.config/**: Application configurations (fish, tmux, etc.)
- **nix/**: Nix flakes for global LSP management
- **Various dotfiles**: Shell configs, git config, tool configs

### Neovim Configuration
- **Location**: `~/neovim` (separate Git repository)
- **Symlink**: `~/.config/nvim` → `~/neovim` (manual symlink, not managed by stow)
- **Syncing**: Neovim config is version-controlled separately and cloned to all devices
- **LSP Config**: Located in `~/neovim/lua/plugins/lsp.lua`
- **IMPORTANT**: Dotfiles does NOT contain Neovim configuration - it only manages Nix LSP infrastructure

#### Manual Setup Steps (First-Time Installation)

**Automatic Setup** (if using setup script with `NVIM_REPO` environment variable):
```bash
NVIM_REPO=git@github.com:user/neovim.git ./scripts/setup.sh
```
The setup script will automatically:
- Clone the neovim repository to `~/neovim`
- Create the symlink `~/.config/nvim` → `~/neovim`
- Trust the mise configuration (`mise trust ~/neovim/mise.toml`)

**Manual Setup** (if setup script was not used):

1. **Retrieve SSH Keys from 1Password**:

   **Option A - Automated** (if 1Password CLI is configured):
   ```bash
   # Run the automated setup script
   ./scripts/setup/setup-1password-ssh-keys.sh
   # This will automatically retrieve keys, set permissions, and add to ssh-agent
   ```

   **Option B - Manual**:
   ```bash
   # Copy private key from 1Password to ~/.ssh/shaheislam-github
   # Set correct permissions (CRITICAL for SSH to work)
   chmod 600 ~/.ssh/shaheislam-github
   chmod 644 ~/.ssh/shaheislam-github.pub

   # Add key to SSH agent
   ssh-add ~/.ssh/shaheislam-github
   ```

2. **Clone Neovim Configuration**:
   ```bash
   git clone git@github.com:user/neovim.git ~/neovim

   # Create manual symlink (NOT managed by stow)
   ln -sf ~/neovim ~/.config/nvim
   ```

3. **Trust mise Configuration**:
   ```bash
   # Required for mise to use the Python version specified in mise.toml
   mise trust ~/neovim/mise.toml

   # Install the specified Python version
   mise install
   ```

4. **Bootstrap LazyVim Plugins**:
   ```bash
   # Open nvim - it will automatically bootstrap lazy.nvim and install all plugins
   nvim
   # Wait for lazy.nvim to clone itself and install all 70 plugins from lazy-lock.json
   ```

**Common Issues**:
- **"Permission denied (publickey)"**: SSH key permissions are wrong or key not added to ssh-agent
- **"E492: Not an editor command: Lazy"**: Symlink is incorrect or bootstrap didn't run
- **"mise ERROR: not trusted"**: Run `mise trust ~/neovim/mise.toml`
- **Neovim loads empty config**: Verify symlink with `readlink ~/.config/nvim` (should point to `/Users/[user]/neovim`)

### LSP Management
- **Global LSPs**: Defined in `~/dotfiles/nix/global/` (version registry in `nix/lsp-versions.nix`)
- **Auto-loading**: `~/.envrc` loads global environment via direnv
- **Inheritance**: All subdirectories of `~` inherit global LSPs automatically
- **Project Override**: Per-project `.envrc` files can override with project-specific LSP versions
- **Configuration**: Neovim LSP config in `~/neovim/lua/plugins/lsp.lua` detects and uses Nix-provided LSPs

## Development Standards

### Configuration Management
- **ALWAYS** add new packages to `homebrew/Brewfile`
- **ALWAYS** update `scripts/setup.sh` when adding new tools
- **ALWAYS** maintain consistent theming (Tokyo Night) across applications
- **ALWAYS** use Fish shell syntax for primary shell configurations
- **ALWAYS** include Zsh compatibility for broader system support

### Tool Integration Patterns
- **PATH Management**: Add new tool paths to both Fish and setup script
- **Plugin Management**: Use appropriate package managers (Fisher for Fish, TPM for tmux)
- **Font Requirements**: Ensure Nerd Fonts are available for icon support
- **Theme Consistency**: Apply Tokyo Night theme to all applicable tools

### File Organization Standards
- Application configs go in `.config/` subdirectories
- Shell configs at dotfiles root level
- Scripts in dedicated `scripts/` directory
- Package management in `homebrew/` directory
- Documentation and rules in repository root

## Development Workflow

### Before Making Changes
1. **ALWAYS** read existing configurations to understand current patterns
2. **ALWAYS** check if new tools require Brewfile additions
3. **ALWAYS** verify setup script needs updates for new dependencies
4. **ALWAYS** ensure changes maintain cross-tool consistency

### Implementation Process
1. Add packages to Brewfile if needed
2. Update setup script with new tool installation/configuration
3. Create or modify application configurations
4. Test configurations work correctly
5. Update documentation if new patterns are introduced

### After Implementation
1. **ALWAYS** verify setup script still works for fresh installations
2. **ALWAYS** check that stow operations complete successfully
3. **ALWAYS** ensure new configurations follow established patterns
4. **ALWAYS** test that theme consistency is maintained

## Common Patterns and Solutions

### Adding New CLI Tools
1. Add to `homebrew/Brewfile`
2. Add PATH configuration to Fish config if needed
3. Update `scripts/setup.sh` to include in automated setup
4. Add aliases/functions to Fish config if appropriate
5. Ensure Zsh compatibility in setup script

### Adding New GUI Applications
1. Add cask to `homebrew/Brewfile`
2. Add installation check to `scripts/setup.sh`
3. Create configuration files in appropriate `.config/` subdirectory
4. Apply Tokyo Night theme if supported

### Shell Configuration Updates
1. Update Fish config for primary shell experience
2. Ensure Zsh compatibility in setup script for broader support
3. Test both shells work correctly with new configurations
4. Maintain consistent aliases and functions across shells

### Plugin Management
- **Fish**: Use Fisher package manager, update config with plugin list
- **tmux**: Use TPM, update `.tmux.conf` with plugin definitions
- **Neovim**: Use LazyVim plugin system, follow LazyVim conventions

### Keyboard Remapping
- **Tool**: Karabiner-Elements (macOS-only, GUI-based configuration)
- **Configuration**: `.config/karabiner/karabiner.json` (managed via stow)
- **Primary Mapping**: Caps Lock ↔ Escape swap
- **Installation**: Via Brewfile cask
- **Setup**: Configuration is symlinked via stow, automatically applied by Karabiner-Elements
- **Management**: Edit via Karabiner-Elements GUI app or directly in `~/.config/karabiner/karabiner.json`
- **Note**: Karabiner-Elements runs as a background service, no LaunchAgent needed

### LSP (Language Server Protocol) Configuration

**Nix-Based LSP Inheritance System**:
- **ALWAYS** refer to `nix/README.md` for LSP architecture and inheritance patterns
- **ALWAYS** use Nix flakes for project-specific LSP versions (not Mason.nvim)
- **ALWAYS** test LSP inheritance with `scripts/test-lsp-inheritance.sh`
- **CRITICAL**: Three-tier system: Global baseline → Project override → Neovim detection

**Documentation Locations**:
- `nix/README.md` - Complete LSP inheritance architecture and patterns
- `nix/TESTING.md` - Step-by-step validation procedures for testing LSP isolation
- `nix/QUICK_START.md` - Quick reference for common LSP operations
- `nix/project-templates/` - Language-specific templates with validation guides
- `scripts/test-lsp-inheritance.sh` - Automated test suite for LSP inheritance

**Key Concepts**:
- **Global Baseline**: LSPs installed via home-manager/nix-env, available everywhere
- **Project Override**: Per-project LSP versions via flake.nix, activated by direnv
- **Isolation**: Different projects can use different LSP versions without conflicts
- **PATH Precedence**: Project LSPs naturally override global via Nix shell PATH

**Common Workflows**:
1. **Create Project with Custom LSP**: Use templates from `nix/project-templates/`
2. **Override LSP Version**: Add to project's flake.nix with different nixpkgs channel
3. **Test Multi-Project Setup**: Follow procedures in `nix/TESTING.md`
4. **Validate System**: Run `scripts/test-lsp-inheritance.sh`

### MCP Server Integration

**CRITICAL MCP Configuration Parity Rule**:
- **ALWAYS** ensure MCP servers are configured in BOTH Claude Desktop AND Claude Code CLI
- **ALWAYS** maintain parity between both configurations - any MCP added to one must be added to the other
- **ALWAYS** update both configurations simultaneously when adding/removing MCP servers
- **ALWAYS** verify parity with `claude mcp list` after making changes to Claude Desktop config

**MCP Configuration Locations**:
1. **Claude Desktop**: `~/dotfiles/Library/Application Support/Claude/claude_desktop_config.json`
   - Managed via stow symlink
   - Use `npx` or `bunx` commands for Node-based MCPs
   - Use `uvx` for Python-based AWS MCPs
   - Use `pipx` for other Python MCPs

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

### Recent Updates
- **2025-11-01**: Configured Opencode with transparent background using system theme (inherits terminal transparency)
- **2025-10-30**: Added Docker container testing framework for Linux compatibility validation
- **2025-10-30**: Fixed BAT_PAGING error in Fish and Zsh configs (prevents FZF preview file descriptor errors)
- **2025-01-26**: Aligned Fish and Zsh configurations for feature parity
- **2025-01-26**: Removed Powerlevel10k configs in favor of Starship-only setup
- **2025-10-05**: Added Kubernetes manifests directory with documentation requirements
