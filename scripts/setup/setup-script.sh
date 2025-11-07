#!/bin/bash

# Better error handling - continue on non-critical errors
set -u  # Exit on undefined variables
# Removed set -e to allow script to continue on recoverable errors

# Track overall success/failure
SETUP_ERRORS=0
SETUP_WARNINGS=0

# Helper functions for error handling
log_error() {
    echo "❌ ERROR: $1" >&2
    ((SETUP_ERRORS++))
}

log_warning() {
    echo "⚠️  WARNING: $1" >&2
    ((SETUP_WARNINGS++))
}

log_success() {
    echo "✅ $1"
}

log_info() {
    echo "ℹ️  $1"
}

# Function to run commands with error handling
run_with_retry() {
    local cmd="$1"
    local description="$2"
    local max_attempts="${3:-1}"

    for attempt in $(seq 1 $max_attempts); do
        if eval "$cmd"; then
            log_success "$description"
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "$description failed after $max_attempts attempts"
                return 1
            else
                log_warning "$description failed (attempt $attempt/$max_attempts), retrying..."
                sleep 2
            fi
        fi
    done
}

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

# Install packages using Brewfile
echo "=== Installing packages via Brewfile ==="
if [ -f "$HOME/dotfiles/homebrew/Brewfile" ]; then
  log_info "Found Brewfile, installing packages..."
  if brew bundle --file="$HOME/dotfiles/homebrew/Brewfile"; then
    log_success "Homebrew packages installed successfully"
  else
    log_error "Failed to install some Homebrew packages"
    log_info "Continuing with setup - you may need to install packages manually"
  fi
else
  log_error "Brewfile not found at $HOME/dotfiles/homebrew/Brewfile"
  log_info "Continuing setup without Homebrew packages"
fi

# Install command line tools and applications
echo "=== Installing CLI tools via Homebrew ==="

# Remove npm tldr if it exists to avoid conflicts with tealdeer
if command -v tldr &> /dev/null && [ -L "/opt/homebrew/bin/tldr" ]; then
  echo "Removing npm tldr package to avoid conflicts..."
  npm uninstall -g tldr
fi

BREW_PACKAGES=(
  "bottom"
  "fastfetch"
  "onefetch"
  "tealdeer"
  "glow"
  "jq"
  "yq"
  "graphviz"
  "shellcheck"
  "shfmt"
  "gh"
  "terraform_landscape"
)

for package in "${BREW_PACKAGES[@]}"; do
  if brew list "$package" &>/dev/null; then
    echo "$package already installed"
  else
    echo "Installing $package..."
    brew install "$package"
  fi
done

# Install Nerd Fonts for beautiful terminal icons
echo "=== Installing Nerd Fonts ==="
NERD_FONTS=(
  "font-iosevka-nerd-font"
)

for font in "${NERD_FONTS[@]}"; do
  if brew list --cask "$font" &>/dev/null; then
    echo "$font already installed"
  else
    echo "Installing $font..."
    brew install --cask "$font"
  fi
done

# DankMono Nerd Font - Manual Installation Required
# Note: DankMono is not available via Homebrew and must be installed manually
# Source: https://github.com/saifulapm/my-fonts
# Installation steps:
#   1. Clone the repository: git clone https://github.com/saifulapm/my-fonts.git /tmp/my-fonts
#   2. Install fonts: cp /tmp/my-fonts/DankMono\ Nerd\ Font/*.otf ~/Library/Fonts/
#   3. Restart applications to use the new font
echo "=== DankMono Nerd Font ==="
if fc-list 2>/dev/null | grep -qi "DankMono"; then
  echo "✓ DankMono Nerd Font is installed"
else
  echo "⚠ DankMono Nerd Font not found - install manually from:"
  echo "  https://github.com/saifulapm/my-fonts"
  echo "  Then: cp /tmp/my-fonts/DankMono\ Nerd\ Font/*.otf ~/Library/Fonts/"
fi

# Install GUI applications via Homebrew Cask (only if not already present)
echo "=== Installing GUI applications via Homebrew Cask ==="

# Function to check if app is installed
app_installed() {
  [ -d "/Applications/$1.app" ]
}

# Install Raycast
if app_installed "Raycast"; then
  echo "Raycast already installed"
else
  echo "Installing Raycast..."
  brew install --cask raycast
fi

# Install Willow Voice Assistant
if app_installed "Willow"; then
  echo "Willow already installed"
else
  echo "Installing Willow Voice Assistant..."
  brew install --cask willow
fi

# Install WezTerm
if app_installed "WezTerm"; then
  echo "WezTerm already installed"
else
  echo "Installing WezTerm..."
  brew install --cask wezterm
fi

# VSCode and Cursor removed from setup

# Install ueberzugpp (for image display in terminals like iTerm2)
if ! command -v ueberzugpp &> /dev/null; then
  echo "=== Installing ueberzugpp for image display ==="
  brew install jstkdng/programs/ueberzugpp
else
  echo "ueberzugpp already installed"
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

# Install AWS Session Manager Plugin
if ! command -v session-manager-plugin &> /dev/null; then
  echo "Installing AWS Session Manager Plugin..."
  brew install --cask session-manager-plugin
else
  echo "AWS Session Manager Plugin already installed"
fi

# Install Granted for AWS credential management
if ! command -v granted &> /dev/null; then
  echo "Installing Granted for AWS credential management..."
  brew tap common-fate/granted
  brew install granted
else
  echo "Granted already installed"
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

# Install fisher and fish plugins
if command -v fish &> /dev/null; then
  echo "=== Installing Fisher and Fish plugins ==="

  # Install Fisher package manager for Fish
  if ! fish -c "type fisher" &>/dev/null; then
    echo "Installing Fisher package manager..."
    fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
  else
    echo "Fisher already installed"
  fi

  # List of Fisher plugins to install
  FISHER_PLUGINS=(
    "gazorby/fish-abbreviation-tips"
    "patrickf3139/colored-man-pages"
    "jorgebucaran/autopair.fish"
    "evanlucas/fish-kubectl-completions"
    "oh-my-fish/plugin-bang-bang"
    "jhillyerd/plugin-git"
    "PatrickF1/fzf.fish"
  )

  # Install each plugin
  for plugin in "${FISHER_PLUGINS[@]}"; do
    echo "Installing Fish plugin: $plugin"
    fish -c "fisher install $plugin" || echo "Warning: Failed to install $plugin"
  done

  echo "Fisher and Fish plugins installation complete"

  # Initialize Carapace completions for Fish
  if command -v carapace &> /dev/null; then
    echo "Setting up Carapace completions for Fish..."
    # The actual initialization happens in config.fish, just verify it works
    fish -c "carapace _carapace" &>/dev/null && echo "Carapace completions ready for Fish" || echo "Warning: Carapace initialization may need manual setup"
  else
    echo "Note: Carapace not installed yet. Run 'brew install carapace' for enhanced completions"
  fi
else
  echo "Warning: Fish shell not found. Skipping Fisher plugin installation."
fi

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

# Install Tmux Plugin Manager and plugins
echo "=== Installing Tmux Plugin Manager and plugins ==="

# Install TPM if not already installed
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing Tmux Plugin Manager..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  echo "Tmux Plugin Manager already installed"
fi

# Function to install tmux plugin
install_tmux_plugin() {
  local plugin_name="$1"
  local plugin_url="$2"
  local plugin_dir="$HOME/.tmux/plugins/$plugin_name"

  if [ ! -d "$plugin_dir" ]; then
    echo "Installing tmux plugin: $plugin_name"
    git clone "$plugin_url" "$plugin_dir"
  else
    echo "Tmux plugin $plugin_name already installed"
  fi
}

# Install tmux plugins via git submodules (preferred) or individual cloning (fallback)
if [ -f "$HOME/dotfiles/.gitmodules" ]; then
  echo "Using git submodules for tmux plugins..."
  cd "$HOME/dotfiles" || exit
  git submodule update --init --recursive
  # Reset any modified submodules to their committed state
  git submodule foreach --recursive git reset --hard
  git submodule foreach --recursive git clean -fd
else
  echo "No .gitmodules found, installing plugins individually..."
  # Install tmux plugins (matching .tmux.conf exactly)
  install_tmux_plugin "tmux-sensible" "https://github.com/tmux-plugins/tmux-sensible"
  install_tmux_plugin "tmux-resurrect" "https://github.com/tmux-plugins/tmux-resurrect"
  install_tmux_plugin "tmux-continuum" "https://github.com/tmux-plugins/tmux-continuum"
  install_tmux_plugin "tmux-yank" "https://github.com/tmux-plugins/tmux-yank"
  install_tmux_plugin "tmux-prefix-highlight" "https://github.com/tmux-plugins/tmux-prefix-highlight"
  install_tmux_plugin "tmux-which-key" "https://github.com/alexwforsythe/tmux-which-key"
  install_tmux_plugin "tmux-open" "https://github.com/tmux-plugins/tmux-open"
  install_tmux_plugin "tmux-copycat" "https://github.com/tmux-plugins/tmux-copycat"
  install_tmux_plugin "tmux-pain-control" "https://github.com/tmux-plugins/tmux-pain-control"
  install_tmux_plugin "tmux-sidebar" "https://github.com/tmux-plugins/tmux-sidebar"
  install_tmux_plugin "tmux-fingers" "https://github.com/Morantron/tmux-fingers"
  install_tmux_plugin "tmux-battery" "https://github.com/tmux-plugins/tmux-battery"
  install_tmux_plugin "tmux-cpu" "https://github.com/tmux-plugins/tmux-cpu"
fi

# Apply Dracula theme customizations
echo "=== Applying Dracula theme customizations ==="
if [ -f "$(pwd)/scripts/setup-tmux-dracula.sh" ]; then
  bash "$(pwd)/scripts/setup-tmux-dracula.sh"
else
  echo "Warning: setup-tmux-dracula.sh script not found"
fi

# Create tmux config directory if it doesn't exist
mkdir -p "$HOME/.tmux"

# Copy tmux configuration
if [ -f "$(pwd)/.tmux.conf" ]; then
  echo "Installing tmux configuration..."
  cp "$(pwd)/.tmux.conf" "$HOME/.tmux.conf"
else
  echo "Warning: .tmux.conf not found in current directory"
fi

echo "=== Running TPM plugin installation ==="
# Auto-install/update plugins using TPM if tmux is installed
if command -v tmux &> /dev/null && [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
  echo "Installing/updating tmux plugins via TPM..."
  $HOME/.tmux/plugins/tpm/bin/install_plugins || echo "Note: TPM plugin installation may need to be run from within tmux"

  # Force install critical plugins if they're missing
  if [ ! -d "$HOME/.tmux/plugins/tmux-cpu" ]; then
    echo "Force installing tmux-cpu plugin..."
    git clone https://github.com/tmux-plugins/tmux-cpu "$HOME/.tmux/plugins/tmux-cpu" || log_warning "Failed to clone tmux-cpu"
  fi
  if [ ! -d "$HOME/.tmux/plugins/tmux-battery" ]; then
    echo "Force installing tmux-battery plugin..."
    git clone https://github.com/tmux-plugins/tmux-battery "$HOME/.tmux/plugins/tmux-battery" || log_warning "Failed to clone tmux-battery"
  fi

  echo "Tmux plugins installation attempted. If any failed, start tmux and press 'prefix' + 'I' (Ctrl-Space + I)"
else
  echo "Tmux setup complete. After starting tmux, press 'prefix' + 'I' (Ctrl-Space + I) to install the plugins."
fi

# Apply tmux-continuum fix
echo "=== Applying tmux-continuum fix ==="
if [ -f "$(pwd)/scripts/fix_tmux_continuum.sh" ]; then
  bash "$(pwd)/scripts/fix_tmux_continuum.sh"
else
  echo "Warning: fix_tmux_continuum.sh script not found"
fi

# Apply Floax plugin fix
echo "=== Applying Floax plugin fix ==="
if [ -f "$(pwd)/scripts/fix-floax-plugin.sh" ]; then
  bash "$(pwd)/scripts/fix-floax-plugin.sh"
else
  echo "Warning: fix-floax-plugin.sh script not found"
fi

# Ensure tmux-fingers is properly linked (installed via Homebrew)
if command -v tmux-fingers &> /dev/null; then
  log_success "tmux-fingers installed via Homebrew"
  # Create symlink in tmux plugins directory for consistency
  if [ ! -L "$HOME/.tmux/plugins/tmux-fingers" ] && [ ! -d "$HOME/.tmux/plugins/tmux-fingers" ]; then
    ln -s $(brew --prefix)/opt/tmux-fingers "$HOME/.tmux/plugins/tmux-fingers" 2>/dev/null || true
  fi
else
  log_warning "tmux-fingers not found. Install with: brew install morantron/tmux-fingers/tmux-fingers"
fi

# Configure tmux-session-wizard plugin
echo "=== Configuring tmux-session-wizard plugin ==="
# Verify dependencies for tmux-session-wizard
if ! command -v zoxide &> /dev/null; then
  log_warning "zoxide not found. tmux-session-wizard requires zoxide for directory jumping."
  log_info "Install with: brew install zoxide"
fi
if ! command -v fzf &> /dev/null; then
  log_warning "fzf not found. tmux-session-wizard requires fzf for fuzzy finding."
  log_info "Install with: brew install fzf"
fi
# Ensure the session-wizard executable is properly configured
if [ -d "$HOME/.tmux/plugins/tmux-session-wizard" ]; then
  chmod +x "$HOME/.tmux/plugins/tmux-session-wizard/bin/t" 2>/dev/null || true
  log_success "tmux-session-wizard plugin configured. Use Prefix+T to activate."
else
  log_info "tmux-session-wizard will be installed when you run TPM (Prefix+I in tmux)"
fi

# Configure tmux-sessionx plugin
if [ -d "$HOME/.tmux/plugins/tmux-sessionx" ]; then
  log_success "tmux-sessionx plugin configured. Use Prefix+o to activate."
else
  log_info "tmux-sessionx will be installed when you run TPM (Prefix+I in tmux)"
fi

# Setup tmuxinator configuration directory
echo "=== Setting up tmuxinator configuration ==="
if ! [ -d "$HOME/.config/tmuxinator" ]; then
  mkdir -p "$HOME/.config/tmuxinator"
  log_success "Created tmuxinator configuration directory"
else
  log_info "Tmuxinator configuration directory already exists"
fi

# Configure tmux-which-key plugin
echo "=== Configuring tmux-which-key plugin ==="
# The plugin will be in ~/.tmux/plugins after stow creates the symlink
if [ -d "$HOME/.tmux/plugins/tmux-which-key" ]; then
  if command -v python3 &> /dev/null; then
    echo "Setting up tmux-which-key configuration..."
    cd "$HOME/.tmux/plugins/tmux-which-key" || exit
    # Copy example config if config.yaml doesn't exist
    if [ ! -f "config.yaml" ]; then
      cp config.example.yaml config.yaml
    fi
    # Build the init.tmux file
    python3 plugin/build.py config.yaml plugin/init.tmux
    echo "tmux-which-key configured successfully"
  else
    echo "Warning: python3 not found. tmux-which-key requires python3 for configuration."
  fi
else
  echo "tmux-which-key plugin not found. Make sure to run 'stow .' from your dotfiles directory first."
fi

# Install vim-plug
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
  echo "=== Installing vim-plug ==="
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
else
  echo "vim-plug already installed"
fi

# Install Node.js packages globally for formatters and browser tools
echo "=== Installing Node.js global packages ==="

if command -v npm &> /dev/null; then
  # Only install prettierd - use existing Homebrew prettier
  bun install -g @fsouza/prettierd prettier-plugin-toml || npm install -g @fsouza/prettierd prettier-plugin-toml
  echo "Installed prettierd and prettier-plugin-toml"
  echo "Using existing prettier from Homebrew"

  # Install BrowserTools MCP packages
  echo "Installing BrowserTools MCP packages..."
  bun install -g @agentdeskai/browser-tools-mcp@1.2.0 || npm install -g @agentdeskai/browser-tools-mcp@1.2.0
  bun install -g @agentdeskai/browser-tools-server@1.2.0 || npm install -g @agentdeskai/browser-tools-server@1.2.0
  echo "Installed BrowserTools MCP packages"

  # Download BrowserTools Chrome extension to dotfiles directory
  echo "Setting up BrowserTools Chrome extension..."
  mkdir -p "$HOME/dotfiles/.config/browser-tools"
  cd "$HOME/dotfiles/.config/browser-tools" || exit

  # Download the packaged extension if not already present
  if [ ! -f "BrowserTools-extension.zip" ]; then
    echo "Downloading BrowserTools Chrome extension..."
    curl -L https://github.com/AgentDeskAI/browser-tools-mcp/releases/download/v1.2.0/BrowserTools-1.2.0-extension.zip -o BrowserTools-extension.zip
  fi

  # Extract extension if not already extracted
  if [ ! -d "chrome-extension" ]; then
    echo "Extracting BrowserTools Chrome extension..."
    unzip BrowserTools-extension.zip
    # Clean up macOS metadata
    rm -rf __MACOSX
  fi

  echo "BrowserTools Chrome extension prepared at ~/dotfiles/.config/browser-tools/chrome-extension"
  echo ""
  echo "⚠️  MANUAL STEP REQUIRED: Install Chrome Extension"
  echo "1. Open Chrome and go to chrome://extensions/"
  echo "2. Enable 'Developer mode' (toggle in top right)"
  echo "3. Click 'Load unpacked' and select: $HOME/dotfiles/.config/browser-tools/chrome-extension"
  echo "4. The BrowserTools extension should now be installed"
  echo "5. Start browser-tools server: npx @agentdeskai/browser-tools-server@latest"
  echo ""
else
  echo "Warning: npm not found. Install Node.js first."
fi

# Install global packages using bun if available
if command -v bun &> /dev/null; then
  log_info "Installing global packages with bun..."
  if bun install -g ccusage; then
    log_success "Installed ccusage globally via bun"
    # Add bun bin to PATH for current session
    export PATH="$HOME/.bun/bin:$PATH"
    log_success "Added bun bin directory to PATH"
  else
    log_warning "Failed to install global packages with bun"
  fi
else
  log_warning "bun not found. Should be installed via Brewfile"
  log_info "You can manually install bun with: curl -fsSL https://bun.sh/install | bash"
fi

# Configure bat with Tokyo Night theme
echo "=== Configuring bat with Tokyo Night theme ==="
mkdir -p "$(bat --config-dir)/themes"
cd "$(bat --config-dir)/themes" || exit
curl -O https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme
bat cache --build
echo '--theme="tokyonight_night"' > "$(bat --config-dir)/config"
echo "Bat configured with Tokyo Night theme"

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

# Install Rust tools
echo "=== Installing Rust tools ==="
if command -v cargo &> /dev/null; then
  cargo install stylua
  cargo install s3grep
fi

# Install Python MCP servers via pipx
echo "=== Installing Python MCP servers ==="
if command -v pipx &> /dev/null; then
  echo "Installing Python-based MCP servers..."

  # Install MCP servers that are Python-based
  pipx install mcp-server-git || echo "Warning: Failed to install mcp-server-git"
  pipx install mcp-server-fetch || echo "Warning: Failed to install mcp-server-fetch"
  pipx install mcp-server-sqlite || echo "Warning: Failed to install mcp-server-sqlite"

  # Install diagrams package (required for aws-diagram-mcp-server)
  pipx install diagrams || echo "Warning: Failed to install diagrams"

  echo "Python MCP servers installation complete"
else
  echo "Warning: pipx not found. Install pipx first via Homebrew"
  echo "Run: brew install pipx"
fi

# Claude Code CLI (now uses official installer)
echo "=== Checking Claude Code CLI ==="
if ! command -v claude &> /dev/null; then
  echo "⚠️  Claude Code CLI not found."
  echo "Please install Claude Code using the official installer:"
  echo "  1. Download from: https://claude.ai/download"
  echo "  2. Run: claude update"
  echo "  3. Run: claude migrate-installer (if upgrading from npm/bun version)"
  log_warning "Claude Code CLI needs manual installation"
else
  echo "Claude Code CLI already installed at: $(which claude)"
  echo "To update, run: claude update"
fi

# Install Claude Code Router for alternative AI providers
echo "=== Installing Claude Code Router ==="
if ! command -v ccr &> /dev/null; then
  echo "Installing Claude Code Router..."
  bun install -g @musistudio/claude-code-router || npm install -g @musistudio/claude-code-router || echo "Warning: Failed to install Claude Code Router"
else
  echo "Claude Code Router already installed at: $(which ccr)"
fi

# Setup Claude Code Router configuration
if [ -f "$HOME/dotfiles/.config/claude-code-router/config.json" ] && [ ! -f "$HOME/.claude-code-router/config.json" ]; then
  echo "Setting up Claude Code Router configuration..."
  mkdir -p "$HOME/.claude-code-router"
  ln -s "$HOME/dotfiles/.config/claude-code-router/config.json" "$HOME/.claude-code-router/config.json"
  echo "Claude Code Router configuration linked from dotfiles"
fi

# Install OpenAI Codex CLI
echo "=== Installing OpenAI Codex CLI ==="
if command -v npm &> /dev/null; then
  if ! command -v codex &> /dev/null; then
    echo "Installing OpenAI Codex CLI..."
    if bun install -g @openai/codex || npm install -g @openai/codex; then
      log_success "OpenAI Codex CLI installed"
      echo "ℹ️  OpenAI Codex CLI is ready!"
      echo "   - Run 'codex' to start the AI coding assistant"
      echo "   - Sign in with your ChatGPT account when prompted"
      echo "   - Get AI-powered coding assistance locally"
    else
      log_error "Failed to install OpenAI Codex CLI"
    fi
  else
    log_success "OpenAI Codex CLI already installed"
  fi
else
  log_warning "npm not found. Install Node.js first to use OpenAI Codex CLI"
fi

# Install AWS CDK CLI globally
echo "=== Installing AWS CDK CLI ==="
if command -v cdk &> /dev/null; then
  log_success "AWS CDK already installed ($(cdk --version))"
else
  log_info "Installing AWS CDK globally..."
  if bun install -g aws-cdk || npm install -g aws-cdk; then
    log_success "AWS CDK installed successfully ($(cdk --version))"
  else
    log_error "Failed to install AWS CDK"
  fi
fi

# Configure Opencode AI coding agent
echo "=== Configuring Opencode ==="
if command -v opencode &> /dev/null; then
  log_success "Opencode already installed at: $(which opencode)"
  echo "ℹ️  Opencode is ready!"
  echo "   - Run 'opencode' to start the AI coding agent"
  echo "   - Use 'opencode auth login' to add your API keys for LLM providers"
  echo "   - Run '/init' in your project directory to create an AGENTS.md file"
  echo "   - Opencode supports OpenCode Zen and various LLM providers"
  echo "   - LSP Integration: Uses your Nix-managed LSP servers (auto-download disabled)"
  echo "     Environment: OPENCODE_DISABLE_LSP_DOWNLOAD=true prevents duplicate LSPs"
else
  echo "Opencode not installed yet."
  echo "Install with: brew install sst/tap/opencode"
  log_warning "Opencode needs installation via Homebrew"
fi

# Configure Claude Code MCP servers (user scope)
echo "=== Configuring Claude Code MCP servers ==="
if command -v claude &> /dev/null; then
  echo "Adding MCP servers to Claude Code user scope..."

  # Core development tools
  claude mcp add --scope user filesystem npx @modelcontextprotocol/server-filesystem "$HOME/Desktop" "$HOME/Downloads" || echo "Warning: Failed to add filesystem MCP"
  claude mcp add --scope user git pipx run mcp-server-git "$HOME/dotfiles" || echo "Warning: Failed to add git MCP"
  claude mcp add --scope user github npx @modelcontextprotocol/server-github || echo "Warning: Failed to add github MCP"
  claude mcp add --scope user memory npx @modelcontextprotocol/server-memory || echo "Warning: Failed to add memory MCP"
  claude mcp add --scope user sequential-thinking npx @modelcontextprotocol/server-sequential-thinking || echo "Warning: Failed to add sequential-thinking MCP"

  # Web and automation tools
  claude mcp add --scope user browser-tools npx @agentdeskai/browser-tools-mcp@1.2.0 || echo "Warning: Failed to add browser-tools MCP"
  claude mcp add --scope user fetch pipx run mcp-server-fetch || echo "Warning: Failed to add fetch MCP"
  claude mcp add --scope user duckduckgo npx duckduckgo-mcp-server || echo "Warning: Failed to add duckduckgo MCP"

  # Database tools - removed (not needed)
  # Enterprise integration - removed (not needed)

  # Additional MCP servers
  claude mcp add --scope user context7 bunx @upstash/context7-mcp || echo "Warning: Failed to add context7 MCP"
  claude mcp add --scope user steampipe npx @turbot/steampipe-mcp postgresql://steampipe@localhost:9193/steampipe || echo "Warning: Failed to add steampipe MCP"

  # Airbnb MCP (uses npx per hook exception)
  # Note: claude mcp add doesn't support passing args like --ignore-robots-txt, so we add it via jq
  echo "Configuring Airbnb MCP..."
  jq '.mcpServers.airbnb = {"type": "stdio", "command": "npx", "args": ["-y", "@openbnb/mcp-server-airbnb", "--ignore-robots-txt"], "env": {}}' ~/.claude.json > /tmp/claude_temp.json && mv /tmp/claude_temp.json ~/.claude.json || echo "Warning: Failed to add airbnb MCP"

  # Browser automation (Microsoft Playwright)
  claude mcp add --scope user playwright bunx @playwright/mcp@latest || echo "Warning: Failed to add playwright MCP"

  # Diagramming tools
  claude mcp add --scope user drawio npx -y drawio-mcp-server || echo "Warning: Failed to add drawio MCP"

  # Database tools (Google GenAI Toolbox)
  # Note: Requires DATABASE_URL env var to be set for database access
  claude mcp add --scope user genai-toolbox bunx @googlegenai/genai-toolbox || echo "Warning: Failed to add genai-toolbox MCP"

  # AWS MCP servers (require uv to be installed)
  echo "Adding AWS MCP servers to Claude Code..."

  # Core AWS tools (no credentials required)
  claude mcp add --scope user aws-documentation uvx awslabs.aws-documentation-mcp-server@latest || echo "Warning: Failed to add aws-documentation MCP"
  claude mcp add --scope user aws-diagram uvx awslabs.aws-diagram-mcp-server || echo "Warning: Failed to add aws-diagram MCP"
  claude mcp add --scope user aws-cdk uvx awslabs.cdk-mcp-server@latest || echo "Warning: Failed to add aws-cdk MCP"
  claude mcp add --scope user aws-terraform uvx awslabs.terraform-mcp-server@latest || echo "Warning: Failed to add aws-terraform MCP"

  # AWS services (require AWS credentials)
  claude mcp add --scope user aws-iam uvx awslabs.iam-mcp-server@latest || echo "Warning: Failed to add aws-iam MCP"
  claude mcp add --scope user aws-cloudformation uvx awslabs.cfn-mcp-server@latest || echo "Warning: Failed to add aws-cloudformation MCP"
  claude mcp add --scope user aws-dynamodb uvx awslabs.dynamodb-mcp-server@latest || echo "Warning: Failed to add aws-dynamodb MCP"
  claude mcp add --scope user aws-lambda uvx awslabs.lambda-tool-mcp-server@latest || echo "Warning: Failed to add aws-lambda MCP"

  echo "AWS MCP servers added to Claude Code"

  echo "Claude Code MCP configuration complete"
  echo "You can verify with: claude mcp list"

  echo ""
  echo "Note: AWS MCP servers are also configured in Claude Desktop config."
  echo "Both Claude Desktop and Claude Code can now use AWS MCP servers."
  echo ""
  echo "Note: browser-tools MCP is enabled with error suppression to hide JSON parsing warnings."
  echo "Both browser-tools and playwright MCP are available for browser automation."
else
  echo "Warning: Claude Code CLI not found. MCP servers not configured for Claude Code."
  echo "Install Claude Code CLI first, then run this script again or configure manually."
fi

# SuperClaude setup is handled by stow when dotfiles are linked
echo "=== SuperClaude Configuration ==="
if [ -L "$HOME/.claude" ]; then
  log_success "SuperClaude already configured via dotfiles symlink"
else
  log_info "SuperClaude will be configured when you run 'stow . --adopt' from dotfiles directory"
  echo "This will symlink ~/.claude/ to your dotfiles/.claude/ directory"
fi

# Install footyres (football results CLI)
echo "=== Installing footyres ==="
if [ ! -d "$HOME/dotfiles/scripts/footyres" ]; then
  echo "Cloning footyres repository..."
  cd "$HOME/dotfiles/scripts" && git clone https://github.com/kubblai/footyres.git
  echo "footyres repository cloned to scripts/footyres"
else
  echo "footyres already installed"
fi

# Make scripts executable
if [ -f "$HOME/dotfiles/scripts/bin/footyres" ]; then
  chmod +x "$HOME/dotfiles/scripts/bin/footyres"
  echo "footyres wrapper script is ready"
fi

# Make tmux scripts executable
if [ -f "$HOME/dotfiles/scripts/tmux/tmux-url-handler.sh" ]; then
  chmod +x "$HOME/dotfiles/scripts/tmux/tmux-url-handler.sh"
  log_success "tmux-url-handler.sh is now executable"
else
  log_warning "tmux-url-handler.sh not found"
fi

# Make tmux formatting scripts executable
for script in tmux-cpu-formatted.sh tmux-ram-formatted.sh tmux-battery-formatted.sh; do
  if [ -f "$HOME/dotfiles/scripts/tmux/$script" ]; then
    chmod +x "$HOME/dotfiles/scripts/tmux/$script"
    log_success "$script is now executable"
  else
    log_warning "$script not found"
  fi
done

# Install Mac App Store applications using mas
echo "=== Installing Mac App Store Applications ==="
if command -v mas &> /dev/null; then
  # Check if signed into Mac App Store
  if mas account &> /dev/null; then
    log_info "Installing Kinda Vim for Safari..."
    if mas install 1609556629; then  # Kinda Vim for Safari
      log_success "Kinda Vim for Safari installed successfully"
      echo "ℹ️  To enable Kinda Vim:"
      echo "   1. Open Safari"
      echo "   2. Go to Safari → Settings → Extensions"
      echo "   3. Enable 'Kinda Vim for Safari'"
      echo ""
    else
      log_warning "Failed to install Kinda Vim for Safari - may already be installed"
    fi
  else
    log_warning "Not signed into Mac App Store - skipping App Store applications"
    echo "ℹ️  To install manually:"
    echo "   1. Sign into Mac App Store"
    echo "   2. Run: mas install 1609556629  # Kinda Vim for Safari"
    echo ""
  fi
else
  log_error "mas (Mac App Store CLI) not found - should be installed via Brewfile"
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
export PATH="$HOME/.bun/bin:$PATH"
export PATH="$HOME/dotfiles/scripts/bin:$PATH"

# VSCode and Cursor PATH entries removed

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

# FZF theme - Tokyo Night
fg="#c0caf5"
bg="#1a1b26"
bg_highlight="#283457"
purple="#9d7cd8"
blue="#7aa2f7"
cyan="#7dcfff"
magenta="#bb9af7"
green="#9ece6a"
yellow="#e0af68"
red="#f7768e"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${blue},fg+:${fg},bg+:${bg_highlight},hl+:${magenta},info:${yellow},prompt:${cyan},pointer:${blue},marker:${green},spinner:${cyan},header:${purple}"
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
alias kc="kubectx"
alias kn="kubens"

# bat theme
export BAT_THEME=tokyonight_night

# thefuck
if command -v thefuck > /dev/null 2>&1; then
  eval $(thefuck --alias)
fi

# VSCode and Cursor functions removed

# AWS SSO function
function aws-sso() {
    local profile=${1:-petlab}
    aws sso login --profile "$profile"
    eval "$(aws configure export-credentials --profile "$profile" --format env)"
    export AWS_DEFAULT_PROFILE="$profile"
    export AWS_PROFILE="$profile"
    aws sts get-caller-identity >/dev/null 2>&1 || echo "Failed to get credentials"
}

# Granted AWS credential management alias and completions
# Granted needs an alias to export environment variables
alias assume="source assume"

# Enable Granted completions for Zsh shell
if command -v granted &> /dev/null 2>&1; then
    eval "$(granted completion --shell zsh)" 2>/dev/null || true
fi

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
mkdir -p "$HOME/.config/"{nvim,ghostty,wezterm,aerospace,atuin,fish,opencode}
mkdir -p "$HOME/Library/Application Support/Claude"
mkdir -p "$HOME/Documents/databases"

# Install Neovim plugins automatically
echo "=== Installing Neovim plugins ==="
if command -v nvim &> /dev/null; then
  echo "Installing Neovim plugins via Lazy.nvim..."
  nvim --headless "+Lazy! sync" +qa
  echo "Neovim plugins installed successfully"

  # Ensure custom Treesitter query directory exists for overrides
  echo "Setting up custom Treesitter query overrides..."
  if [ -d "$HOME/neovim" ]; then
    mkdir -p "$HOME/neovim/queries/python"
    echo "Custom query directory created/verified at ~/neovim/queries/python"
  fi
else
  echo "Warning: Neovim not found. Skipping plugin installation."
fi

# Install pynvim for Neovim Python support
echo "=== Installing pynvim for Neovim Python support ==="
if command -v python3.11 &> /dev/null; then
  echo "Installing pynvim for Python 3.11..."
  python3.11 -m pip install --quiet pynvim
  echo "pynvim installed successfully"
elif command -v python3 &> /dev/null; then
  echo "Installing pynvim for system Python 3..."
  python3 -m pip install --quiet pynvim
  echo "pynvim installed successfully"
else
  echo "Warning: Python 3 not found. Skipping pynvim installation."
fi

# Setup Pulse (Coding Activity Tracker)
echo "=== Setting up Pulse (Coding Activity Tracker) ==="

# Start Redis service (required for Pulse)
log_info "Starting Redis service..."
if command -v brew &> /dev/null; then
  brew services start redis 2>/dev/null || log_warning "Redis service may already be running"
  log_success "Redis service started"
else
  log_warning "Homebrew not found - cannot start Redis service"
fi

# Build and install Pulse binaries
if ! command -v pulse-server &> /dev/null || ! command -v pulse-client &> /dev/null; then
  log_info "Building Pulse from source..."
  if command -v go &> /dev/null; then
    cd /tmp || exit
    if [ -d "pulse" ]; then
      rm -rf pulse
    fi

    if git clone https://github.com/viccon/pulse.git; then
      cd pulse || exit
      if go build -o pulse-server ./cmd/server && go build -o pulse-client ./cmd/client; then
        mkdir -p ~/bin
        cp pulse-server ~/bin/
        cp pulse-client ~/bin/
        chmod +x ~/bin/pulse-server ~/bin/pulse-client
        log_success "Pulse binaries installed to ~/bin/"
      else
        log_error "Failed to build Pulse binaries"
      fi
      cd ~ || exit
      rm -rf /tmp/pulse
    else
      log_error "Failed to clone Pulse repository"
    fi
  else
    log_error "Go not installed - cannot build Pulse. Install with: brew install go"
  fi
else
  log_success "Pulse binaries already installed"
fi

# Create Pulse configuration
log_info "Configuring Pulse..."
mkdir -p ~/.pulse/logs ~/.pulse/data

if [ ! -f ~/.pulse/config.yaml ]; then
  cat > ~/.pulse/config.yaml << 'EOF'
server:
  name: "pulse-server"
  hostname: "localhost"
  port: "1122"
  aggregationInterval: "15m"
  segmentationInterval: "5m"
  segmentSizeKB: "10"
database:
  address: "localhost:6379"
  password: ""
EOF
  log_success "Pulse configuration created at ~/.pulse/config.yaml"
else
  log_success "Pulse configuration already exists"
fi

# Setup Pulse launch daemon (auto-start on login)
log_info "Setting up Pulse launch daemon..."
PULSE_PLIST=~/Library/LaunchAgents/dev.shaheislam.pulse.plist

if [ ! -f "$PULSE_PLIST" ]; then
  mkdir -p ~/Library/LaunchAgents
  cat > "$PULSE_PLIST" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>dev.shaheislam.pulse</string>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/Users/shaheislam/.pulse/logs/stderr.log</string>
    <key>StandardOutPath</key>
    <string>/Users/shaheislam/.pulse/logs/stdout.log</string>
    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string><![CDATA[/Users/shaheislam/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin]]></string>
    </dict>
    <key>WorkingDirectory</key>
    <string>/Users/shaheislam</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/shaheislam/bin/pulse-server</string>
    </array>
    <key>KeepAlive</key>
    <true/>
  </dict>
</plist>
EOF

  # Load the daemon
  if command -v pulse-server &> /dev/null; then
    launchctl load "$PULSE_PLIST" 2>/dev/null && log_success "Pulse daemon configured and started" || log_warning "Pulse daemon configured but not started - may need manual start"
  else
    log_warning "Pulse daemon configured but server binary not found - will start after installation"
  fi
else
  log_success "Pulse daemon already configured"
fi

log_success "Pulse setup complete!"
log_info "View Pulse logs: tail -f ~/.pulse/logs/stdout.log"
log_info "Query data: redis-cli KEYS \"*\""
log_info "Server status: launchctl list | grep pulse"

# Install consul-template
echo "=== Installing consul-template ==="
if ! command -v consul-template &> /dev/null; then
  log_info "Downloading consul-template..."
  cd /tmp || exit
  curl -L https://releases.hashicorp.com/consul-template/0.41.3/consul-template_0.41.3_darwin_arm64.zip -o consul-template.zip
  unzip -q consul-template.zip
  mkdir -p ~/bin
  mv consul-template ~/bin/
  chmod +x ~/bin/consul-template
  rm consul-template.zip
  log_success "consul-template installed to ~/bin/"
else
  log_success "consul-template already installed"
fi

# Setup Karabiner-Elements keyboard remapper
echo "=== Setting up Karabiner-Elements keyboard remapper ==="

if [ "$(uname)" == "Darwin" ]; then
  if [ -d "/Library/Application Support/org.pqrs/Karabiner-Elements" ] || [ -d "/Applications/Karabiner-Elements.app" ]; then
    log_success "Karabiner-Elements is installed"

    # Ensure karabiner config directory exists
    mkdir -p "$HOME/.config/karabiner"

    # Symlink config if needed (can't use stow due to Karabiner's own files in directory)
    if [ -L "$HOME/.config/karabiner/karabiner.json" ]; then
      log_success "Karabiner-Elements configuration already symlinked"
    elif [ -f "$HOME/.config/karabiner/karabiner.json" ]; then
      log_info "Backing up existing Karabiner config and creating symlink"
      mv "$HOME/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json.backup"
      ln -sf "$HOME/dotfiles/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
      log_success "Karabiner-Elements configuration symlinked (backup created)"
    elif [ -f "$HOME/dotfiles/.config/karabiner/karabiner.json" ]; then
      ln -sf "$HOME/dotfiles/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
      log_success "Karabiner-Elements configuration symlinked"
    else
      log_warning "Karabiner-Elements configuration not found in dotfiles"
    fi

    log_info "Key mappings: Caps Lock ↔ Escape"
    log_info "Edit config: Open Karabiner-Elements app or edit ~/.config/karabiner/karabiner.json"
  else
    log_warning "Karabiner-Elements not found"
    log_info "Install with: brew install --cask karabiner-elements"
  fi
fi

# Setup Bash configuration
echo "=== Setting up Bash configuration ==="
log_info "Bash config files (.bashrc, .bash_profile) are managed by stow"
log_info "These provide PATH consistency and tool integrations across Fish, Zsh, and Bash"
if [ -L "$HOME/.bashrc" ] && [ -L "$HOME/.bash_profile" ]; then
  log_success "Bash configuration files already symlinked"
else
  log_info "Run 'cd ~/dotfiles && stow .' to symlink Bash configs"
fi
log_info "Test Bash: Type 'bash' from Fish/Zsh to switch shells"
log_info "Features: Starship prompt, zoxide, direnv, atuin, fzf, asdf"

# Run p10k configuration if it doesn't exist
if [ ! -f "$HOME/.p10k.zsh" ]; then
  echo "=== Setting up Powerlevel10k ==="
  echo "Please run 'p10k configure' after this script completes to set up your terminal prompt"
fi

# Configure global gitignore
echo "=== Configuring global gitignore ==="
git config --global core.excludesfile ~/.gitignore_global
echo "Global gitignore configured to use ~/.gitignore_global"

# Configure Jujutsu (jj) version control
echo "=== Configuring Jujutsu (jj) version control ==="
if command -v jj &> /dev/null; then
  # Initialize jj configuration
  if [ -f "$HOME/dotfiles/.config/jj/config.toml" ]; then
    mkdir -p "$HOME/.config/jj"
    ln -sf "$HOME/dotfiles/.config/jj/config.toml" "$HOME/.config/jj/config.toml" 2>/dev/null || true
    log_success "Jujutsu (jj) configuration linked"
  else
    log_info "Jujutsu config will be created by stow"
  fi
else
  log_warning "Jujutsu (jj) not installed. Install with: brew install jj"
fi

# Pre-commit hooks removed from dotfiles setup
# Users can manually install pre-commit if needed for specific projects

# Configure Claude Code
echo "=== Configuring Claude Code ==="
if command -v claude &> /dev/null; then
    claude config set --global preferredNotifChannel terminal_bell
    echo "Claude Code notification channel set to terminal_bell"
else
    echo "Claude Code not found, skipping configuration"
fi

# Configure direnv
echo "=== Configuring direnv ==="
if command -v direnv &> /dev/null; then
  # Create direnv config directory
  mkdir -p "$HOME/.config/direnv"
  # Link direnv config if it exists in dotfiles
  if [ -f "$HOME/dotfiles/.config/direnv/direnv.toml" ]; then
    ln -sf "$HOME/dotfiles/.config/direnv/direnv.toml" "$HOME/.config/direnv/direnv.toml" 2>/dev/null || true
  fi
  log_success "direnv configured"
else
  log_warning "direnv not installed. Install with: brew install direnv"
fi

# Install and configure Nix package manager
echo "=== Installing Nix Package Manager ==="
if ! command -v nix &> /dev/null; then
  log_info "Nix not found, installing..."

  # Use the Determinate Systems installer for better macOS support
  if curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm; then
    log_success "Nix installed successfully"

    # Source Nix for current session
    if [ -f '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
  else
    log_error "Failed to install Nix package manager"
    log_info "You can manually install Nix later from https://nixos.org/download"
  fi
else
  log_success "Nix already installed"
fi

# Configure Nix
if command -v nix &> /dev/null; then
  echo "=== Configuring Nix ==="

  # Create Nix config directory
  mkdir -p "$HOME/.config/nix"

  # Enable experimental features (flakes and nix-command)
  if [ ! -f "$HOME/.config/nix/nix.conf" ]; then
    cat > "$HOME/.config/nix/nix.conf" << 'EOF'
# Enable experimental features
experimental-features = nix-command flakes

# Build settings
max-jobs = auto
cores = 0
sandbox = true

# Substituters (binary caches)
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=

# Garbage collection
keep-outputs = true
keep-derivations = true
EOF
    log_success "Nix configuration created"
  else
    log_info "Nix configuration already exists"
  fi

  # Create Nix directory structure in dotfiles
  if [ ! -d "$HOME/dotfiles/nix" ]; then
    log_info "Creating Nix directory structure..."
    mkdir -p "$HOME/dotfiles/nix/flake-templates"
    mkdir -p "$HOME/dotfiles/nix/project-templates"
    log_success "Nix directories created"
  fi

  # Test Nix installation
  if nix --version &> /dev/null; then
    NIX_VERSION=$(nix --version | awk '{print $3}')
    log_success "Nix $NIX_VERSION configured successfully"
  else
    log_warning "Nix installed but not fully configured - may need to restart shell"
  fi

  # Install Home Manager
  echo "=== Setting up Home Manager ==="
  if [ ! -f "$HOME/.config/home-manager/flake.nix" ]; then
    log_info "Home Manager configuration not found, setting up..."

    # Symlink Home Manager configuration from dotfiles if it exists
    if [ -d "$HOME/dotfiles/.config/home-manager" ]; then
      # Remove any existing directory first
      rm -rf "$HOME/.config/home-manager" 2>/dev/null || true
      ln -sf "$HOME/dotfiles/.config/home-manager" "$HOME/.config/home-manager"
      log_success "Home Manager configuration symlinked from dotfiles"
    else
      log_warning "Home Manager configuration not found in dotfiles"
      log_info "You can manually set it up later with 'nix run home-manager/master -- init'"
    fi
  else
    log_info "Home Manager configuration already exists"
  fi

  # Activate Home Manager if config exists
  if [ -f "$HOME/.config/home-manager/flake.nix" ]; then
    log_info "Activating Home Manager configuration..."
    if cd "$HOME/.config/home-manager" && nix run . -- switch --flake . 2>/dev/null; then
      log_success "Home Manager activated - global packages now available"
    else
      log_warning "Home Manager activation failed - run 'hm-switch' manually after restarting shell"
    fi
    cd - > /dev/null
  fi
else
  log_warning "Nix installation skipped or failed"
fi

# LSP Installation (Manual)
echo ""
log_info "LSP installation is available but not run automatically"
log_info "To install LSPs when ready: cd ~/dotfiles && ./scripts/activate-nix-lsps.sh hybrid"
echo ""

# Apply macOS system defaults for developers
echo "=== Applying macOS developer defaults ==="
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [ -f "$HOME/dotfiles/scripts/setup/macos-defaults.sh" ]; then
    log_info "Configuring macOS developer settings..."
    bash "$HOME/dotfiles/scripts/setup/macos-defaults.sh" || log_warning "Some macOS defaults may have failed - check manually"
    log_success "macOS developer defaults applied"
  else
    log_warning "macos-defaults.sh not found in scripts directory"
  fi
else
  log_info "Not running on macOS, skipping macOS defaults"
fi

# Set Fish as default shell
echo "=== Setting Fish as default shell ==="
if command -v fish &> /dev/null; then
  FISH_PATH=$(which fish)
  # Check if fish is in /etc/shells
  if ! grep -q "$FISH_PATH" /etc/shells; then
    log_info "Adding Fish to /etc/shells..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells
  fi
  # Check if Fish is already the default shell
  if [[ "$SHELL" != "$FISH_PATH" ]]; then
    log_info "Setting Fish as default shell..."
    if chsh -s "$FISH_PATH"; then
      log_success "Fish set as default shell. Please restart your terminal."
    else
      log_warning "Failed to set Fish as default shell. You can manually run: chsh -s $FISH_PATH"
    fi
  else
    log_success "Fish is already your default shell"
  fi
else
  log_warning "Fish not installed. Install with: brew install fish"
fi

# Clone personal repositories
echo "=== Cloning personal repositories ==="

# Clone Obsidian vault if it doesn't exist
if [ ! -d "$HOME/obsidian" ]; then
  echo "Cloning Obsidian vault..."
  if git clone git@github.com:shaheislam/obsidian.git "$HOME/obsidian"; then
    log_success "Obsidian vault cloned successfully"
  else
    log_warning "Failed to clone Obsidian vault - you may need to set up SSH keys first"
    log_info "You can manually clone it later with: git clone git@github.com:shaheislam/obsidian.git ~/obsidian"
  fi
else
  log_info "Obsidian vault already exists at ~/obsidian"
fi

# Clone neovim configuration repository
if [ ! -d "$HOME/neovim" ]; then
  echo "Cloning Neovim configuration repository..."
  if git clone git@github.com:shaheislam/neovim.git "$HOME/neovim"; then
    log_success "Neovim repository cloned successfully"

    # Create symlink from dotfiles to neovim repo
    if [ -d "$HOME/dotfiles/.config/nvim" ] && [ ! -L "$HOME/dotfiles/.config/nvim" ]; then
      echo "Removing existing nvim directory to create symlink..."
      rm -rf "$HOME/dotfiles/.config/nvim"
    fi
    ln -sf "../../neovim" "$HOME/dotfiles/.config/nvim"
    log_success "Symlink created from ~/dotfiles/.config/nvim to ~/neovim"
  else
    log_warning "Failed to clone neovim repository - you may need to set up SSH keys first"
    log_info "You can manually clone it later with: git clone git@github.com:shaheislam/neovim.git ~/neovim"
  fi
else
  log_info "Neovim repository already exists at ~/neovim"

  # Ensure symlink exists even if repo was already cloned
  if [ ! -L "$HOME/dotfiles/.config/nvim" ]; then
    if [ -d "$HOME/dotfiles/.config/nvim" ]; then
      echo "Removing existing nvim directory to create symlink..."
      rm -rf "$HOME/dotfiles/.config/nvim"
    fi
    ln -sf "../../neovim" "$HOME/dotfiles/.config/nvim"
    log_success "Symlink created from ~/dotfiles/.config/nvim to ~/neovim"
  else
    log_info "Neovim symlink already exists"
  fi
fi

# Setup SSH config
echo "=== Setting up SSH configuration ==="
if [ -f "$HOME/dotfiles/.ssh/config" ] && [ ! -L "$HOME/.ssh/config" ]; then
  echo "Backing up existing SSH config to ~/.ssh/config.backup"
  cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup"
  ln -sf "$HOME/dotfiles/.ssh/config" "$HOME/.ssh/config"
  echo "SSH config linked from dotfiles"
elif [ ! -f "$HOME/.ssh/config" ]; then
  mkdir -p "$HOME/.ssh"
  ln -sf "$HOME/dotfiles/.ssh/config" "$HOME/.ssh/config"
  echo "SSH config linked from dotfiles"
else
  echo "SSH config already linked"
fi

# Configure Kubernetes Local Development Tools
echo "=== Configuring Kubernetes Local Development Tools ==="

# Create .kube directory if it doesn't exist
mkdir -p $HOME/.kube

# Initialize kubectl config if it doesn't exist
if [ ! -f "$HOME/.kube/config" ]; then
  echo "Creating initial kubectl config..."
  cat > "$HOME/.kube/config" << 'EOF'
apiVersion: v1
kind: Config
clusters: []
contexts: []
current-context: ""
preferences: {}
users: []
EOF
  chmod 600 $HOME/.kube/config
  log_success "kubectl config initialized"
else
  log_info "kubectl config already exists"
fi

# Initialize k3d with Colima if installed
if command -v k3d &> /dev/null; then
  log_info "k3d installed. Create cluster with: k3d cluster create mycluster"
  log_info "List clusters with: k3d cluster list"
fi

# Initialize kind if installed
if command -v kind &> /dev/null; then
  log_info "kind installed. Create cluster with: kind create cluster"
  log_info "List clusters with: kind get clusters"
fi

# Configure Azure Kubernetes tools
echo "=== Configuring Azure Kubernetes tools ==="
if command -v kubelogin &> /dev/null; then
  echo "Configuring kubelogin..."
  # Set proper permissions for kubeconfig
  if [ -f "$HOME/.kube/config" ]; then
    chmod 600 $HOME/.kube/config
  fi
  # Convert kubeconfig to use Azure CLI authentication
  kubelogin convert-kubeconfig -l azurecli
  echo "Azure Kubernetes tools configured successfully"
else
  echo "kubelogin not found, skipping Azure Kubernetes configuration"
fi

echo ""
# Configure Starship prompt
echo "=== Configuring Starship prompt ==="
if command -v starship &> /dev/null; then
  # Link Starship config if it exists in dotfiles
  if [ -f "$HOME/dotfiles/.config/starship.toml" ]; then
    mkdir -p "$HOME/.config"
    ln -sf "$HOME/dotfiles/.config/starship.toml" "$HOME/.config/starship.toml" 2>/dev/null || true
    log_success "Starship configuration linked"
  else
    log_info "Starship config will be created by stow"
  fi
else
  log_warning "Starship not installed. Install with: brew install starship"
fi

# Configure LaunchTemplates
echo "=== Configuring LaunchTemplates ==="
if [ -d "$HOME/dotfiles/.config/launch-templates" ]; then
  mkdir -p "$HOME/.config"
  ln -sf "$HOME/dotfiles/.config/launch-templates" "$HOME/.config/launch-templates" 2>/dev/null || true
  log_success "LaunchTemplates configured"
else
  log_info "LaunchTemplates directory not found in dotfiles"
fi


# Run stow to create all symlinks
echo "=== Running stow to create symlinks ==="
if command -v stow &> /dev/null; then
  cd "$HOME/dotfiles" || exit
  log_info "Creating symlinks with stow..."

  # Run stow with adopt flag to handle existing files
  if stow . --adopt --verbose 2>&1 | tee /tmp/stow-output.log; then
    log_success "Dotfiles symlinked successfully"

    # Check if any files were adopted
    if grep -q "LINK:" /tmp/stow-output.log; then
      log_info "Some existing files were adopted into dotfiles - review git status"
    fi
  else
    log_error "Stow encountered errors - check /tmp/stow-output.log"
    log_info "You can manually run: cd ~/dotfiles && stow . --adopt"
  fi

  # Clean up log file
  rm -f /tmp/stow-output.log

  # Fix k9s plugin paths for current user
  if [[ -f "$HOME/dotfiles/scripts/fix-k9s-paths.sh" ]]; then
    log_info "Fixing k9s plugin paths for current user..."
    if "$HOME/dotfiles/scripts/fix-k9s-paths.sh" > /dev/null 2>&1; then
      log_success "k9s plugin paths updated"
    else
      log_warning "Failed to update k9s plugin paths - run manually: ~/dotfiles/scripts/fix-k9s-paths.sh"
    fi
  fi
else
  log_error "stow not installed. Install with: brew install stow"
  log_info "After installing stow, run: cd ~/dotfiles && stow . --adopt"
fi

# Setup completion summary
echo ""
echo "=== Setup Complete! ==="
echo ""

# Display error/warning summary
if [ $SETUP_ERRORS -eq 0 ] && [ $SETUP_WARNINGS -eq 0 ]; then
    log_success "All setup steps completed successfully! 🎉"
elif [ $SETUP_ERRORS -eq 0 ]; then
    log_success "Setup completed with $SETUP_WARNINGS warnings (see above)"
    log_info "Warnings are usually non-critical and can be resolved later"
else
    log_error "Setup completed with $SETUP_ERRORS errors and $SETUP_WARNINGS warnings"
    log_info "Review the errors above and run manual fixes as needed"
    log_info "You can re-run this script to retry failed steps"
fi

echo ""
echo "Installed dependencies:"
echo "- Core tools: neovim, tmux, ripgrep, fd, bat, eza, zoxide"
echo "- Git tools: lazygit, lazydocker"
echo "- Shell enhancements: atuin, thefuck, starship"
echo "- Development tools: terraform, node, python, go, rust"
echo "- Formatters: stylua, prettier, black, isort"
echo "- Rust tools: s3grep"
echo "- Security tools: vet (safe remote script execution), gitleaks (secret detection)"
echo "- AWS log tools: aws-log-viewer (interactive s3grep TUI)"
echo "- MCP tools: pipx, browser-tools, Python MCP servers"
echo "- Claude Code: CLI tool with SuperClaude framework"
echo "- AI Tools: OpenAI Codex CLI, Claude Code Router, Opencode (with Nix LSP integration)"
echo "- Image display: ueberzugpp, imagemagick"
echo "- Fonts: DankMono Nerd Font (manual), Iosevka Nerd Font, JetBrains Mono Nerd Font (fallback)"
echo "- macOS apps: ghostty, wezterm, aerospace"
echo "- Mac App Store apps: Kinda Vim for Safari"
echo "- Personal repositories: Obsidian vault at ~/obsidian"
echo "- Sports tools: footyres (football results CLI)"
echo ""
echo "Next steps:"

# Check if Claude Code is installed and provide instructions if not
if ! command -v claude &> /dev/null; then
    echo ""
    echo "⚠️  IMPORTANT: Claude Code CLI is not installed!"
    echo "   Install Claude Code using the official installer:"
    echo "   a) Download from: https://claude.ai/download"
    echo "   b) After installation, run: claude update"
    echo "   c) If upgrading from npm/bun version, run: claude migrate-installer"
    echo "   d) Then verify MCP servers with: claude mcp list"
    echo ""
fi

echo "1. Close and reopen your terminal to use Fish shell (or run 'exec fish')"
echo "2. DankMono Nerd Font is now configured for WezTerm, tmux, and Neovim"
echo "3. Configure aerospace with 'aerospace --config ~/.config/aerospace/aerospace.toml'"
echo "5. Restart Claude Desktop to load MCP servers"
echo "6. Verify Claude Code MCP servers with 'claude mcp list' (after installing Claude Code if needed)"
echo "7. SuperClaude framework is ready via stow symlinks at ~/.claude/"
echo "8. Fish shell is now your default shell with great aliases and functions"
echo "9. Your Starship prompt should display beautiful icons!"
echo "10. Start coding!"
echo ""

# Exit with appropriate code
if [ $SETUP_ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
