# Unified Cross-Platform Dotfiles Setup

Universal setup system that works seamlessly on macOS and Linux with flexible profiles and deployment modes.

## Quick Start

```bash
# Auto-detect everything, use standard profile
./scripts/setup.sh

# Minimal installation
./scripts/setup.sh --profile minimal

# Full installation with all tools
./scripts/setup.sh --profile comprehensive

# Preview changes without executing
./scripts/setup.sh --profile dev --dry-run

# Automated installation (no prompts)
./scripts/setup.sh --profile minimal --no-confirm

# Locked-down laptop setup without host sudo
./scripts/setup.sh --no-sudo
```

## Architecture

### Directory Structure

```
scripts/
├── setup.sh                 # Universal entry point
├── lib/                     # Core library modules
│   ├── common.sh           # Shared utilities
│   ├── package-manager.sh  # Abstract package manager interface
│   ├── binary-installer.sh # Cross-platform binary installation
│   ├── shell-setup.sh      # Shell configuration
│   └── dotfiles-manager.sh # Stow-based symlinking
├── os/                      # OS-specific implementations
│   ├── macos/
│   │   └── package-manager.sh  # Homebrew implementation
│   └── linux/
│       └── package-manager.sh  # apt/yum/dnf/pacman support
└── profiles/                # Installation profiles
    ├── minimal.conf
    ├── standard.conf
    ├── comprehensive.conf
    ├── dev.conf
    └── ops.conf
```

### Design Principles

1. **Abstract Interface Pattern**: Common API with OS-specific implementations
2. **Profile-Based Configuration**: Flexible installation profiles
3. **Architecture Detection**: Automatic CPU architecture handling (x86_64, ARM64)
4. **Idempotent Operations**: Safe to run multiple times
5. **Resumable Installation**: State management with phase tracking
6. **Comprehensive Logging**: Detailed logs in ~/.dotfiles-setup/logs/

## Installation Profiles

### minimal
Fastest setup with essential tools only
- Core: git, curl, wget, stow
- CLI: ripgrep, fd, fzf
- **Use case**: Quick setup, CI/CD environments

### standard (default)
Balanced installation for daily use
- Everything in minimal
- Shells: fish, zsh, starship
- Development: nodejs (via nvm), python
- **Use case**: General development work

### comprehensive
Full installation with all available tools
- Everything in standard
- Languages: go, rust (via rustup)
- Cloud: awscli, kubectl, helm, terraform, docker
- Editors: neovim
- **Use case**: Complete workstation setup

### dev
Development-focused configuration
- Core tools + all language runtimes
- Development tools and debuggers
- **Use case**: Software development

### ops
DevOps/SRE focused toolset
- Cloud tools and CLI utilities
- Container and orchestration tools
- Infrastructure as code tools
- **Use case**: Operations and infrastructure work

## Command-Line Options

### Profile Selection
```bash
--profile <name>    # Choose installation profile
                    # Options: minimal, standard, comprehensive, dev, ops
                    # Default: standard
```

### OS Override
```bash
--os <type>         # Force OS type (auto-detected by default)
                    # Options: auto, macos, linux
                    # Default: auto
```

### Installation Mode
```bash
--mode <mode>       # Installation mode
                    # Options: auto, online, offline
                    # Default: auto
```

### Operation Modes
```bash
--dry-run           # Preview actions without executing
--no-confirm        # Skip confirmation prompts (for automation)
--no-sudo           # Never run host sudo; skip or warn for privileged steps
--verbose           # Show detailed output and debug information
```

### Skip Options
```bash
--skip-packages     # Skip package installation phase
--skip-dotfiles     # Skip dotfiles symlinking phase
--skip-shells       # Skip shell configuration phase
--skip-fonts-apps   # Skip macOS fonts and GUI applications phase
```

## No-Sudo Mode

Use `./scripts/setup.sh --no-sudo` or the Fish helper `dotsetup-nosudo` on managed laptops where sudo is unavailable. Homebrew must already work from the user account; setup will not run the official Homebrew installer in this mode.

No-sudo mode keeps the user-space parts of setup: Homebrew CLI tooling, stow-managed dotfiles, shell configuration, tmux, Neovim, and user-space agent tooling.

No-sudo mode skips or warns for privileged system changes: macOS fonts/apps, Command Line Tools auto-update, the OpenJDK `/Library/Java` system symlink, Nix daemon system config, Linux Pulse Redis systemd startup, and the optional self-hosted LLM installer.

### Help
```bash
-h, --help          # Show help message with examples
```

## Usage Examples

### Development Setup
```bash
# Full development environment
./scripts/setup.sh --profile dev

# Development setup with preview
./scripts/setup.sh --profile dev --dry-run

# Skip package installation, only configure shells
./scripts/setup.sh --profile dev --skip-packages
```

### Server Setup
```bash
# Minimal server setup
./scripts/setup.sh --profile minimal --no-confirm

# Operations tools only
./scripts/setup.sh --profile ops
```

### Testing
```bash
# Test on specific OS
./scripts/setup.sh --os linux --dry-run

# Verbose output for debugging
./scripts/setup.sh --profile minimal --verbose
```

### CI/CD Integration
```bash
# Automated minimal setup
./scripts/setup.sh --profile minimal --no-confirm --verbose

# Skip prompts and configure verbosely
PROFILE=minimal ./scripts/setup.sh --no-confirm --verbose
```

## Installation Phases

The setup runs in 8 phases, each tracked for resumability:

1. **Core Packages**: Essential system tools (git, curl, wget)
2. **CLI Tools**: Modern CLI replacements (ripgrep, fd, eza, bat)
3. **Development**: Language runtimes (Node.js, Python, Go, Rust)
4. **Cloud Tools**: AWS CLI, kubectl, helm, terraform
5. **Editors**: Neovim, vim
6. **Multiplexer**: tmux with TPM
7. **Shells**: Fish with Fisher, Zsh with Oh My Zsh, Starship
8. **Dotfiles**: Stow-based symlinking

## Package Manager Support

### macOS
- **Primary**: Homebrew
- **Features**: Automatic installation, Cask support, ARM64 detection

### Linux
- **apt** (Debian/Ubuntu)
- **yum/dnf** (RHEL/CentOS/Fedora/Amazon Linux)
- **pacman** (Arch/Manjaro)
- **Features**: Automatic detection, sudo handling, package name mapping

## Architecture Support

- **x86_64**: Intel/AMD 64-bit
- **arm64/aarch64**: Apple Silicon, ARM 64-bit servers
- **armv7**: ARM 32-bit (limited support)

## Creating Custom Profiles

Create a new profile file in `scripts/profiles/`:

```ini
# custom.conf

[core]
git=true
curl=true
wget=true
stow=true

[cli_tools]
ripgrep=true
fd=true
fzf=true
bat=true
eza=true

[shells]
fish=true
starship=true

[development]
nodejs=true
python=true

[cloud]
awscli=true
kubectl=true
```

Use it:
```bash
./scripts/setup.sh --profile custom
```

## Troubleshooting

### View Logs
```bash
# Latest log
ls -t ~/.dotfiles-setup/logs/ | head -1

# View latest log
tail -f ~/.dotfiles-setup/logs/$(ls -t ~/.dotfiles-setup/logs/ | head -1)
```

### Resume Failed Installation
The setup automatically resumes from the last successful phase. Just run the command again:
```bash
./scripts/setup.sh --profile <same-profile>
```

### Reset Installation State
```bash
rm -rf ~/.dotfiles-setup/state
./scripts/setup.sh --profile <profile>
```

### Package Manager Issues
```bash
# macOS: Ensure Homebrew is working
brew doctor

# Linux: Update package cache manually
# apt
sudo apt-get update

# yum/dnf
sudo yum check-update

# pacman
sudo pacman -Sy
```

### Binary Installation Failures
If binary installations fail, packages may be available through the system package manager. The setup will continue with available packages.

## Environment Variables

```bash
PROFILE=minimal         # Set default profile
NO_CONFIRM=true        # Skip confirmations
VERBOSE=true           # Enable verbose output
SKIP_PACKAGES=true     # Skip package installation
SKIP_DOTFILES=true     # Skip dotfiles symlinking
SKIP_SHELLS=true       # Skip shell configuration
```

Use them:
```bash
PROFILE=comprehensive VERBOSE=true ./scripts/setup.sh
```

## Backward Compatibility

Legacy scripts are preserved with compatibility wrappers:

```bash
# Old macOS setup (redirects to unified setup.sh)
./scripts/setup-compat.sh

# Old Linux setup (redirects to unified setup.sh)
./scripts/linux/setup-aws-workspace-compat.sh
```

## Migration from Old Scripts

If you were using the old setup scripts:

### macOS Users
```bash
# New unified way
./scripts/setup.sh --os macos
# or simply (auto-detects OS)
./scripts/setup.sh
```

### Linux Users
```bash
# Old way
./scripts/linux/setup-aws-workspace.sh

# New way
./scripts/setup.sh --os linux
# or simply
./scripts/setup.sh  # auto-detects Linux
```

## Advanced Features

### Offline Installation (Coming Soon)
For air-gapped environments:
```bash
# Create offline bundle (on internet-connected machine)
./scripts/create-offline-bundle.sh

# Transfer bundle to target machine

# Install from bundle
./scripts/setup.sh --mode offline --offline-package ~/bundle.tar.gz
```

### Custom Package Name Mapping
Edit OS-specific package managers to add custom mappings:
- macOS: `scripts/os/macos/package-manager.sh`
- Linux: `scripts/os/linux/package-manager.sh`

## Contributing

When adding new tools or features:

1. Add package to appropriate profile (`scripts/profiles/*.conf`)
2. Update package name mappings if needed (OS-specific package managers)
3. Add binary URL if not in package managers (`scripts/lib/binary-installer.sh`)
4. Test on both macOS and Linux if possible
5. Update documentation

## Support

- **Repository**: https://github.com/shaheislam/dotfiles
- **Issues**: File issues in the GitHub repository
- **Logs**: Check `~/.dotfiles-setup/logs/` for detailed error information

## License

This setup system is part of the shaheislam/dotfiles repository.
