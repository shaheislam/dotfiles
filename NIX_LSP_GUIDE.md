# Nix LSP Management Guide

## Overview

This guide explains how to use Nix as a replacement/complement to Mason for version-controlled, per-project LSP management in Neovim. With this setup, you can:

- **Pin exact LSP versions per project** - No more "works on my machine" issues
- **Share consistent environments** - Team members get identical LSP versions
- **Version control LSP configurations** - Track LSP versions in git via `flake.lock`
- **Instant environment switching** - direnv automatically loads project-specific LSPs
- **Keep Mason as fallback** - Gradual migration path from Mason to Nix

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Project Templates](#project-templates)
5. [Advanced Configuration](#advanced-configuration)
6. [Migration from Mason](#migration-from-mason)
7. [Troubleshooting](#troubleshooting)
8. [Reference](#reference)

## Quick Start

### Creating a New Project with Nix LSPs

```bash
# 1. Navigate to your project
cd ~/projects/my-app

# 2. Initialize a flake from template
nix-init-flake backend  # or devops, frontend, etc.

# 3. Enter the Nix environment
nix develop

# OR use direnv for automatic activation
direnv allow
```

Your Neovim will now automatically use the Nix-provided LSPs!

### Adding Nix to Existing Project

```bash
# Copy appropriate template
cp ~/dotfiles/nix/flake-templates/backend.nix flake.nix

# Edit flake.nix to customize for your project
nvim flake.nix

# Create .envrc for direnv
echo "use flake" > .envrc
direnv allow

# Commit to version control
git add flake.nix flake.lock .envrc
git commit -m "Add Nix development environment"
```

## Installation

The setup script automatically installs Nix. For manual installation:

```bash
# Install Nix (using Determinate Systems installer for better macOS support)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --no-confirm

# Restart your shell
exec fish

# Verify installation
nix --version
nix-status  # Custom Fish function to check status
```

## Basic Usage

### Fish Shell Commands

The Fish shell integration provides helpful commands:

```bash
# Check Nix environment status
nix-status

# List available LSPs in current environment
nix-lsps

# Initialize flake from template
nix-init-flake <template>  # default, devops, backend, frontend

# Quick Nix shell with packages
nix-shell-with nodejs python3 go

# Search for packages
nix-search <package-name>

# Update flake dependencies
nix-update

# Clean up Nix store
nix-clean
```

### Neovim Integration

The Neovim configuration automatically detects and uses Nix-provided LSPs:

1. **Check LSP status**: `<leader>ns` - Shows active LSP servers and their source
2. **List available LSPs**: `<leader>nl` - Shows which LSPs are available
3. **Enter Nix shell**: `<leader>nd` - Enter Nix develop shell from Neovim
4. **Update flake**: `<leader>nu` - Update flake.lock

### Directory Structure

```
project/
├── flake.nix          # Nix configuration with LSP versions
├── flake.lock         # Locked versions (commit this!)
├── .envrc             # direnv configuration
└── .git/
    └── ...
```

## Project Templates

### Available Templates

1. **default** - Basic development environment with common tools
2. **devops** - Terraform, Ansible, Kubernetes, Docker tools
3. **backend** - Go, Rust, Python with respective LSPs
4. **frontend** - TypeScript, React, Vue with modern tooling

### Template Structure

Each template includes:
- Language-specific LSPs
- Development tools and linters
- Build tools and package managers
- Testing frameworks
- Pre-configured environment variables

### Using Templates

```bash
# View available templates
ls ~/dotfiles/nix/flake-templates/

# Initialize from template
nix-init-flake devops

# Or manually copy
cp ~/dotfiles/nix/flake-templates/devops.nix flake.nix
```

### Customizing Templates

Edit `flake.nix` to add/remove packages:

```nix
devPackages = with pkgs; [
  # Add your packages here
  lspVersions.golang.stable
  terraform
  kubectl
  # Custom package
  your-package-here
];
```

## Advanced Configuration

### Multiple Development Shells

Create specialized shells in your `flake.nix`:

```nix
devShells = {
  default = pkgs.mkShell { ... };

  test = pkgs.mkShell {
    buildInputs = [ testing-tools ];
  };

  production = pkgs.mkShell {
    buildInputs = [ production-tools ];
  };
};
```

Use them with:
```bash
nix develop .#test      # Enter test shell
nix develop .#production # Enter production shell
```

### Pinning Specific LSP Versions

In `nix/lsp-versions.nix`, override versions:

```nix
golang = {
  stable = pkgs.gopls.overrideAttrs (oldAttrs: rec {
    version = "0.14.2";  # Specific version
    src = pkgs.fetchFromGitHub {
      owner = "golang";
      repo = "tools";
      rev = "gopls/v${version}";
      sha256 = "...";  # Get from error message
    };
  });
};
```

### Per-Directory Overrides

Create subdirectory-specific environments:

```
project/
├── flake.nix          # Root environment
├── frontend/
│   └── flake.nix      # Frontend-specific LSPs
└── backend/
    └── flake.nix      # Backend-specific LSPs
```

### CI/CD Integration

Use Nix in CI pipelines for consistent environments:

```yaml
# GitHub Actions example
- uses: cachix/install-nix-action@v22
- run: nix develop --command npm test
```

## Migration from Mason

### Hybrid Approach (Recommended)

1. **Keep Mason installed** - It remains as fallback
2. **Gradually add Nix** - Start with one project
3. **Neovim auto-detects** - Uses Nix LSP if available, Mason otherwise

### Migration Steps

1. **Identify current LSPs**:
```vim
:Mason
```

2. **Create flake.nix with same LSPs**:
```nix
buildInputs = with pkgs; [
  terraform-ls      # Instead of Mason's terraformls
  gopls            # Instead of Mason's gopls
  rust-analyzer    # Instead of Mason's rust_analyzer
];
```

3. **Test both work**:
```bash
# In Nix environment
nix develop
nvim test.go  # Should use Nix gopls

# Outside Nix environment
exit
nvim test.go  # Should use Mason gopls
```

4. **Disable Mason auto-install** (optional):
```lua
-- In mason-fix.lua
automatic_installation = false  -- Was true
```

### Advantages Over Mason

| Feature | Mason | Nix |
|---------|-------|-----|
| Version Control | ❌ Global state | ✅ In git via flake.lock |
| Team Consistency | ❌ Manual sync | ✅ Automatic |
| Rollback | ❌ Difficult | ✅ Git revert |
| Per-Project Versions | ❌ Single global | ✅ Different per project |
| CI/CD | ❌ Requires setup | ✅ Same as dev |
| Reproducibility | ❌ Best effort | ✅ Guaranteed |

## Troubleshooting

### Common Issues

**Nix command not found**
```bash
# Restart shell or source manually
exec fish
# Or
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
```

**"use flake" error with direnv**
```bash
# Ensure direnv is hooked to shell
direnv hook fish | source
# Add to ~/.config/fish/config.fish if not present
```

**LSP not detected by Neovim**
```bash
# Check if LSP is in PATH
which gopls

# Check Neovim LSP status
:LspInfo

# Force Neovim to reload
:LspRestart
```

**Flake evaluation errors**
```bash
# Check flake syntax
nix flake check

# Show detailed error
nix develop --show-trace
```

**Permission denied on /nix**
```bash
# Nix daemon not running (macOS)
sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
```

### Debugging Commands

```bash
# Check Nix environment variables
env | grep NIX

# List what's in current Nix environment
echo $PATH | tr ':' '\n' | grep nix

# Show flake information
nix flake show
nix flake metadata

# Garbage collection (free space)
nix-collect-garbage -d
nix-store --optimise
```

## Reference

### Environment Variables

- `IN_NIX_SHELL` - Set when in Nix shell
- `NIX_PATH` - Nix package search paths
- `NIX_LSP_ENABLED` - Custom flag for Neovim to prefer Nix LSPs

### File Locations

```
~/dotfiles/
├── nix/
│   ├── lsp-versions.nix       # LSP version registry
│   ├── flake-templates/       # Template flakes
│   │   ├── default.nix
│   │   ├── devops.nix
│   │   ├── backend.nix
│   │   └── frontend.nix
│   └── project-templates/     # Full project examples
│       ├── terraform-project/
│       ├── go-project/
│       ├── python-project/
│       └── nodejs-project/
├── .config/
│   ├── fish/conf.d/nix.fish  # Fish integration
│   └── nvim/lua/plugins/nix-lsp.lua  # Neovim integration
└── scripts/setup/setup-script.sh  # Auto-installation
```

### Useful Nix Commands

```bash
# Enter development shell
nix develop

# Run command in Nix shell
nix develop --command npm test

# Update all flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Show what would be built
nix build --dry-run

# Search for packages
nix search nixpkgs nodejs

# Get package info
nix eval nixpkgs#nodejs.version

# Shell with specific packages
nix shell nixpkgs#go nixpkgs#gopls

# Garbage collection
nix-collect-garbage -d

# Optimize store (dedup)
nix-store --optimise
```

### Links and Resources

- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)
- [Nixpkgs Search](https://search.nixos.org/packages)
- [Determinate Systems Installer](https://github.com/DeterminateSystems/nix-installer)
- [direnv Documentation](https://direnv.net/)
- [Zero to Nix Guide](https://zero-to-nix.com/)

## Summary

The Nix LSP management system provides:

1. **Version Control** - LSP versions tracked in git
2. **Reproducibility** - Identical environments across machines
3. **Flexibility** - Per-project LSP versions
4. **Simplicity** - Automatic with direnv
5. **Compatibility** - Works alongside Mason

Start with one project, experience the benefits, then gradually migrate others. The hybrid approach ensures you're never blocked while learning Nix.