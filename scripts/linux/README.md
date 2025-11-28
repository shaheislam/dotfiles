# Linux Workspace Setup Scripts

Automated setup scripts for configuring Linux development environments (AWS workspaces, cloud VMs, etc.) with your dotfiles, Neovim, shells, and development tools.

## Overview

These scripts provide a distribution-agnostic way to set up your development environment on Linux systems, replicating your macOS dotfiles setup on:

- Amazon Linux 2 / 2023
- Ubuntu 20.04 / 22.04 / 24.04
- Red Hat Enterprise Linux / CentOS / Rocky / AlmaLinux
- Debian
- Arch Linux / Manjaro (experimental)

## Scripts

| Script | Purpose | Size |
|--------|---------|------|
| `bootstrap.sh` | Single-command installer that clones repo and runs setup | ~200 lines |
| `setup-aws-workspace.sh` | Main setup script orchestrating the entire installation | ~900 lines |
| `linux-packages.sh` | Distribution-agnostic package management abstraction | ~300 lines |
| `setup-neovim-linux.sh` | Neovim installation, configuration, and plugin setup | ~200 lines |
| `package-offline.sh` | Create portable offline installation package | ~400 lines |
| `install-offline.sh` | Offline installer for air-gapped systems | ~400 lines |

## Quick Start

### Prerequisites

**Minimum Requirements:**
- Git installed
- Bash 4.0+
- curl or wget
- Internet connectivity

**Optional:**
- sudo access (recommended for system package installation)
- Without sudo: scripts will fall back to Linuxbrew (user-space installation)

### One-Command Installation (Recommended)

The fastest way to get started is using the bootstrap script:

```bash
# Full setup with single command
curl -fsSL https://raw.githubusercontent.com/shaheislam/dotfiles/main/scripts/linux/bootstrap.sh | bash

# Or with wget
wget -qO- https://raw.githubusercontent.com/shaheislam/dotfiles/main/scripts/linux/bootstrap.sh | bash
```

**With Options:**
```bash
# Minimal installation
curl -fsSL https://raw.githubusercontent.com/shaheislam/dotfiles/main/scripts/linux/bootstrap.sh | bash -s -- --minimal

# Preview what would be installed (dry run)
curl -fsSL https://raw.githubusercontent.com/shaheislam/dotfiles/main/scripts/linux/bootstrap.sh | bash -s -- --dry-run

# Custom repository location
DOTFILES_REPO=https://github.com/shaheislam/dotfiles.git \
  curl -fsSL https://raw.githubusercontent.com/shaheislam/dotfiles/main/scripts/linux/bootstrap.sh | bash
```

**Environment Variables:**
- `DOTFILES_REPO` - Repository URL (default: your repo)
- `DOTFILES_DIR` - Installation directory (default: `~/dotfiles`)
- `DOTFILES_BRANCH` - Git branch (default: `main`)

### Manual Installation

```bash
# Clone dotfiles repository
git clone https://github.com/shaheislam/dotfiles.git ~/dotfiles

# Navigate to Linux scripts directory
cd ~/dotfiles/scripts/linux

# Make scripts executable
chmod +x *.sh

# Run full setup
./setup-aws-workspace.sh
```

### Offline Installation (No Internet Access)

For AWS workspaces without public internet access, use the offline installation method:

**Step 1: Create offline package (on internet-connected machine):**
```bash
cd ~/dotfiles/scripts/linux
./package-offline.sh
# Creates ~/dotfiles-offline.tar.gz (~50-100MB)
```

**Step 2: Transfer to workspace**

Use one of these methods:
- **Local drive mapping** - Copy via mounted drives (easiest)
- **S3 intermediary** - Upload to internal S3 bucket
- **SCP/SFTP** - Transfer via internal network
- **Copy/paste** - For smaller packages
- **USB drive** - If supported by your workspace

**Step 3: Install on workspace:**
```bash
tar xzf dotfiles-offline.tar.gz
cd dotfiles-offline
./install.sh
```

**📖 See [OFFLINE-INSTALL.md](OFFLINE-INSTALL.md) for detailed transfer methods and troubleshooting**

### Installation Modes

#### Full Setup (Default)
```bash
./setup-aws-workspace.sh
```
Installs everything: core tools, dev tools, shells, Neovim, tmux, AWS/K8s tools

#### Minimal Setup
```bash
./setup-aws-workspace.sh --minimal
```
Installs only core essentials: git, ripgrep, fzf, bat, shells, Neovim, tmux

#### Preview Mode (Dry Run)
```bash
./setup-aws-workspace.sh --dry-run
```
Shows what would be installed without making changes

#### Selective Installation
```bash
# Skip Neovim setup
./setup-aws-workspace.sh --skip-neovim

# Skip shell configuration
./setup-aws-workspace.sh --skip-shells

# Skip dotfiles symlinking
./setup-aws-workspace.sh --skip-stow

# Combine flags
./setup-aws-workspace.sh --minimal --skip-shells --dry-run
```

## What Gets Installed

### Core Tools
- **Version Control:** git
- **Build Tools:** build-essential (gcc, make, etc.)
- **Package Management:** stow (dotfiles), curl, wget, unzip
- **Modern CLI:** ripgrep, fd, fzf, bat, eza, zoxide
- **Multiplexer:** tmux with Tokyo Night theme
- **Prompt:** starship
- **Utilities:** direnv, htop, jq

### Development Tools (Standard Mode)
- **Node.js:** via nvm (LTS version) + pnpm
- **Python:** Python 3.11+ with pip, pipx, black, isort, ruff
- **Go:** Latest stable version
- **Rust:** via rustup with cargo

### AWS & Kubernetes Tools (Standard Mode)
- **AWS:** AWS CLI v2, session-manager-plugin
- **Kubernetes:** kubectl, helm

### Shells & Configuration
- **Fish:** Modern shell with Fisher plugin manager + 7 plugins
- **Zsh:** Oh My Zsh with plugins (fast-syntax-highlighting, autosuggestions, completions)
- **Prompt:** Starship (cross-shell)

### Neovim Setup
- **Editor:** Neovim (latest stable, built from source if needed)
- **Config:** Your personal neovim configuration repository
- **Plugins:** Lazy.nvim with automatic plugin installation
- **LSP Servers:** TypeScript, Python, Bash, YAML, JSON, HTML, CSS, Lua
- **Formatters:** Prettier, Black, Stylua

### Dotfiles
- Automated symlinking via GNU Stow
- Preserves existing files with `--adopt` flag
- Creates all necessary directories

## Installation Process

The setup script runs through 9 phases:

1. **Environment Detection**: Detects Linux distribution, package manager, sudo availability
2. **Core Packages**: Installs essential system tools and utilities
3. **CLI Utilities**: Installs modern CLI replacements (eza, zoxide, starship, etc.)
4. **Development Tools**: Installs language runtimes and toolchains
5. **AWS/K8s Tools**: Installs cloud and container orchestration tools
6. **Shell Setup**: Configures Fish and Zsh with plugins
7. **Neovim Setup**: Installs and configures Neovim with LSP servers
8. **tmux Setup**: Installs tmux with plugin manager
9. **Dotfiles Symlinking**: Uses stow to symlink all configurations
10. **Final Configuration**: Installs fonts, sets default shell, updates PATH

## Configuration

### Customizing Package Selection

Edit `linux-packages.sh` to add/remove packages:

```bash
install_cli_tools() {
    local cli_tools=(
        ripgrep
        fd
        fzf
        bat
        tmux
        htop
        jq
        # Add your packages here
    )
    install_packages "${cli_tools[@]}"
}
```

### Customizing Neovim Setup

Edit `setup-neovim-linux.sh` to change:

```bash
# Neovim version
NEOVIM_VERSION="stable"  # or "nightly" or "v0.9.5"

# Your Neovim config repository
NEOVIM_CONFIG_REPO="https://github.com/shaheislam/neovim.git"
```

### Sudo vs No-Sudo Installation

**With sudo** (recommended):
- Installs system packages via apt/yum/dnf
- Faster installation
- Better integration with system

**Without sudo**:
- Falls back to Linuxbrew (Homebrew for Linux)
- Slower installation (compiles from source)
- User-space installation only
- Requires more disk space

The script automatically detects sudo availability and adapts.

## Differences from macOS Setup

### What's Excluded
- ❌ Homebrew (replaced with native package managers)
- ❌ macOS GUI applications (WezTerm, Raycast, Aerospace, etc.)
- ❌ macOS-specific tmux plugins (`reattach-to-user-namespace`)
- ❌ macOS fonts management (uses Linux font directories)
- ❌ macOS system preferences

### What's Adapted
- ✅ Package managers: apt/yum/dnf instead of Homebrew
- ✅ Font installation: `~/.local/share/fonts/` instead of macOS paths
- ✅ Binary installations: Direct downloads for tools not in repos
- ✅ PATH management: `~/.bashrc` instead of macOS shell profiles

### What's Identical
- ✅ Neovim configuration
- ✅ Fish/Zsh configurations
- ✅ tmux configuration (except macOS-specific plugins)
- ✅ Git configuration
- ✅ All `.config/` application configurations
- ✅ Starship prompt configuration

## Troubleshooting

### Permission Denied Errors

```bash
# Make scripts executable
chmod +x scripts/linux/*.sh
```

### Package Not Found

If a package is not available in your distribution's repositories:

1. Script will attempt to install from binary releases
2. Or skip with a warning
3. You can install manually later

### Stow Conflicts

If stow reports conflicts:

```bash
# Backup existing files
mkdir -p ~/.dotfiles-backup
mv ~/.config/nvim ~/.dotfiles-backup/

# Re-run stow
cd ~/dotfiles
stow . --adopt --verbose
```

### Neovim Build Fails

If building Neovim from source fails:

```bash
# Install build dependencies
# Ubuntu/Debian
sudo apt-get install -y cmake gcc g++ ninja-build gettext

# Amazon Linux/RHEL
sudo yum install -y cmake gcc gcc-c++ ninja-build gettext

# Try building again
cd scripts/linux
./setup-neovim-linux.sh
```

### No sudo Access

The scripts will automatically fall back to Linuxbrew if sudo is not available:

```bash
# Linuxbrew will be installed automatically
# Installation will take longer (compiles from source)
# ~2-3GB additional disk space required
```

### Fish Not Set as Default Shell

If Fish wasn't set as default shell:

```bash
# Check if Fish is in /etc/shells
grep fish /etc/shells

# If not, add it (requires sudo)
which fish | sudo tee -a /etc/shells

# Change default shell
chsh -s $(which fish)

# Log out and back in
```

## Manual Steps After Installation

### 1. Tmux Plugin Installation

```bash
# Start tmux
tmux

# Press Ctrl-s (prefix) + I (capital i)
# Wait for plugins to install
```

### 2. Neovim Plugin Installation

```bash
# Start Neovim
nvim

# Lazy.nvim will automatically install plugins
# Wait for completion (takes 1-2 minutes)
```

### 3. Configure AWS Credentials

```bash
# If you installed AWS CLI
aws configure

# Or use AWS SSO
aws configure sso
```

### 4. Verify Installation

```bash
# Check installed tools
fish --version
nvim --version
tmux -V
starship --version
kubectl version --client
aws --version

# Check shell configuration
fish -c "echo \$PATH"

# Check stow links
ls -la ~/.config/fish
ls -la ~/.config/nvim
```

## Environment Variables

The scripts set up the following in your shell profiles:

```bash
# Node.js (via nvm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Go
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Rust
source "$HOME/.cargo/env"

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# Linuxbrew (if no sudo)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

## Performance Notes

### Installation Time

| Mode | Time | Notes |
|------|------|-------|
| Minimal | 5-10 min | Core tools only |
| Standard | 15-25 min | Full dev environment |
| No-sudo | 25-40 min | Linuxbrew compiles from source |

### Disk Space Required

| Mode | Space | Notes |
|------|-------|-------|
| Minimal | ~500 MB | Essential tools |
| Standard | ~2 GB | Full toolchain |
| No-sudo | ~4 GB | Includes Linuxbrew |

## Advanced Usage

### Running Individual Phases

```bash
# Source the package manager functions
source scripts/linux/linux-packages.sh

# Run specific install functions
install_cli_utilities
install_development_tools
```

### Custom Package Lists

Create custom installation functions in `linux-packages.sh`:

```bash
install_my_custom_tools() {
    local tools=(
        tool1
        tool2
        tool3
    )
    install_packages "${tools[@]}"
}
```

### Building Neovim with Specific Version

```bash
# Edit setup-neovim-linux.sh
NEOVIM_VERSION="v0.9.5"  # specific version
# or
NEOVIM_VERSION="nightly"  # bleeding edge

# Run setup
./setup-neovim-linux.sh
```

## Contributing

If you find issues or have improvements:

1. Test on your Linux distribution
2. Update the appropriate script
3. Add notes to this README for distribution-specific quirks
4. Submit a pull request

## Common Issues by Distribution

### Amazon Linux 2023
- Uses `dnf` package manager
- Most packages available in standard repos
- May need EPEL for some tools

### Ubuntu 24.04
- Uses `apt` package manager
- Excellent package availability
- `eza` available in main repos

### RHEL/CentOS 8+
- Uses `dnf` package manager
- May need EPEL and PowerTools repos
- Some tools require binary installation

## Support

For issues specific to these Linux setup scripts:
1. Check this README's troubleshooting section
2. Review script output for specific error messages
3. Check `/tmp/linux-setup.log` if generated
4. Verify your distribution is supported

## License

Same as parent dotfiles repository.
