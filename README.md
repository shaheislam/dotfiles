# Dotfiles

Personal macOS development environment configuration with Fish shell, tmux, Neovim (LazyVim), and comprehensive tooling.

## Quick Start

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/yourusername/dotfiles.git ~/dotfiles

# Run automated setup
cd ~/dotfiles
./scripts/setup-script.sh

# Create symlinks
stow .
```

## Prerequisites

- macOS (tested on macOS 14+)
- Git
- Internet connection
- Admin privileges for Homebrew installation

## Detailed Installation Steps

### 1. Clone Repository

Choose one of these methods:

**Method A: Clone with submodules (recommended)**
```bash
git clone --recurse-submodules https://github.com/yourusername/dotfiles.git ~/dotfiles
```

**Method B: Clone then initialize submodules**
```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
git submodule update --init --recursive
```

### 2. Run Setup Script

The setup script handles all dependencies and configurations:

```bash
cd ~/dotfiles
./scripts/setup-script.sh
```

**What the setup script does:**
- Installs Homebrew (if not present)
- Installs packages from `homebrew/Brewfile`
- Sets up Fish shell and plugins via Fisher
- Installs and configures tmux plugins
- Applies tmux-continuum debug fix
- Builds tmux-fingers plugin (requires Crystal)
- Configures development tools (fzf, vim-plug, etc.)
- Sets up Node.js formatters

### 3. Create Symlinks

Use GNU Stow to create symbolic links:

```bash
stow .
```

This creates symlinks from `~/dotfiles` to your home directory.

### 4. Post-Installation Setup

#### Shell Configuration
```bash
# Set Fish as default shell
chsh -s /opt/homebrew/bin/fish

# Restart terminal or source configurations
exec fish
```

#### Tmux Plugin Installation
Start tmux and install plugins:
```bash
tmux
# Press: Ctrl-Space + I (capital i)
```

#### Neovim Setup
First time opening Neovim will install plugins automatically:
```bash
nvim
# Wait for LazyVim to install all plugins
```

## Manual Steps (If Needed)

### Fix tmux-continuum Debug Output
If you see debug output in tmux:
```bash
./scripts/fix_tmux_continuum.sh
```

### Build tmux-fingers Plugin
If tmux-fingers isn't working:
```bash
./scripts/build_tmux_fingers.sh
```

### Update tmux Plugins
```bash
# In tmux session
# Press: Ctrl-Space + U
```

## Verification

Test that everything is working:

```bash
# Check shell
echo $SHELL  # Should show fish path

# Check tmux
tmux list-sessions  # Should work without errors

# Check key bindings in tmux
# Press: Ctrl-Space + ? (shows help)
# Press: Ctrl-Space + F (tmux-fingers mode)

# Check Neovim
nvim --version  # Should show recent version
```

## Troubleshooting

### Common Issues

**1. Homebrew Installation Fails**
```bash
# Manually install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. tmux Plugins Not Working**
```bash
# Manually install TPM
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# In tmux, press: Ctrl-Space + I
```

**3. Fish Plugins Missing**
```bash
# Reinstall Fisher
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher update
```

**4. Stow Conflicts**
```bash
# Remove conflicting files first
rm ~/.gitconfig ~/.tmux.conf  # etc.
stow .
```

**5. tmux-fingers Not Building**
```bash
# Check Crystal installation
brew install crystal
cd ~/.tmux/plugins/tmux-fingers
make clean && make
```

## Directory Structure

```
~/dotfiles/
├── .config/          # Application configurations
├── .tmux/            # Tmux configurations and plugins
├── homebrew/         # Brewfile for package management
├── scripts/          # Setup and utility scripts
├── .gitconfig        # Git configuration
├── .tmux.conf        # Tmux configuration
└── various dotfiles  # Shell configs, etc.
```

## Key Features

- **Fish Shell**: Modern shell with auto-completion
- **tmux**: Terminal multiplexer with custom plugins
- **Neovim**: LazyVim distribution with LSP support
- **Development Tools**: Complete toolchain for multiple languages
- **Consistent Theming**: Tokyo Night theme across applications

## Customization

- **Shell aliases**: Edit `.config/fish/config.fish`
- **tmux bindings**: Edit `.tmux.conf`
- **Editor settings**: See `.config/nvim/`
- **New packages**: Add to `homebrew/Brewfile`

## Updates

```bash
# Update dotfiles
cd ~/dotfiles
git pull

# Update submodules
git submodule update --remote --recursive

# Update Homebrew packages
brew update && brew upgrade

# Update tmux plugins
# In tmux: Ctrl-Space + U
```

## CI/CD & Automation

![CI Status](https://github.com/yourusername/dotfiles/workflows/Dotfiles%20CI/badge.svg)
![Setup Test](https://github.com/yourusername/dotfiles/workflows/Setup%20Script%20Test/badge.svg)
![Weekly Maintenance](https://github.com/yourusername/dotfiles/workflows/Weekly%20Maintenance/badge.svg)

This repository includes comprehensive GitHub Actions workflows for quality assurance and automation:

### Continuous Integration (`ci.yml`)
- **Configuration Validation**: JSON, YAML, shell script syntax checking
- **Security Scanning**: Detects exposed secrets and vulnerabilities
- **Documentation Checks**: Markdown validation and broken link detection
- **Cross-Platform Testing**: Tests on macOS and Ubuntu

### Setup Testing (`setup-test.yml`)
- **Fresh Installation Tests**: Validates setup script on clean macOS environments
- **Compatibility Testing**: Tests on both Intel and Apple Silicon Macs
- **Symlink Verification**: Ensures all configurations link correctly
- **Installation Reports**: Generates detailed installation logs

### Weekly Maintenance (`weekly-maintenance.yml`)
- **Dependency Updates**: Checks for outdated Homebrew packages
- **Security Audits**: Scans for vulnerabilities in dependencies
- **Cleanup Reports**: Identifies large files and broken symlinks
- **Auto-PR Creation**: Creates PRs for necessary updates

### PR Validation (`pr-validation.yml`)
- **Code Formatting**: Enforces consistent formatting standards
- **Commit Message Validation**: Ensures conventional commit format
- **Compatibility Checks**: Validates POSIX compliance
- **Security Review**: CodeQL analysis and secret detection

### Sync & Deploy (`sync.yml`)
- **Release Bundles**: Creates downloadable dotfiles packages
- **Change Validation**: Tests critical file modifications
- **Sync Notifications**: Reminds to sync changes across machines

### Running Workflows Locally

Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act
brew install act

# Run CI workflow
act -W .github/workflows/ci.yml

# Run specific job
act -j validate-configs

# Run with specific event
act pull_request
```

### Workflow Badges

Add these badges to show workflow status:

```markdown
![CI](https://github.com/yourusername/dotfiles/workflows/Dotfiles%20CI/badge.svg)
![Setup](https://github.com/yourusername/dotfiles/workflows/Setup%20Script%20Test/badge.svg)
```

## Support

For issues or questions:
1. Check this troubleshooting section
2. Review setup script output for errors
3. Check individual component documentation
4. Verify prerequisites are met

---

**Note**: This setup is optimized for macOS development environments. Some configurations may need adjustment for other systems.
