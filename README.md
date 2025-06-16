# Dotfiles

Personal macOS development environment configuration with Fish shell, tmux, Neovim (LazyVim), and comprehensive tooling.

## Quick Install

```bash
git clone --recurse-submodules https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/setup-script.sh
stow .
```

## Full Documentation

See [INSTALL.md](./INSTALL.md) for complete installation instructions, troubleshooting, and customization guide.

## Key Features

- **Modern Shell**: Fish with intelligent completions and plugins
- **Terminal Multiplexer**: tmux with custom key bindings (Ctrl-Space prefix)
- **Editor**: Neovim with LazyVim distribution
- **Package Management**: Homebrew with centralized Brewfile
- **Development Tools**: Complete toolchain for multiple languages
- **Consistent Theming**: Tokyo Night across all applications

## Directory Structure

```
~/dotfiles/
├── INSTALL.md           # Complete installation guide
├── .config/            # Application configurations
├── .tmux/              # Tmux plugins and configurations  
├── homebrew/Brewfile   # Package definitions
├── scripts/            # Setup and utility scripts
└── dotfiles            # Shell configs, git config, etc.
```

## Requirements

- macOS 14+
- Git
- Internet connection

The setup script handles all other dependencies automatically.