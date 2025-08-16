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
  "shellcheck"
  "shfmt"
  "gh"
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

# Install Cursor
if app_installed "Cursor"; then
  echo "Cursor already installed"
else
  echo "Installing Cursor..."
  curl https://cursor.com/install -fsS | bash || log_error "Failed to install Cursor"
fi

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

echo "Tmux setup complete. After starting tmux, press 'prefix' + 'I' (capital i) to install the plugins."

# Apply tmux-continuum fix
echo "=== Applying tmux-continuum fix ==="
if [ -f "$(pwd)/scripts/fix_tmux_continuum.sh" ]; then
  bash "$(pwd)/scripts/fix_tmux_continuum.sh"
else
  echo "Warning: fix_tmux_continuum.sh script not found"
fi

# tmux-fingers is now installed via Homebrew (see Brewfile)


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

  echo "Python MCP servers installation complete"
else
  echo "Warning: pipx not found. Install pipx first via Homebrew"
  echo "Run: brew install pipx"
fi

# Install Claude Code CLI
echo "=== Installing Claude Code CLI ==="
if ! command -v claude &> /dev/null; then
  echo "Installing Claude Code CLI via npm..."
  bun install -g @anthropic-ai/claude-code || npm install -g @anthropic-ai/claude-code || echo "Warning: Failed to install Claude Code CLI"
  
  # Install Claude Code Router for alternative AI providers
  echo "Installing Claude Code Router..."
  npm install -g @musistudio/claude-code-router || echo "Warning: Failed to install Claude Code Router"
else
  echo "Claude Code CLI already installed"
  # Still install Claude Code Router if not present
  if ! command -v ccr &> /dev/null; then
    echo "Installing Claude Code Router..."
    bun install -g @musistudio/claude-code-router || npm install -g @musistudio/claude-code-router || echo "Warning: Failed to install Claude Code Router"
  fi
fi

# Setup Claude Code Router configuration
if [ -f "$HOME/dotfiles/.config/claude-code-router/config.json" ] && [ ! -f "$HOME/.claude-code-router/config.json" ]; then
  echo "Setting up Claude Code Router configuration..."
  mkdir -p "$HOME/.claude-code-router"
  ln -s "$HOME/dotfiles/.config/claude-code-router/config.json" "$HOME/.claude-code-router/config.json"
  echo "Claude Code Router configuration linked from dotfiles"
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

  # Database tools
  claude mcp add --scope user sqlite pipx run mcp-server-sqlite "$HOME/Documents/databases" || echo "Warning: Failed to add sqlite MCP"
  claude mcp add --scope user postgres npx @modelcontextprotocol/server-postgres || echo "Warning: Failed to add postgres MCP"

  # Enterprise integration
  claude mcp add --scope user slack npx @modelcontextprotocol/server-slack || echo "Warning: Failed to add slack MCP"
  claude mcp add --scope user airbnb "npx @openbnb/mcp-server-airbnb --ignore-robots-txt" || echo "Warning: Failed to add airbnb MCP"

  # Browser automation (Microsoft Playwright)
  claude mcp add --scope user playwright npx @playwright/mcp@latest || echo "Warning: Failed to add playwright MCP"

  # AWS MCP servers (require uv to be installed)
  echo "Adding AWS MCP servers to Claude Code..."

  # Core AWS tools (no credentials required)
  claude mcp add --scope user aws-documentation uvx awslabs.aws-documentation-mcp-server@latest || echo "Warning: Failed to add aws-documentation MCP"
  claude mcp add --scope user aws-cdk uvx awslabs.cdk-mcp-server@latest || echo "Warning: Failed to add aws-cdk MCP"
  claude mcp add --scope user aws-terraform uvx awslabs.terraform-mcp-server@latest || echo "Warning: Failed to add aws-terraform MCP"

  # AWS services (require AWS credentials)
  claude mcp add --scope user aws-cost-analysis uvx awslabs.cost-analysis-mcp-server@latest || echo "Warning: Failed to add aws-cost-analysis MCP"
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
  echo "Some MCP servers are disabled by default in Claude Desktop:"
  echo "- exa (requires EXA_API_KEY)"
  echo "- linear (requires LINEAR_API_KEY)"
  echo "- slack (requires SLACK_BOT_TOKEN and SLACK_APP_TOKEN)"
  echo "- postgres (requires POSTGRES_CONNECTION_STRING)"
  echo ""
  echo "API-based servers are configured in Claude Code but will fail without credentials."
  echo "Configure API keys/credentials in the Claude Desktop config file to enable them."
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
mkdir -p "$HOME/.config/"{nvim,ghostty,wezterm,aerospace,sketchybar,atuin,fish}
mkdir -p "$HOME/Library/Application Support/Claude"
mkdir -p "$HOME/Documents/databases"

# Install Neovim plugins automatically
echo "=== Installing Neovim plugins ==="
if command -v nvim &> /dev/null; then
  echo "Installing Neovim plugins via Lazy.nvim..."
  nvim --headless "+Lazy! sync" +qa
  echo "Neovim plugins installed successfully"
else
  echo "Warning: Neovim not found. Skipping plugin installation."
fi

# Run p10k configuration if it doesn't exist
if [ ! -f "$HOME/.p10k.zsh" ]; then
  echo "=== Setting up Powerlevel10k ==="
  echo "Please run 'p10k configure' after this script completes to set up your terminal prompt"
fi

# Configure global gitignore
echo "=== Configuring global gitignore ==="
git config --global core.excludesfile ~/.gitignore_global
echo "Global gitignore configured to use ~/.gitignore_global"

# Configure Claude Code
echo "=== Configuring Claude Code ==="
if command -v claude &> /dev/null; then
    claude config set --global preferredNotifChannel terminal_bell
    echo "Claude Code notification channel set to terminal_bell"
else
    echo "Claude Code not found, skipping configuration"
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

# Configure Azure Kubernetes tools
echo "=== Configuring Azure Kubernetes tools ==="
if command -v kubelogin &> /dev/null; then
  echo "Configuring kubelogin..."
  # Create .kube directory if it doesn't exist
  mkdir -p $HOME/.kube
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
echo "- Security tools: vet (safe remote script execution), gitleaks (secret detection), pre-commit (git hooks framework)"
echo "- AWS log tools: aws-log-viewer (interactive s3grep TUI)"
echo "- MCP tools: pipx, browser-tools, Python MCP servers"
echo "- Claude Code: CLI tool with SuperClaude framework"
echo "- Image display: ueberzugpp, imagemagick"
echo "- Fonts: JetBrains Mono Nerd Font, Fira Code Nerd Font, Hack Nerd Font"
echo "- macOS apps: ghostty, wezterm, aerospace, sketchybar"
echo ""
echo "Next steps:"
echo "1. Close and reopen your terminal or run 'source ~/.zshrc'"
echo "2. Configure iTerm2 to use 'JetBrainsMono Nerd Font' in Preferences → Profiles → Text"
echo "3. Set up your dotfiles with 'stow . --adopt' (includes SuperClaude configuration and git hooks)"
echo "4. Configure aerospace with 'aerospace --config ~/.config/aerospace/aerospace.toml'"
echo "5. Start sketchybar: 'brew services start sketchybar'"
echo "6. Restart Claude Desktop to load MCP servers"
echo "7. Verify Claude Code MCP servers with 'claude mcp list'"
echo "8. SuperClaude framework is ready via stow symlinks at ~/.claude/"
echo "9. Pre-commit framework installed globally with gitleaks and other hooks"
echo "10. Run 'pre-commit install' in any git repo to enable hooks"
echo "11. Your Starship prompt should display beautiful icons!"
echo ""

# Exit with appropriate code
if [ $SETUP_ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
