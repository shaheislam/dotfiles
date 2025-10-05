# Claude Code Rules for Dotfiles

> **Note**: This file extends the global DevOps rules in `~/.claude/CLAUDE.md`. Read both files for complete context.

## Core Development Principles

### 1. Setup Script Compatibility
- **ALWAYS** check if `scripts/setup-script.sh` requires modification when adding new tools, packages, or configurations
- **ALWAYS** verify new dependencies are included in the Brewfile and setup script
- **ALWAYS** test setup script changes for compatibility with fresh macOS installations
- **ALWAYS** ensure PATH configurations are added to both Fish and Zsh configs in setup script

### 2. File Location Constraints
- **NEVER** create or modify files outside of `~/dotfiles` directory
- **ALWAYS** keep all configurations within the dotfiles repository structure
- **ALWAYS** use relative paths within the dotfiles directory structure
- **ALWAYS** ensure all tools and configs can be installed via stow or setup script
- **CRITICAL**: The tmux configuration must ONLY exist at `~/dotfiles/.tmux.conf` - NEVER create tmux.conf in `.config/tmux/` or any other location to avoid conflicts

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
- **Editor**: Neovim with LazyVim distribution
- **Terminal**: Multiple options (Ghostty, WezTerm, iTerm2)
- **Multiplexer**: tmux with extensive plugin system
- **Automation**: Comprehensive setup script for new installations

### Core Components
- **homebrew/**: Brewfile for package management
- **scripts/**: Setup and utility scripts
- **.config/**: Application configurations (fish, nvim, tmux, etc.)
- **Various dotfiles**: Shell configs, git config, tool configs

## Development Standards

### Configuration Management
- **ALWAYS** add new packages to `homebrew/Brewfile`
- **ALWAYS** update `scripts/setup-script.sh` when adding new tools
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
3. Update `scripts/setup-script.sh` to include in automated setup
4. Add aliases/functions to Fish config if appropriate
5. Ensure Zsh compatibility in setup script

### Adding New GUI Applications
1. Add cask to `homebrew/Brewfile`
2. Add installation check to `scripts/setup-script.sh`
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
   - Located in `scripts/setup/setup-script.sh` (line 676+)
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

### Recent Updates
- **2025-01-26**: Aligned Fish and Zsh configurations for feature parity
- **2025-01-26**: Removed Powerlevel10k configs in favor of Starship-only setup
- **2025-10-05**: Added Kubernetes manifests directory with documentation requirements
