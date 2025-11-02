#!/usr/bin/env bash

# setup.sh - Universal Cross-Platform Dotfiles Setup
# Works on macOS and Linux with online/offline modes and flexible profiles

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
PROFILE="${PROFILE:-standard}"
OS="${OS:-auto}"
MODE="${MODE:-auto}"
DRY_RUN=false
NO_CONFIRM=false
VERBOSE=false
SKIP_PACKAGES=false
SKIP_DOTFILES=false
SKIP_SHELLS=false
SKIP_FONTS_APPS=false

# ============================================================================
# Help
# ============================================================================

show_help() {
    cat << EOF
Universal Dotfiles Setup - Cross-Platform Installation

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --profile <name>           Installation profile (minimal|standard|comprehensive|dev|ops)
    --os <type>                OS type (auto|macos|linux) - default: auto-detect
    --mode <mode>              Installation mode (auto|online|offline) - default: auto-detect
    --offline-package <path>   Path to offline package for offline installation

    --dry-run                  Preview actions without executing
    --no-confirm               Skip confirmation prompts
    --verbose                  Show detailed output

    --skip-packages            Skip package installation
    --skip-dotfiles            Skip dotfiles symlinking
    --skip-shells              Skip shell configuration
    --skip-fonts-apps          Skip fonts and GUI applications (macOS)

    -h, --help                 Show this help message

PROFILES:
    minimal         Essential tools only (fastest)
    standard        Balanced installation (default)
    comprehensive   Everything installed
    dev             Development-focused tools
    ops             DevOps/SRE focused tools

EXAMPLES:
    # Auto-detect everything, standard profile
    $0

    # Minimal installation on Linux
    $0 --profile minimal --os linux

    # Comprehensive development setup
    $0 --profile comprehensive

    # Offline installation
    $0 --mode offline --offline-package ~/dotfiles-offline.tar.gz

    # Dry run to preview
    $0 --profile dev --dry-run

    # Automated installation (CI/scripts)
    $0 --profile minimal --no-confirm

    # Enable optional features (Nix, Pulse)
    ENABLE_NIX=true ENABLE_PULSE=true $0 --profile comprehensive

    # Clone personal repositories (set environment variables)
    OBSIDIAN_REPO=git@github.com:user/obsidian.git \\
    NVIM_REPO=git@github.com:user/nvim.git \\
    $0 --profile standard

ENVIRONMENT VARIABLES:
    ENABLE_NIX=true         Enable Nix package manager installation (Phase 11)
    ENABLE_PULSE=true       Enable Pulse coding tracker installation (Phase 11)
    OBSIDIAN_REPO=<url>     Clone Obsidian vault from repository (Phase 10)
    NVIM_REPO=<url>         Clone personal Neovim config (Phase 10)

For more information: https://github.com/shaheislam/dotfiles

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --os)
                OS="$2"
                shift 2
                ;;
            --mode)
                MODE="$2"
                shift 2
                ;;
            --offline-package)
                OFFLINE_PACKAGE="$2"
                MODE="offline"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-confirm)
                NO_CONFIRM=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                shift
                ;;
            --skip-dotfiles)
                SKIP_DOTFILES=true
                shift
                ;;
            --skip-shells)
                SKIP_SHELLS=true
                shift
                ;;
            --skip-fonts-apps)
                SKIP_FONTS_APPS=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Export for child modules
    export PROFILE DRY_RUN NO_CONFIRM VERBOSE SKIP_PACKAGES SKIP_DOTFILES SKIP_SHELLS
    export DOTFILES_ROOT SCRIPT_DIR
}

# ============================================================================
# Load Modules
# ============================================================================

load_modules() {
    # Load common utilities
    # shellcheck source=./lib/common.sh
    source "$SCRIPT_DIR/lib/common.sh"

    # Load package manager
    # shellcheck source=./lib/package-manager.sh
    source "$SCRIPT_DIR/lib/package-manager.sh"

    # Load other modules
    # shellcheck source=./lib/binary-installer.sh
    source "$SCRIPT_DIR/lib/binary-installer.sh"

    # shellcheck source=./lib/shell-setup.sh
    source "$SCRIPT_DIR/lib/shell-setup.sh"

    # shellcheck source=./lib/dotfiles-manager.sh
    source "$SCRIPT_DIR/lib/dotfiles-manager.sh"
}

# ============================================================================
# Preflight Checks
# ============================================================================

preflight_checks() {
    print_header "Preflight Checks"

    # Check disk space
    if ! check_disk_space 500; then
        print_error "Insufficient disk space"
        exit 1
    fi

    # Check required commands
    if ! check_required_commands bash curl; then
        print_error "Missing required commands"
        exit 1
    fi

    # Check profile exists
    if [[ ! -f "$SCRIPT_DIR/profiles/$PROFILE.conf" ]]; then
        print_error "Profile not found: $PROFILE"
        print_warning "Available profiles: minimal, standard, comprehensive, dev, ops"
        exit 1
    fi

    # Detect OS if auto
    if [[ "$OS" == "auto" ]]; then
        OS=$(detect_os)
        print_success "Detected OS: $OS"
    fi

    # Load OS-specific package manager
    if ! load_package_manager; then
        print_error "Failed to load package manager"
        exit 1
    fi

    # Detect mode if auto
    if [[ "$MODE" == "auto" ]]; then
        MODE=$(detect_installation_mode)
        print_success "Installation mode: $MODE"
    fi

    print_success "Preflight checks passed"
}

# ============================================================================
# Display Summary
# ============================================================================

show_summary() {
    print_header "Installation Summary"

    echo "Operating System: $DETECTED_OS"
    echo "Architecture: $DETECTED_ARCH"
    echo "Profile: $PROFILE"
    echo "Mode: $DETECTED_MODE"
    echo "Sudo Access: ${HAS_SUDO:-false}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    if [[ "$NO_CONFIRM" != "true" ]]; then
        confirm "Proceed with installation?" || exit 0
    fi
}

# ============================================================================
# Installation Phases
# ============================================================================

phase_1_core_packages() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "core_packages") == "true" ]] && return 0

    print_header "Phase 1: Core Packages"

    pm_update

    install_packages_from_profile "$PROFILE" "core"

    mark_step_complete "core_packages"
}

phase_2_cli_tools() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "cli_tools") == "true" ]] && return 0

    print_header "Phase 2: CLI Tools"

    # Try package manager first
    install_packages_from_profile "$PROFILE" "cli_tools"

    # Install binaries for tools not in repos
    install_binaries_from_profile "$PROFILE"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping CLI tool post-install configuration"
        mark_step_complete "cli_tools"
        return 0
    fi

    # Configure bat with Tokyo Night theme
    if command_exists bat; then
        print_step "Configuring bat with Tokyo Night theme..."
        mkdir -p "$(bat --config-dir)/themes"
        if curl -sL https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme \
            -o "$(bat --config-dir)/themes/tokyonight_night.tmTheme"; then
            bat cache --build >/dev/null 2>&1
            echo '--theme="tokyonight_night"' > "$(bat --config-dir)/config"
            print_success "Bat configured with Tokyo Night theme"
        else
            print_warning "Failed to download Tokyo Night theme for bat"
        fi
    fi

    mark_step_complete "cli_tools"
}

phase_3_development() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "development") == "true" ]] && return 0

    print_header "Phase 3: Development Tools"

    install_packages_from_profile "$PROFILE" "development"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping language toolchain installers and pipx installs"
        mark_step_complete "development"
        return 0
    fi

    # Node.js via nvm
    if [[ $(get_package_list_from_profile "$PROFILE" "development") =~ nodejs ]]; then
        # Check if Node.js is already installed (via Homebrew, system, or nvm)
        if command_exists node; then
            print_success "Node.js already installed: $(node --version)"
            log_verbose "Skipping nvm installation"
        elif [[ -d "$HOME/.nvm" ]]; then
            print_success "nvm already installed"
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        else
            print_step "Installing Node.js via nvm..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            nvm install --lts
        fi

        # Install Node.js global packages
        if command_exists npm; then
            print_step "Installing Node.js global packages..."
            # Install prettierd and prettier-plugin-toml
            if command_exists bun; then
                bun install -g @fsouza/prettierd prettier-plugin-toml >/dev/null 2>&1 || \
                npm install -g @fsouza/prettierd prettier-plugin-toml >/dev/null 2>&1
            else
                npm install -g @fsouza/prettierd prettier-plugin-toml >/dev/null 2>&1
            fi
            print_success "Installed prettierd and prettier-plugin-toml"
        fi
    fi

    # Rust via rustup
    if [[ $(get_package_list_from_profile "$PROFILE" "development") =~ rust ]]; then
        # Check if Rust is already installed
        if command_exists rustc; then
            print_success "Rust already installed: $(rustc --version)"
            log_verbose "Skipping rustup installation"
        elif [[ -d "$HOME/.cargo" ]]; then
            print_success "Rust toolchain already installed"
            source "$HOME/.cargo/env" 2>/dev/null || true
        else
            print_step "Installing Rust via rustup..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi
    fi

    # Install Python MCP servers via pipx
    if command_exists pipx; then
        print_step "Installing Python-based MCP servers..."
        pipx install mcp-server-git >/dev/null 2>&1 || print_warning "Failed to install mcp-server-git"
        pipx install mcp-server-fetch >/dev/null 2>&1 || print_warning "Failed to install mcp-server-fetch"
        pipx install mcp-server-sqlite >/dev/null 2>&1 || print_warning "Failed to install mcp-server-sqlite"
        pipx install diagrams >/dev/null 2>&1 || print_warning "Failed to install diagrams (for AWS diagram MCP)"
        print_success "Python MCP servers installation complete"
    fi

    mark_step_complete "development"
}

phase_4_cloud_tools() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "cloud_tools") == "true" ]] && return 0

    print_header "Phase 4: Cloud & Infrastructure Tools"

    install_packages_from_profile "$PROFILE" "cloud"
    install_packages_from_profile "$PROFILE" "kubernetes"
    install_packages_from_profile "$PROFILE" "containers"
    install_packages_from_profile "$PROFILE" "security"
    install_packages_from_profile "$PROFILE" "monitoring"
    install_packages_from_profile "$PROFILE" "network"
    install_packages_from_profile "$PROFILE" "performance"
    install_packages_from_profile "$PROFILE" "data"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping cloud tool post-install steps and MCP configuration"
        mark_step_complete "cloud_tools"
        return 0
    fi

    # Claude Code CLI check
    print_step "Checking Claude Code CLI..."
    if ! command_exists claude; then
        print_warning "Claude Code CLI not found"
        echo "  Install Claude Code using the official installer:"
        echo "  1. Download from: https://claude.ai/download"
        echo "  2. Run: claude update"
        echo "  3. Run: claude migrate-installer (if upgrading from npm/bun version)"
    else
        print_success "Claude Code CLI installed at: $(which claude)"
        log_verbose "To update, run: claude update"
    fi

    # Install Claude Code Router
    if ! command_exists ccr; then
        print_step "Installing Claude Code Router..."
        if command_exists bun; then
            bun install -g @musistudio/claude-code-router >/dev/null 2>&1 && \
                print_success "Claude Code Router installed" || \
                print_warning "Failed to install Claude Code Router"
        elif command_exists npm; then
            npm install -g @musistudio/claude-code-router >/dev/null 2>&1 && \
                print_success "Claude Code Router installed" || \
                print_warning "Failed to install Claude Code Router"
        fi
    else
        print_success "Claude Code Router already installed at: $(which ccr)"
    fi

    # Setup Claude Code Router configuration
    if [[ -f "$DOTFILES_ROOT/.config/claude-code-router/config.json" ]] && [[ ! -f "$HOME/.claude-code-router/config.json" ]]; then
        print_step "Setting up Claude Code Router configuration..."
        mkdir -p "$HOME/.claude-code-router"
        ln -sf "$DOTFILES_ROOT/.config/claude-code-router/config.json" "$HOME/.claude-code-router/config.json"
        print_success "Claude Code Router configuration linked from dotfiles"
    fi

    # Ensure claude wrapper is executable (runs Claude under Node 20 only)
    if [[ -f "$DOTFILES_ROOT/scripts/bin/claude" ]]; then
        chmod +x "$DOTFILES_ROOT/scripts/bin/claude" 2>/dev/null || true
    fi

    # Install OpenAI Codex CLI (with sudo fallback for Linux)
    if ! command_exists codex; then
        print_step "Installing OpenAI Codex CLI..."
        if command_exists bun; then
            bun add -g @openai/codex >/dev/null 2>&1 && \
                print_success "OpenAI Codex CLI installed" || \
                log_verbose "OpenAI Codex CLI installation skipped (optional)"
        elif command_exists npm; then
            # Try global install first, fallback to user-local on Linux
            if npm install -g @openai/codex >/dev/null 2>&1; then
                print_success "OpenAI Codex CLI installed"
            else
                # Fallback to user-local installation
                npm install --prefix "$HOME/.local" @openai/codex >/dev/null 2>&1 && \
                    export PATH="$HOME/.local/node_modules/.bin:$PATH" && \
                    print_success "OpenAI Codex CLI installed (user-local)" || \
                    log_verbose "OpenAI Codex CLI installation skipped (optional)"
            fi
        fi
    else
        print_success "OpenAI Codex CLI already installed at: $(which codex)"
    fi

    # Configure Claude Code MCP servers
    if command_exists claude; then
        print_step "Configuring Claude Code MCP servers..."

        # Core development tools
        claude mcp add --scope user filesystem npx @modelcontextprotocol/server-filesystem "$HOME/Desktop" "$HOME/Downloads" >/dev/null 2>&1 || true
        claude mcp add --scope user git pipx run mcp-server-git "$HOME/dotfiles" >/dev/null 2>&1 || true
        claude mcp add --scope user github npx @modelcontextprotocol/server-github >/dev/null 2>&1 || true
        claude mcp add --scope user memory npx @modelcontextprotocol/server-memory >/dev/null 2>&1 || true
        claude mcp add --scope user sequential-thinking npx @modelcontextprotocol/server-sequential-thinking >/dev/null 2>&1 || true

        # Web and automation tools
        claude mcp add --scope user browser-tools npx @agentdeskai/browser-tools-mcp@1.2.0 >/dev/null 2>&1 || true

        # Download and install Browser Tools Chrome extension
        local browser_tools_dir="$HOME/.config/browser-tools"
        mkdir -p "$browser_tools_dir"
        if [[ ! -d "$browser_tools_dir/chrome-extension" ]]; then
            print_step "Downloading Browser Tools extension..."
            local latest_release=$(curl -s https://api.github.com/repos/agentdeskai/browser-tools/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
            if [[ -n "$latest_release" ]]; then
                local download_url="https://github.com/agentdeskai/browser-tools/releases/download/${latest_release}/BrowserTools-extension.zip"
                if curl -sL "$download_url" -o "$browser_tools_dir/BrowserTools-extension.zip" 2>/dev/null; then
                    unzip -q "$browser_tools_dir/BrowserTools-extension.zip" -d "$browser_tools_dir" 2>/dev/null
                    rm "$browser_tools_dir/BrowserTools-extension.zip"
                    print_success "Browser Tools extension downloaded"

                    # OS-specific installation instructions
                    log_verbose "Extension directory: $browser_tools_dir/chrome-extension"
                    if [[ "$(uname -s)" == "Darwin" ]]; then
                        log_verbose "Chrome: chrome://extensions → Load unpacked → $browser_tools_dir/chrome-extension"
                        log_verbose "Or copy to: ~/Library/Application Support/Google/Chrome/Default/Extensions/"
                    else
                        log_verbose "Chrome/Chromium: chrome://extensions → Load unpacked → $browser_tools_dir/chrome-extension"
                        log_verbose "Or copy to: ~/.config/google-chrome/Default/Extensions/"
                        log_verbose "Firefox: about:debugging#/runtime/this-firefox → Load Temporary Add-on"
                    fi
                fi
            fi
        fi

        # Install Browser Tools MCP server package
        if command_exists bun; then
            bun add -g @agentdeskai/browser-tools-server@1.2.0 >/dev/null 2>&1 || true
        elif command_exists npm; then
            npm install -g @agentdeskai/browser-tools-server@1.2.0 >/dev/null 2>&1 || true
        fi

        claude mcp add --scope user fetch pipx run mcp-server-fetch >/dev/null 2>&1 || true
        claude mcp add --scope user duckduckgo npx duckduckgo-mcp-server >/dev/null 2>&1 || true

        # Additional MCP servers
        claude mcp add --scope user context7 bunx @upstash/context7-mcp >/dev/null 2>&1 || true
        claude mcp add --scope user steampipe npx @turbot/steampipe-mcp postgresql://steampipe@localhost:9193/steampipe >/dev/null 2>&1 || true
        claude mcp add --scope user playwright bunx @playwright/mcp@latest >/dev/null 2>&1 || true
        claude mcp add --scope user drawio npx -y drawio-mcp-server >/dev/null 2>&1 || true
        claude mcp add --scope user genai-toolbox bunx @googlegenai/genai-toolbox >/dev/null 2>&1 || true

        # AWS MCP servers
        claude mcp add --scope user aws-documentation uvx awslabs.aws-documentation-mcp-server@latest >/dev/null 2>&1 || true
        claude mcp add --scope user aws-diagram uvx awslabs.aws-diagram-mcp-server >/dev/null 2>&1 || true
        claude mcp add --scope user aws-cdk uvx awslabs.cdk-mcp-server@latest >/dev/null 2>&1 || true
        claude mcp add --scope user aws-terraform uvx awslabs.terraform-mcp-server@latest >/dev/null 2>&1 || true
        claude mcp add --scope user aws-iam uvx awslabs.iam-mcp-server@latest >/dev/null 2>&1 || true
        claude mcp add --scope user aws-cloudformation uvx awslabs.cfn-mcp-server@latest >/dev/null 2>&1 || true
        claude mcp add --scope user aws-dynamodb uvx awslabs.dynamodb-mcp-server@latest >/dev/null 2>&1 || true
        claude mcp add --scope user aws-lambda uvx awslabs.lambda-tool-mcp-server@latest >/dev/null 2>&1 || true

        print_success "Claude Code MCP configuration complete"
        log_verbose "Verify with: claude mcp list"

        # Configure Claude Code global settings
        claude config set --global preferredNotifChannel terminal_bell >/dev/null 2>&1 && \
            print_success "Claude Code notification channel set to terminal_bell" || true
    fi

    mark_step_complete "cloud_tools"
}

phase_5_editors() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "editors") == "true" ]] && return 0

    print_header "Phase 5: Editors"

    install_packages_from_profile "$PROFILE" "editors"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping Neovim plugin bootstrap and Python support"
        mark_step_complete "editors"
        return 0
    fi

    # Install Neovim plugins automatically
    if command_exists nvim; then
        print_step "Installing Neovim plugins via Lazy.nvim..."
        nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 && \
            print_success "Neovim plugins installed successfully" || \
            print_warning "Neovim plugin installation had issues (this is normal on first run)"

        # Install pynvim for Python support
        if command_exists python3; then
            print_step "Installing pynvim for Neovim Python support..."
            python3 -m pip install --user pynvim >/dev/null 2>&1 && \
                print_success "pynvim installed" || \
                log_verbose "pynvim installation completed with warnings"
        fi
    fi

    mark_step_complete "editors"
}

phase_6_multiplexer() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "multiplexer") == "true" ]] && return 0

    print_header "Phase 6: Terminal Multiplexer"

    install_packages_from_profile "$PROFILE" "multiplexer"

    # Install TPM
    if command_exists tmux && [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        print_step "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi

    # Manually install tmux plugins (ensures immediate availability)
    if command_exists tmux && [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        print_step "Installing tmux plugins..."

        local plugins_dir="$HOME/.tmux/plugins"
        local tmux_plugins=(
            "tmux-plugins/tmux-sensible"
            "tmux-plugins/tmux-yank"
            "tmux-plugins/tmux-prefix-highlight"
            "tmux-plugins/tmux-open"
            "tmux-plugins/tmux-copycat"
            "tmux-plugins/tmux-pain-control"
            "tmux-plugins/tmux-sidebar"
            "Morantron/tmux-fingers"
            "tmux-plugins/tmux-battery"
            "tmux-plugins/tmux-cpu"
            "omerxx/tmux-floax"
            "tmux-plugins/tmux-resurrect"
            "tmux-plugins/tmux-continuum"
            "alexwforsythe/tmux-which-key"
            "27medkamal/tmux-session-wizard"
            "omerxx/tmux-sessionx"
        )

        for plugin in "${tmux_plugins[@]}"; do
            local plugin_name="${plugin##*/}"
            if [[ ! -d "$plugins_dir/$plugin_name" ]]; then
                log_verbose "Installing $plugin_name..."
                git clone "https://github.com/$plugin.git" "$plugins_dir/$plugin_name" 2>/dev/null || true
            fi
        done

        print_success "Tmux plugins installed"
    fi

    # Apply Dracula theme customizations
    if [[ -f "$DOTFILES_ROOT/scripts/setup-tmux-dracula.sh" ]]; then
        print_step "Applying Dracula theme customizations..."
        bash "$DOTFILES_ROOT/scripts/setup-tmux-dracula.sh" >/dev/null 2>&1 && \
            print_success "Dracula theme customizations applied" || \
            log_verbose "Dracula theme setup completed with warnings"
    fi

    # Apply tmux-continuum fix
    if [[ -f "$DOTFILES_ROOT/scripts/fix_tmux_continuum.sh" ]]; then
        print_step "Applying tmux-continuum fix..."
        bash "$DOTFILES_ROOT/scripts/fix_tmux_continuum.sh" >/dev/null 2>&1 && \
            print_success "tmux-continuum fix applied" || \
            log_verbose "tmux-continuum fix completed with warnings"
    fi

    # Apply Floax plugin fix
    if [[ -f "$DOTFILES_ROOT/scripts/fix-floax-plugin.sh" ]]; then
        print_step "Applying Floax plugin fix..."
        bash "$DOTFILES_ROOT/scripts/fix-floax-plugin.sh" >/dev/null 2>&1 && \
            print_success "Floax plugin fix applied" || \
            log_verbose "Floax plugin fix completed with warnings"
    fi

    # Configure tmux-session-wizard dependencies
    if [[ -d "$HOME/.tmux/plugins/tmux-session-wizard" ]]; then
        chmod +x "$HOME/.tmux/plugins/tmux-session-wizard/bin/t" 2>/dev/null || true
        print_success "tmux-session-wizard configured (use Prefix+T)"
    fi

    # Configure tmux-which-key plugin
    if [[ -d "$HOME/.tmux/plugins/tmux-which-key" ]] && command_exists python3; then
        print_step "Configuring tmux-which-key..."
        (cd "$HOME/.tmux/plugins/tmux-which-key" && \
         [[ ! -f "config.yaml" ]] && cp config.example.yaml config.yaml; \
         python3 plugin/build.py config.yaml plugin/init.tmux) >/dev/null 2>&1 && \
            print_success "tmux-which-key configured" || \
            log_verbose "tmux-which-key configuration completed"
    fi

    mark_step_complete "multiplexer"
}

phase_7_shells() {
    [[ "$SKIP_SHELLS" == "true" ]] && return 0
    [[ $(is_step_complete "shells") == "true" ]] && return 0

    print_header "Phase 7: Shell Configuration"

    install_packages_from_profile "$PROFILE" "shells"

    setup_shells_from_profile "$PROFILE"

    mark_step_complete "shells"
}

phase_8_dotfiles() {
    [[ "$SKIP_DOTFILES" == "true" ]] && return 0
    [[ $(is_step_complete "dotfiles") == "true" ]] && return 0

    print_header "Phase 8: Dotfiles"

    stow_dotfiles

    mark_step_complete "dotfiles"
}

phase_9_fonts_and_apps() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "fonts_and_apps") == "true" ]] && return 0

    print_header "Phase 9: Fonts & Applications"

    [[ "$SKIP_FONTS_APPS" == "true" ]] && { print_warning "Skipping fonts/apps (flag)"; mark_step_complete "fonts_and_apps"; return 0; }

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping font and GUI application installation"
        mark_step_complete "fonts_and_apps"
        return 0
    fi

    # macOS-specific installations
    if [[ "$DETECTED_OS" == "macos" ]]; then
        # Install Nerd Fonts
        print_step "Installing Nerd Fonts..."
        local fonts=(
            "font-iosevka-nerd-font"
            "font-jetbrains-mono-nerd-font"
            "font-fira-code-nerd-font"
            "font-hack-nerd-font"
        )
        for font in "${fonts[@]}"; do
            if pm_is_installed "$font"; then
                print_success "$font already installed"
            else
                if brew install --cask "$font" >/dev/null 2>&1; then
                    print_success "$font installed"
                else
                    print_warning "Failed to install $font"
                fi
            fi
        done

        # Check for DankMono Nerd Font
        if fc-list 2>/dev/null | grep -qi "DankMono"; then
            print_success "DankMono Nerd Font is installed"
        else
            print_warning "DankMono Nerd Font not found - install manually from:"
            echo "  https://github.com/saifulapm/my-fonts"
            echo "  Then: cp /tmp/my-fonts/DankMono\\ Nerd\\ Font/*.otf ~/Library/Fonts/"
        fi

        # Install GUI Applications
        print_step "Installing GUI Applications..."
        local gui_apps=(
            "raycast"
            "wezterm"
            "nikitabobko/tap/aerospace"
            "willow"
            "amazon-q"
            "ngrok"
            "altair-graphql-client"
        )

        for app in "${gui_apps[@]}"; do
            local app_name="${app##*/}"
            if pm_is_installed "$app_name"; then
                print_success "$app_name already installed"
            else
                if brew install --cask "$app" >/dev/null 2>&1; then
                    print_success "$app_name installed"
                else
                    log_verbose "Failed to install $app_name (may not be available)"
                fi
            fi
        done

        # Install Mac App Store applications
        if command_exists mas; then
            print_step "Installing Mac App Store applications..."
            if mas account >/dev/null 2>&1; then
                # Install Kinda Vim for Safari
                if mas list | grep -q "1609556629"; then
                    print_success "Kinda Vim for Safari already installed"
                else
                    mas install 1609556629 >/dev/null 2>&1 && \
                        print_success "Kinda Vim for Safari installed" || \
                        print_warning "Failed to install Kinda Vim for Safari"
                fi
            else
                print_warning "Not signed into Mac App Store - skipping App Store applications"
                echo "  To install manually:"
                echo "  1. Sign into Mac App Store"
                echo "  2. Run: mas install 1609556629  # Kinda Vim for Safari"
            fi
        fi

        # Execute macOS defaults configuration
        if [[ -f "$DOTFILES_ROOT/scripts/setup/macos-defaults.sh" ]]; then
            print_step "Applying macOS system defaults..."
            bash "$DOTFILES_ROOT/scripts/setup/macos-defaults.sh" >/dev/null 2>&1 && \
                print_success "macOS defaults configured (Finder, Dock, developer settings)" || \
                log_verbose "macOS defaults completed with warnings"
        fi
    else
        # Linux/other OS
        print_info "Font and GUI application installation is macOS-specific"
        log_verbose "Phase 9 operations skipped on $DETECTED_OS (safe to skip)"
    fi

    mark_step_complete "fonts_and_apps"
}

phase_10_advanced_features() {
    [[ $(is_step_complete "advanced_features") == "true" ]] && return 0

    print_header "Phase 10: Advanced Features"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping Kubernetes init, cargo installs, and repo cloning"
        mark_step_complete "advanced_features"
        return 0
    fi

    # Kubernetes initialization
    if command_exists kubectl; then
        print_step "Initializing Kubernetes configuration..."
        mkdir -p "$HOME/.kube"
        touch "$HOME/.kube/config"
        chmod 600 "$HOME/.kube/config"

        # Initialize kubelogin for Azure (if installed)
        if command_exists kubelogin; then
            kubelogin convert-kubeconfig >/dev/null 2>&1 && \
                print_success "Azure kubelogin initialized" || \
                log_verbose "kubelogin initialization skipped"
        fi
        print_success "Kubernetes configuration initialized"
    fi

    # Rust tools installation
    if command_exists cargo; then
        print_step "Installing Rust development tools..."
        cargo install stylua s3grep >/dev/null 2>&1 && \
            print_success "Rust tools installed (stylua, s3grep)" || \
            log_verbose "Rust tools installation completed with warnings"
    fi

    # Personal repositories (optional - check for SSH key)
    if [[ -f "$HOME/.ssh/id_rsa" ]] || [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        print_step "Cloning personal repositories..."

        # Clone Obsidian vault (if configured)
        local obsidian_repo="${OBSIDIAN_REPO:-}"
        if [[ -n "$obsidian_repo" ]] && [[ ! -d "$HOME/obsidian" ]]; then
            git clone "$obsidian_repo" "$HOME/obsidian" 2>/dev/null && \
                print_success "Obsidian vault cloned" || \
                log_verbose "Obsidian vault clone skipped"
        fi

        # Clone personal Neovim config (if configured)
        local nvim_repo="${NVIM_REPO:-}"
        if [[ -n "$nvim_repo" ]] && [[ ! -d "$HOME/neovim" ]]; then
            print_step "Cloning personal Neovim configuration..."
            git clone "$nvim_repo" "$HOME/neovim" 2>/dev/null && \
                print_success "Personal Neovim config cloned to ~/neovim" || \
                log_verbose "Neovim config clone skipped"

            # Create symlink from dotfiles to repository
            if [[ -d "$HOME/neovim" ]]; then
                if [[ ! -L "$DOTFILES_ROOT/.config/nvim" ]]; then
                    ln -sf "$HOME/neovim" "$DOTFILES_ROOT/.config/nvim"
                    log_verbose "Symlinked ~/dotfiles/.config/nvim → ~/neovim"
                fi
            fi
        fi
    else
        log_verbose "No SSH keys found, skipping personal repository cloning"
    fi

    mark_step_complete "advanced_features"
}

phase_11_optional_features() {
    [[ $(is_step_complete "optional_features") == "true" ]] && return 0

    # Only run if explicitly enabled via environment variables
    if [[ "$DRY_RUN" == "true" ]]; then
        print_header "Phase 11: Optional Features"
        print_warning "DRY RUN: Skipping optional Nix/Pulse installations"
        mark_step_complete "optional_features"
        return 0
    fi
    if [[ "${ENABLE_NIX:-false}" == "true" ]]; then
        print_header "Phase 11: Optional Features - Nix Package Manager"

        if ! command_exists nix; then
            print_step "Installing Nix package manager..."
            sh <(curl -L https://nixos.org/nix/install) --daemon >/dev/null 2>&1 && \
                print_success "Nix package manager installed" || \
                print_warning "Nix installation failed"

            # Install Home Manager
            if command_exists nix; then
                print_step "Installing Home Manager..."
                nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager >/dev/null 2>&1
                nix-channel --update >/dev/null 2>&1
                print_success "Home Manager configured"
            fi
        fi

        # Setup Nix LSP hybrid mode
        if command_exists nix; then
            print_step "Configuring Nix LSP hybrid setup..."

            # Install global LSPs
            if [[ -f "$DOTFILES_ROOT/scripts/install-lsps-global.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/install-lsps-global.sh" >/dev/null 2>&1 && \
                    log_verbose "Global LSPs installed"
            fi

            # Activate hybrid mode
            if [[ -f "$DOTFILES_ROOT/scripts/activate-nix-lsps.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/activate-nix-lsps.sh" hybrid >/dev/null 2>&1 && \
                    log_verbose "Nix LSP hybrid mode activated"
            fi

            # Check LSP status
            if [[ -f "$DOTFILES_ROOT/scripts/check-lsp-status.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/check-lsp-status.sh" >/dev/null 2>&1 && \
                    print_success "Nix LSP hybrid setup complete"
            fi
        fi
    fi

    if [[ "${ENABLE_PULSE:-false}" == "true" ]]; then
        print_header "Phase 11: Optional Features - Pulse Coding Tracker"

        if ! command_exists pulse; then
            print_step "Building Pulse from source..."
            # Clone correct repo and build Pulse
            local pulse_dir="/tmp/pulse-build"
            git clone https://github.com/viccon/pulse.git "$pulse_dir" 2>/dev/null

            if [[ -d "$pulse_dir" ]]; then
                (cd "$pulse_dir" && make install) >/dev/null 2>&1 && \
                    print_success "Pulse coding tracker installed" || \
                    print_warning "Pulse installation failed"
                rm -rf "$pulse_dir"
            fi
        fi

        # Create Pulse configuration
        if command_exists pulse; then
            print_step "Configuring Pulse..."
            mkdir -p "$HOME/.pulse"

            # Create config.yaml
            cat > "$HOME/.pulse/config.yaml" <<'EOF'
# Pulse Coding Tracker Configuration
redis:
  host: localhost
  port: 6379
  db: 0

tracking:
  auto_start: true
  idle_timeout: 300
  save_interval: 60

projects:
  default_root: ~/code
EOF
            chmod 600 "$HOME/.pulse/config.yaml"

            # Setup daemon (OS-specific)
            if [[ "$(uname -s)" == "Darwin" ]]; then
                print_step "Setting up Pulse daemon (launchd)..."
                local pulse_plist="$HOME/Library/LaunchAgents/com.pulse.tracker.plist"
                mkdir -p "$HOME/Library/LaunchAgents"

                cat > "$pulse_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pulse.tracker</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which pulse)</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$HOME/.pulse/error.log</string>
    <key>StandardOutPath</key>
    <string>$HOME/.pulse/output.log</string>
</dict>
</plist>
EOF

                # Load daemon
                launchctl load "$pulse_plist" 2>/dev/null || true
                print_success "Pulse daemon configured and started"
            else
                # Linux systemd user service
                print_step "Setting up Pulse daemon (systemd)..."
                mkdir -p "$HOME/.config/systemd/user"
                local pulse_service="$HOME/.config/systemd/user/pulse-tracker.service"

                cat > "$pulse_service" <<EOF
[Unit]
Description=Pulse Coding Tracker
After=network.target

[Service]
Type=simple
ExecStart=$(which pulse) daemon
Restart=on-failure
RestartSec=5
StandardOutput=append:$HOME/.pulse/output.log
StandardError=append:$HOME/.pulse/error.log

[Install]
WantedBy=default.target
EOF

                # Reload and enable service
                systemctl --user daemon-reload 2>/dev/null || true
                systemctl --user enable pulse-tracker.service 2>/dev/null || true
                systemctl --user start pulse-tracker.service 2>/dev/null || true
                print_success "Pulse daemon configured and started"
            fi

            print_success "Pulse tracker configured"
        fi
    fi

    mark_step_complete "optional_features"
}

# ============================================================================
# Main
# ============================================================================

main() {
    parse_args "$@"
    load_modules
    preflight_checks
    show_summary

    # Run installation phases
    phase_1_core_packages
    phase_2_cli_tools
    phase_3_development
    phase_4_cloud_tools
    phase_5_editors
    phase_6_multiplexer
    phase_7_shells
    phase_8_dotfiles
    phase_9_fonts_and_apps
    phase_10_advanced_features
    phase_11_optional_features

    # Success
    print_header "Setup Complete!"

    echo "Installation Summary:"
    echo "  OS: $DETECTED_OS"
    echo "  Profile: $PROFILE"
    echo "  Mode: $DETECTED_MODE"
    echo ""
    echo "Next Steps:"
    echo "  1. Restart your shell or run: source ~/.bashrc"
    echo "  2. If using tmux: Start tmux and press Ctrl-s + I to install plugins"
    echo "  3. If using Neovim: Run 'nvim' to complete plugin installation"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
    print_success "Enjoy your configured environment! 🚀"
}

# Run main
main "$@"
