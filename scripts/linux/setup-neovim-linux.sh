#!/usr/bin/env bash

# setup-neovim-linux.sh - Neovim setup for Linux systems
# Handles Neovim installation from source if needed, config cloning, and plugin setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NEOVIM_VERSION="stable"  # or "nightly" or specific version like "v0.9.5"
NEOVIM_BUILD_DIR="$HOME/.local/src/neovim"
NEOVIM_INSTALL_PREFIX="$HOME/.local"
NEOVIM_CONFIG_REPO="https://github.com/shaheislam/neovim.git"
NEOVIM_CONFIG_DIR="$HOME/.config/nvim"

# ============================================================================
# Neovim Version Check
# ============================================================================

check_neovim_version() {
    if ! command -v nvim &> /dev/null; then
        echo -e "${YELLOW}Neovim not found${NC}"
        return 1
    fi

    local current_version=$(nvim --version | head -n 1 | awk '{print $2}')
    echo -e "${GREEN}Neovim version: $current_version${NC}"

    # Check if version is sufficient (>= 0.9.0 recommended for modern configs)
    local major=$(echo "$current_version" | cut -d'v' -f2 | cut -d'.' -f1)
    local minor=$(echo "$current_version" | cut -d'v' -f2 | cut -d'.' -f2)

    if [[ $major -eq 0 && $minor -lt 9 ]]; then
        echo -e "${YELLOW}Neovim version is old, consider building from source${NC}"
        return 1
    fi

    return 0
}

# ============================================================================
# Build Neovim from Source
# ============================================================================

build_neovim_from_source() {
    echo -e "${BLUE}Building Neovim from source...${NC}"

    # Check for build dependencies
    local missing_deps=()

    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    if ! command -v make &> /dev/null; then
        missing_deps+=("make")
    fi
    if ! command -v cmake &> /dev/null; then
        missing_deps+=("cmake")
    fi
    if ! command -v gcc &> /dev/null; then
        missing_deps+=("gcc")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Missing build dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install: build-essential cmake git${NC}"
        return 1
    fi

    # Create build directory
    mkdir -p "$NEOVIM_BUILD_DIR"

    # Clone or update Neovim repository
    if [[ -d "$NEOVIM_BUILD_DIR/.git" ]]; then
        echo -e "${BLUE}Updating existing Neovim repository...${NC}"
        cd "$NEOVIM_BUILD_DIR"
        git fetch --all
        git checkout "$NEOVIM_VERSION"
        git pull
    else
        echo -e "${BLUE}Cloning Neovim repository...${NC}"
        git clone https://github.com/neovim/neovim.git "$NEOVIM_BUILD_DIR"
        cd "$NEOVIM_BUILD_DIR"
        git checkout "$NEOVIM_VERSION"
    fi

    # Build Neovim
    echo -e "${BLUE}Building Neovim (this may take several minutes)...${NC}"
    make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$NEOVIM_INSTALL_PREFIX"

    # Install Neovim
    echo -e "${BLUE}Installing Neovim to $NEOVIM_INSTALL_PREFIX...${NC}"
    make install

    # Verify installation
    if command -v "$NEOVIM_INSTALL_PREFIX/bin/nvim" &> /dev/null; then
        echo -e "${GREEN}Neovim built and installed successfully${NC}"

        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$NEOVIM_INSTALL_PREFIX/bin:"* ]]; then
            echo -e "${YELLOW}Add $NEOVIM_INSTALL_PREFIX/bin to your PATH${NC}"
            echo "export PATH=\"$NEOVIM_INSTALL_PREFIX/bin:\$PATH\"" >> ~/.bashrc
        fi
        return 0
    else
        echo -e "${RED}Neovim installation failed${NC}"
        return 1
    fi
}

# ============================================================================
# Clone Neovim Configuration
# ============================================================================

clone_neovim_config() {
    echo -e "${BLUE}Setting up Neovim configuration...${NC}"

    # Backup existing config if it exists and is not a git repo
    if [[ -d "$NEOVIM_CONFIG_DIR" && ! -d "$NEOVIM_CONFIG_DIR/.git" ]]; then
        local backup_dir="$NEOVIM_CONFIG_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Backing up existing config to $backup_dir${NC}"
        mv "$NEOVIM_CONFIG_DIR" "$backup_dir"
    fi

    # Clone config repository
    if [[ ! -d "$NEOVIM_CONFIG_DIR" ]]; then
        echo -e "${BLUE}Cloning Neovim configuration from $NEOVIM_CONFIG_REPO...${NC}"

        # Try to clone, but handle case where repo URL might need updating
        if git clone "$NEOVIM_CONFIG_REPO" "$NEOVIM_CONFIG_DIR"; then
            echo -e "${GREEN}Neovim configuration cloned successfully${NC}"
        else
            echo -e "${RED}Failed to clone Neovim configuration${NC}"
            echo -e "${YELLOW}Please update NEOVIM_CONFIG_REPO in this script or clone manually${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Neovim configuration directory already exists${NC}"
        cd "$NEOVIM_CONFIG_DIR"
        if git rev-parse --git-dir > /dev/null 2>&1; then
            echo -e "${BLUE}Updating existing configuration...${NC}"
            git pull
        fi
    fi

    return 0
}

# ============================================================================
# Install Neovim Dependencies
# ============================================================================

install_neovim_dependencies() {
    echo -e "${BLUE}Installing Neovim dependencies...${NC}"

    # Node.js (required for many LSP servers and plugins)
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}Node.js not found, installing via nvm...${NC}"
        if ! command -v nvm &> /dev/null; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        fi
        nvm install --lts
    fi

    # Python provider (optional but recommended)
    if command -v pip3 &> /dev/null; then
        echo -e "${BLUE}Installing Python Neovim provider...${NC}"
        pip3 install --user --upgrade pynvim
    fi

    # Ruby provider (optional)
    if command -v gem &> /dev/null; then
        echo -e "${BLUE}Installing Ruby Neovim provider...${NC}"
        gem install --user-install neovim
    fi

    # Clipboard support (xclip or xsel on Linux)
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo -e "${YELLOW}No clipboard tool found, install xclip or xsel for clipboard support${NC}"
    fi
}

# ============================================================================
# Install Neovim Plugins
# ============================================================================

install_neovim_plugins() {
    echo -e "${BLUE}Installing Neovim plugins...${NC}"

    # Check if lazy.nvim is configured (LazyVim setup)
    if [[ -f "$NEOVIM_CONFIG_DIR/lua/config/lazy.lua" ]] || [[ -f "$NEOVIM_CONFIG_DIR/init.lua" ]]; then
        echo -e "${BLUE}Running lazy.nvim plugin installation...${NC}"

        # Run Neovim headless to install plugins
        nvim --headless "+Lazy! sync" +qa

        echo -e "${GREEN}Plugins installed successfully${NC}"
    else
        echo -e "${YELLOW}Plugin manager not detected, skipping plugin installation${NC}"
    fi
}

# ============================================================================
# Install LSP Servers
# ============================================================================

install_lsp_servers() {
    echo -e "${BLUE}Installing common LSP servers...${NC}"

    # TypeScript/JavaScript
    if command -v npm &> /dev/null; then
        npm install -g typescript typescript-language-server
        npm install -g vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
        npm install -g bash-language-server
        npm install -g yaml-language-server
    fi

    # Python
    if command -v pip3 &> /dev/null; then
        pip3 install --user python-lsp-server
        pip3 install --user black isort ruff  # Formatters and linters
    fi

    # Go (if Go is installed)
    if command -v go &> /dev/null; then
        go install golang.org/x/tools/gopls@latest
    fi

    # Lua (for Neovim config editing)
    if command -v cargo &> /dev/null; then
        cargo install stylua
    fi

    echo -e "${GREEN}LSP servers installed${NC}"
}

# ============================================================================
# Main Setup Function
# ============================================================================

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Neovim Setup for Linux${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Check if Neovim is already installed and up-to-date
    if check_neovim_version; then
        echo -e "${GREEN}Neovim is already installed with a suitable version${NC}"
    else
        echo -e "${YELLOW}Neovim needs to be installed or updated${NC}"

        # Ask if user wants to build from source
        read -p "Build Neovim from source? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! build_neovim_from_source; then
                echo -e "${RED}Failed to build Neovim from source${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Please install Neovim manually${NC}"
            exit 1
        fi
    fi

    # Clone/update Neovim configuration
    if ! clone_neovim_config; then
        echo -e "${YELLOW}Neovim configuration setup incomplete${NC}"
    fi

    # Install dependencies
    install_neovim_dependencies

    # Install LSP servers
    install_lsp_servers

    # Install plugins
    install_neovim_plugins

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Neovim setup complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${BLUE}Run 'nvim' to start Neovim${NC}"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
