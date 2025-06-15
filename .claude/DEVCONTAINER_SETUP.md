# Devcontainer Setup Todo List

Based on analysis of dotfiles, here's what needs to be implemented for a comprehensive base devcontainer:

## Core Devcontainer Features
- [ ] Add Node.js (LTS) feature
- [ ] Add Python 3.11 feature  
- [ ] Add Go latest feature
- [ ] Add Rust latest feature
- [ ] Add Git feature
- [ ] Add GitHub CLI feature
- [ ] Add Docker-outside-of-Docker feature
- [ ] Add kubectl/helm feature
- [ ] Add Terraform feature
- [ ] Add AWS CLI feature
- [ ] Add Azure CLI feature
- [ ] Add Fish shell feature
- [ ] Add Starship prompt feature
- [ ] Add Neovim feature
- [ ] Add Homebrew feature
- [ ] Add common-utils feature (with zsh)

## Custom Tools Installation
- [ ] Install eza (modern ls replacement)
- [ ] Install bat (cat with syntax highlighting)
- [ ] Install fd (find replacement)
- [ ] Install ripgrep (grep replacement)
- [ ] Install fzf (fuzzy finder)
- [ ] Install zoxide (cd replacement)
- [ ] Install bottom (top replacement)
- [ ] Install lazygit (git TUI)
- [ ] Install lazydocker (docker TUI)
- [ ] Install fastfetch (system info)
- [ ] Install onefetch (git repo info)
- [ ] Install git-delta (enhanced git diff)
- [ ] Install direnv (environment management)
- [ ] Install mise or asdf (version manager)

## Font Installation
- [ ] Install JetBrains Mono Nerd Font
- [ ] Install Fira Code Nerd Font
- [ ] Install Hack Nerd Font
- [ ] Install Iosevka Nerd Font

## Configuration Files to Copy
- [ ] Copy `.config/fish/config.fish` and fish plugins
- [ ] Copy `.config/starship.toml`
- [ ] Copy entire `.config/nvim/` directory (LazyVim setup)
- [ ] Copy `.tmux.conf` and tmux plugins
- [ ] Copy `.zshrc` configuration
- [ ] Copy `.config/vscode/settings.json` (if needed)
- [ ] Copy `.gitconfig` settings
- [ ] Copy `.config/ghostty/config` (terminal config)

## Environment Setup
- [ ] Configure PATH for all installed tools
- [ ] Set up proper shell environment variables
- [ ] Configure tmux plugin manager and plugins
- [ ] Set up fish shell plugins via Fisher
- [ ] Configure LazyVim and Mason LSP servers
- [ ] Apply Tokyo Night theme consistently
- [ ] Set up dotfiles syncing mechanism

## Version Management
- [ ] Configure mise/asdf for Node.js versions
- [ ] Configure mise/asdf for Python versions
- [ ] Configure mise/asdf for Go versions
- [ ] Set up proper tool versions from `.tool-versions`

## Cloud/DevOps Integration
- [ ] Configure AWS CLI with SSO support
- [ ] Set up Azure CLI with kubelogin
- [ ] Configure kubectl with kubie context switching
- [ ] Set up terraform with terraform-docs

## Testing & Validation
- [ ] Test all CLI tools work correctly
- [ ] Verify shell configurations load properly
- [ ] Test editor (neovim) with all plugins
- [ ] Validate tmux sessions and plugins
- [ ] Test development workflows
- [ ] Verify theme consistency across tools