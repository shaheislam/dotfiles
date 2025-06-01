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
  "fzf"
  "ripgrep"
  "neovim"
  "tmux"
  "thefuck"
  "atuin"
  "lazygit"
  "lazydocker"
  "fish"
  "terraform"
  "asdf"
  "stylua"
  "black"
  "isort"
  "node"
  "python@3.11"
  "go"
  "rust"
  "awscli"
  "kubectl"
  "azure-cli"
  "imagemagick"
)

for package in "${BREW_PACKAGES[@]}"; do
  if brew list "$package" &>/dev/null; then
    echo "$package already installed"
  else
    echo "Installing $package..."
    brew install "$package"
  fi
done

# Install ueberzugpp (for image display in terminals like iTerm2)
if ! command -v ueberzugpp &> /dev/null; then
  echo "=== Installing ueberzugpp for image display ==="
  brew install jstkdng/programs/ueberzugpp
else
  echo "ueberzugpp already installed"
fi

# Install Nerd Fonts for beautiful terminal icons
echo "=== Installing Nerd Fonts ==="
NERD_FONTS=(
  "font-jetbrains-mono-nerd-font"
  "font-fira-code-nerd-font"
  "font-hack-nerd-font"
)

for font in "${NERD_FONTS[@]}"; do
  if brew list --cask "$font" &>/dev/null; then
    echo "$font already installed"
  else
    echo "Installing $font..."
    brew install --cask "$font"
  fi
done

# Install GUI applications via Homebrew Cask (only if not already present)
echo "=== Installing GUI applications via Homebrew Cask ==="

# Function to check if app is installed
app_installed() {
  [ -d "/Applications/$1.app" ]
}

# Install Ghostty
if app_installed "Ghostty"; then
  echo "Ghostty already installed"
else
  echo "Installing Ghostty..."
  brew install --cask ghostty
fi

# Install WezTerm
if app_installed "WezTerm"; then
  echo "WezTerm already installed"
else
  echo "Installing WezTerm..."
  brew install --cask wezterm
fi

# Install Visual Studio Code
if app_installed "Visual Studio Code"; then
  echo "Visual Studio Code already installed"
else
  echo "Installing Visual Studio Code..."
  brew install --cask visual-studio-code
fi

# Install AeroSpace
if app_installed "AeroSpace"; then
  echo "AeroSpace already installed"
else
  echo "Installing AeroSpace..."
  brew install --cask nikitabobko/tap/aerospace || {
    echo "Tap failed, installing manually..."
    curl -L https://github.com/nikitabobko/AeroSpace/releases/latest/download/AeroSpace-Beta.zip -o /tmp/aerospace.zip
    unzip /tmp/aerospace.zip -d /tmp/
    sudo mv "/tmp/AeroSpace.app" "/Applications/"
  }
fi

# Install SketchyBar (status bar) - needs special handling
if ! command -v sketchybar &> /dev/null; then
  echo "=== Installing SketchyBar ==="
  brew tap FelixKratz/formulae
  brew install sketchybar
  brew services start sketchybar
else
  echo "SketchyBar already installed"
fi

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

# Array of plugin names and their git URLs
install_zsh_plugin() {
  local plugin_name="$1"
  local plugin_url="$2"
  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin_name"

  if [ ! -d "$plugin_dir" ]; then
    echo "Installing plugin: $plugin_name"
    git clone "$plugin_url" "$plugin_dir"
  else
    echo "Plugin $plugin_name already installed"
  fi
}

# Install each plugin
install_zsh_plugin "zsh-completions" "https://github.com/zsh-users/zsh-completions"
install_zsh_plugin "zsh-vi-mode" "https://github.com/jeffreytse/zsh-vi-mode"
install_zsh_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"
install_zsh_plugin "zsh-kubectl-prompt" "https://github.com/superbrothers/zsh-kubectl-prompt"
install_zsh_plugin "docker-zsh-completion" "https://github.com/greymd/docker-zsh-completion"
install_zsh_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
install_zsh_plugin "zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"

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

# Install Node.js packages globally for formatters
echo "=== Installing Node.js global packages ==="

if command -v npm &> /dev/null; then
  # Only install prettierd - use existing Homebrew prettier
  npm install -g @fsouza/prettierd prettier-plugin-toml
  echo "Installed prettierd and prettier-plugin-toml"
  echo "Using existing prettier from Homebrew"
else
  echo "Warning: npm not found. Install Node.js first."
fi

# Install Python packages via Homebrew (safer)
echo "=== Installing Python packages via Homebrew ==="
PYTHON_BREW_PACKAGES=(
  "black"
  "isort"
  "ruff"
)

for package in "${PYTHON_BREW_PACKAGES[@]}"; do
  if brew list "$package" &>/dev/null; then
    echo "$package already installed"
  else
    echo "Installing $package via Homebrew..."
    brew install "$package"
  fi
done

# Install Rust formatters
echo "=== Installing Rust formatters ==="
if command -v cargo &> /dev/null; then
  cargo install stylua
fi

# Setup atuin
if command -v atuin &> /dev/null && [ ! -f "$HOME/.local/share/atuin/key" ]; then
  echo "=== Setting up Atuin ==="
  atuin import auto
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
KEYTIMEOUT=500

# Enable Powerlevel10k instant prompt (or starship)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k/.p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Choose between powerlevel10k and starship (uncomment one)
eval "$(starship init zsh)"
# export ZSH_THEME="powerlevel10k/powerlevel10k"

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set plugins
plugins=(
  git
  zsh-completions
  fzf-tab
  zsh-kubectl-prompt
  docker-zsh-completion
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-history-substring-search
)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Paths
export PATH="/opt/homebrew/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

# Add VSCode bin to PATH
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi

# Initialize tools
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"
eval "$(atuin init zsh)"

# Source asdf
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
  . /opt/homebrew/opt/asdf/libexec/asdf.sh
fi

# Source fzf-git.sh
if [ -f "$HOME/fzf-git.sh/fzf-git.sh" ]; then
  source "$HOME/fzf-git.sh/fzf-git.sh"
fi

# FZF configuration
source <(fzf --zsh)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# FZF theme
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Aliases
alias python=python3
alias cd="z"
alias ls="eza"
alias la="eza -al"
alias cat="bat"
alias k="kubectl"

# bat theme
export BAT_THEME=tokyonight_night

# thefuck
if command -v thefuck > /dev/null 2>&1; then
  eval $(thefuck --alias)
fi

# VSCode function
code() {
  if command -v code &> /dev/null; then
    command code "$@"
  elif [ -d "/Applications/Visual Studio Code.app" ]; then
    open -a "Visual Studio Code" "$@"
  else
    echo "VSCode is not installed or not found in the expected location."
  fi
}

# AWS SSO function
function aws-sso() {
    local profile=${1:-petlab}
    aws sso login --profile "$profile"
    eval "$(aws configure export-credentials --profile "$profile" --format env)"
    export AWS_DEFAULT_PROFILE="$profile"
    export AWS_PROFILE="$profile"
    aws sts get-caller-identity >/dev/null 2>&1 || echo "Failed to get credentials"
}

# Source powerlevel10k config if using it
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
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

# Create necessary directories
echo "=== Creating configuration directories ==="
mkdir -p "$HOME/.config/"{nvim,ghostty,wezterm,aerospace,sketchybar,atuin,fish}

# Run p10k configuration if it doesn't exist
if [ ! -f "$HOME/.p10k.zsh" ]; then
  echo "=== Setting up Powerlevel10k ==="
  echo "Please run 'p10k configure' after this script completes to set up your terminal prompt"
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Installed dependencies:"
echo "- Core tools: neovim, tmux, ripgrep, fd, bat, eza, zoxide"
echo "- Git tools: lazygit, lazydocker"
echo "- Shell enhancements: atuin, thefuck, starship"
echo "- Development tools: terraform, node, python, go, rust"
echo "- Formatters: stylua, prettier, black, isort"
echo "- Image display: ueberzugpp, imagemagick"
echo "- Fonts: JetBrains Mono Nerd Font, Fira Code Nerd Font, Hack Nerd Font"
echo "- macOS apps: ghostty, wezterm, aerospace, sketchybar"
echo ""
echo "Next steps:"
echo "1. Close and reopen your terminal or run 'source ~/.zshrc'"
echo "2. Configure iTerm2 to use 'JetBrainsMono Nerd Font' in Preferences → Profiles → Text"
echo "3. Set up your dotfiles with 'stow' if using GNU Stow"
echo "4. Configure aerospace with 'aerospace --config ~/.config/aerospace/aerospace.toml'"
echo "5. Start sketchybar: 'brew services start sketchybar'"
echo "6. Your Starship prompt should display beautiful icons!"
echo ""
