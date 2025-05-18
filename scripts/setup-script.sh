#!/bin/bash

# Exit on error
set -e

echo "=== Starting macOS Development Environment Setup ==="

# Check if Homebrew is installed, install if not
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH (for Apple Silicon Macs)
  if [[ $(uname -m) == 'arm64' ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  echo "Homebrew already installed, updating..."
  brew update
fi

# Install command line tools and applications
echo "=== Installing CLI tools via Homebrew ==="
BREW_PACKAGES=(
  "zsh-vi-mode"
  "bat"
  "git-delta"
  "eza"
  "zoxide"
  "fd"
  "stow"
  "direnv"
  "mise"
  "kubie"
  "starship"
  "eks-node-viewer"
  "fzf"
)

for package in "${BREW_PACKAGES[@]}"; do
  if brew list "$package" &>/dev/null; then
    echo "$package already installed"
  else
    echo "Installing $package..."
    brew install "$package"
  fi
done

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "=== Installing Oh My Zsh ==="
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh already installed"
fi

# Install Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  echo "=== Installing Powerlevel10k theme ==="
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
else
  echo "Powerlevel10k already installed"
fi

# Install Oh My Zsh plugins
echo "=== Installing Oh My Zsh plugins ==="
declare -A plugins=(
  ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
  ["zsh-vi-mode"]="https://github.com/jeffreytse/zsh-vi-mode"
  ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
  ["zsh-kubectl-prompt"]="https://github.com/superbrothers/zsh-kubectl-prompt"
  ["docker-zsh-completion"]="https://github.com/greymd/docker-zsh-completion"
  ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
  ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
  ["zsh-history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search"
)

for plugin in "${!plugins[@]}"; do
  plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"
  if [ ! -d "$plugin_dir" ]; then
    echo "Installing plugin: $plugin"
    git clone "${plugins[$plugin]}" "$plugin_dir"
  else
    echo "Plugin $plugin already installed"
  fi
done

# Install and setup fzf
if [ ! -d "$HOME/.fzf" ]; then
  echo "=== Installing fzf ==="
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --all --no-bash --no-fish
else
  echo "fzf already installed"
fi

# Install fzf-git.sh
if [ ! -d "$HOME/fzf-git.sh" ]; then
  echo "=== Installing fzf-git.sh ==="
  git clone https://github.com/junegunn/fzf-git.sh "$HOME/fzf-git.sh"
else
  echo "fzf-git.sh already installed"
fi

# Create/modify .zshrc with appropriate configurations
echo "=== Configuring .zshrc ==="

# Backup existing .zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
  echo "Backing up existing .zshrc to .zshrc.backup.$(date +%Y%m%d%H%M%S)"
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
fi

# Create a new .zshrc
cat > "$HOME/.zshrc" << 'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set plugins
plugins=(
  git
  zsh-completions
  zsh-vi-mode
  fzf-tab
  zsh-kubectl-prompt
  docker-zsh-completion
  zsh-autosuggestions
  zsh-history-substring-search
  zsh-syntax-highlighting
)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Source zsh-vi-mode from Homebrew if installed
if [ -f "$(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]; then
  source "$(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi

# Initialize zoxide
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# Initialize direnv
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# Initialize mise
if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# Initialize starship prompt if not using powerlevel10k
# (uncomment to use instead of powerlevel10k)
# if command -v starship &> /dev/null; then
#   eval "$(starship init zsh)"
# fi

# Source fzf-git.sh
if [ -f "$HOME/fzf-git.sh/fzf-git.sh" ]; then
  source "$HOME/fzf-git.sh/fzf-git.sh"
fi

# Setup bat as a replacement for cat
if command -v bat &> /dev/null; then
  alias cat='bat'
fi

# Setup eza as a replacement for ls
if command -v eza &> /dev/null; then
  alias ls='eza'
  alias ll='eza -la'
  alias la='eza -a'
  alias lt='eza --tree'
fi

# FZF configuration
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Source powerlevel10k config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Add Homebrew to PATH for Apple Silicon Mac
if [[ $(uname -m) == 'arm64' ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Source asdf if installed via Homebrew
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
  . /opt/homebrew/opt/asdf/libexec/asdf.sh
fi
EOF

# Create basic .tmux.conf file
if [ ! -f "$HOME/.config/tmux/tmux.conf" ]; then
  echo "=== Creating tmux configuration ==="
  mkdir -p "$HOME/.config/tmux"
  cat > "$HOME/.config/tmux/tmux.conf" << 'EOF'
# Set prefix to Ctrl-Space
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Enable mouse mode
set -g mouse on

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Set larger history limit
set -g history-limit 5000

# Enable vi mode
setw -g mode-keys vi

# Split panes with | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload tmux config
bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

# Enable 256 colors
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
EOF

  # Create a symlink for backward compatibility
  ln -sf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
  echo "Created tmux configuration at ~/.config/tmux/tmux.conf with symlink at ~/.tmux.conf"
else
  echo "tmux configuration already exists"
fi

# Run p10k configuration if it doesn't exist
if [ ! -f "$HOME/.p10k.zsh" ]; then
  echo "=== Setting up Powerlevel10k ==="
  echo "Please run 'p10k configure' after this script completes to set up your terminal prompt"
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Close and reopen your terminal or run 'source ~/.zshrc'"
echo "2. If this is your first time with Powerlevel10k, run 'p10k configure'"
echo "3. Enjoy your new development environment!"
echo ""
