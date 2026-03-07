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
    cat <<EOF
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
    --clean                    Clear completion state to re-run all phases

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

    # Enable optional features (Nix, Pulse, Pi-Hole, Self-Hosted LLM, SonarQube)
    ENABLE_NIX=true ENABLE_PULSE=true ENABLE_PIHOLE=true ENABLE_SELFHOST_LLM=true ENABLE_SONARQUBE=true $0 --profile comprehensive

    # Clone personal repositories (set environment variables)
    OBSIDIAN_REPO=git@github.com:user/obsidian.git \\
    NVIM_REPO=git@github.com:user/nvim.git \\
    $0 --profile standard

ENVIRONMENT VARIABLES:
    ENABLE_NIX=true         Enable Nix package manager installation (Phase 11)
    ENABLE_PULSE=true       Enable Pulse coding tracker installation (Phase 11)
    ENABLE_PIHOLE=true      Enable Pi-hole DNS ad blocker via Colima + Docker (Phase 11)
    ENABLE_SELFHOST_LLM=true  Enable self-hosted LLM stack (Ollama + Open WebUI) (Phase 11)
    ENABLE_SONARQUBE=true   Enable SonarQube code quality server via Colima + Docker (Phase 11)
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
            [[ -z "${2:-}" ]] && {
                echo "Error: --profile requires a value"
                exit 1
            }
            PROFILE="$2"
            shift 2
            ;;
        --os)
            [[ -z "${2:-}" ]] && {
                echo "Error: --os requires a value"
                exit 1
            }
            OS="$2"
            shift 2
            ;;
        --mode)
            [[ -z "${2:-}" ]] && {
                echo "Error: --mode requires a value"
                exit 1
            }
            MODE="$2"
            shift 2
            ;;
        --offline-package)
            [[ -z "${2:-}" ]] && {
                echo "Error: --offline-package requires a value"
                exit 1
            }
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
        --clean)
            CLEAN_STATE=true
            shift
            ;;
        -h | --help)
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

    # Validate --os value
    if [[ "$OS" != "auto" ]]; then
        case "$OS" in
        macos | linux | wsl) ;;
        *)
            echo "Error: Invalid --os value '$OS'. Must be: auto, macos, linux, wsl"
            exit 1
            ;;
        esac
    fi

    # Validate --mode value
    if [[ "$MODE" != "auto" ]]; then
        case "$MODE" in
        online | offline) ;;
        *)
            echo "Error: Invalid --mode value '$MODE'. Must be: auto, online, offline"
            exit 1
            ;;
        esac
    fi

    # Export for child modules
    export PROFILE DRY_RUN NO_CONFIRM VERBOSE SKIP_PACKAGES SKIP_DOTFILES SKIP_SHELLS SKIP_FONTS_APPS
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

    # Clear state if --clean was passed
    if [[ "${CLEAN_STATE:-false}" == "true" ]]; then
        print_step "Clearing completion state (--clean)..."
        clear_state
        print_success "State cleared — all phases will re-run"
    fi

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

    # Auto-proceed — no interactive confirmation needed

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

    # Enable Homebrew background auto-updates (daily update + upgrade + cleanup)
    if command_exists brew && brew tap | grep -q "domt4/autoupdate" 2>/dev/null; then
        if [[ "$DRY_RUN" != "true" ]]; then
            print_step "Enabling Homebrew background auto-updates..."
            brew autoupdate start --upgrade --cleanup --immediate 2>/dev/null &&
                print_success "Homebrew auto-update enabled (24h interval)" ||
                log_verbose "Homebrew auto-update configuration skipped"
        else
            print_warning "DRY RUN: Would enable Homebrew background auto-updates"
        fi
    fi

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

    # Configure bat with Catppuccin Mocha theme
    if command_exists bat; then
        print_step "Configuring bat with Catppuccin Mocha theme..."
        mkdir -p "$(bat --config-dir)/themes"
        if curl -sL "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme" \
            -o "$(bat --config-dir)/themes/Catppuccin Mocha.tmTheme"; then
            bat cache --build >/dev/null 2>&1
            echo '--theme="Catppuccin Mocha"' >"$(bat --config-dir)/config"
            print_success "Bat configured with Catppuccin Mocha theme"
        else
            print_warning "Failed to download Catppuccin Mocha theme for bat"
        fi

        # Rebuild bat cache for custom themes (handles version upgrades)
        if [[ -d "$DOTFILES_ROOT/.config/bat/themes" ]] || [[ -d "$(bat --config-dir)/themes" ]]; then
            bat cache --build >/dev/null 2>&1 &&
                print_success "bat cache rebuilt for custom themes" || true
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
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash </dev/null
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            nvm install 22
        fi

        # Install Node.js global packages
        if command_exists npm; then
            print_step "Installing Node.js global packages..."
            # Install prettierd and prettier-plugin-toml
            if command_exists bun; then
                bun install -g @fsouza/prettierd prettier-plugin-toml >/dev/null 2>&1 ||
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
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y </dev/null
            source "$HOME/.cargo/env"
        fi
    fi

    # Install Python MCP servers via pipx (parallel — each creates an isolated venv)
    if command_exists pipx; then
        print_step "Installing Python-based MCP servers (parallel)..."
        pipx install mcp-server-git >/dev/null 2>&1 &
        pipx install mcp-server-fetch >/dev/null 2>&1 &
        pipx install mcp-server-sqlite >/dev/null 2>&1 &
        pipx install diagrams >/dev/null 2>&1 &
        pipx install hookify >/dev/null 2>&1 &
        pipx install websockets >/dev/null 2>&1 &
        wait
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

    # Claude Code CLI - native installer (auto-updates, no Node.js dependency)
    # Reference: https://code.claude.com/docs/en/setup
    print_step "Checking Claude Code CLI..."

    # Migrate from Homebrew to native installer (one-time cleanup)
    if brew list --cask claude-code >/dev/null 2>&1; then
        print_step "Migrating Claude Code from Homebrew to native installer..."
        brew uninstall --cask claude-code >/dev/null 2>&1 || true
        print_success "Homebrew Claude Code removed (migrating to native)"
    fi

    # Clean up legacy installations (only if remnants exist — skip slow npm/bun scans otherwise)
    if [[ -d "$HOME/.claude/local" ]]; then
        rm -rf "$HOME/.claude/local" 2>/dev/null || true
    fi
    if [[ -d "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code" ]]; then
        npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true
        rm -rf /opt/homebrew/lib/node_modules/@anthropic-ai/claude-code 2>/dev/null || true
    fi
    if command_exists bun && bun pm ls -g 2>/dev/null | grep -q "@anthropic-ai/claude-code"; then
        bun remove -g @anthropic-ai/claude-code >/dev/null 2>&1 || true
    fi
    rm -rf "$HOME/.npm/_npx/@anthropic-ai/claude-code" 2>/dev/null || true
    rm -f "$DOTFILES_ROOT/scripts/bin/claude" 2>/dev/null || true

    # Always install/upgrade via native installer on latest channel
    # The installer is idempotent — safe to run every time
    print_step "Installing/updating Claude Code (latest channel)..."
    # Close stdin (</dev/null) so the piped bash can't consume the parent script's input stream
    if curl -fsSL https://claude.ai/install.sh | bash -s -- latest </dev/null 2>&1; then
        print_success "Claude Code installed (latest channel): $(claude --version 2>/dev/null || echo 'version check failed')"
    else
        print_warning "Failed to install Claude Code - install manually: curl -fsSL https://claude.ai/install.sh | sh -s -- latest"
    fi

    # Verify installation health
    if command_exists claude; then
        claude doctor >/dev/null 2>&1 &&
            print_success "Claude Code doctor check passed" ||
            log_verbose "Claude Code doctor reported warnings (non-fatal)"
    fi

    # Install independent CLI tools
    print_step "Installing CLI tools..."

    _install_recall() {
        if ! command_exists recall; then
            brew install zippoxer/tap/recall >/dev/null 2>&1 &&
                print_success "recall installed" ||
                print_warning "Failed to install recall"
        else
            print_success "recall already installed"
        fi
    }

    _install_dolt() {
        if ! command_exists dolt; then
            brew install dolt >/dev/null 2>&1 &&
                print_success "dolt installed" ||
                print_warning "Failed to install dolt"
        else
            print_success "dolt already installed"
        fi
    }

    _install_beads() {
        _install_dolt # beads requires dolt as database backend
        if ! command_exists bd; then
            brew install beads >/dev/null 2>&1 &&
                print_success "beads installed" ||
                print_warning "Failed to install beads"
        else
            print_success "beads CLI already installed"
        fi
    }

    _install_entire() {
        if ! command_exists entire; then
            brew tap entireio/tap >/dev/null 2>&1 || true
            brew install entireio/tap/entire >/dev/null 2>&1 &&
                print_success "entire installed" ||
                print_warning "Failed to install entire"
        else
            print_success "entire CLI already installed"
        fi
    }

    _install_ccr() {
        if ! command_exists ccr; then
            if command_exists bun; then
                bun install -g @musistudio/claude-code-router >/dev/null 2>&1 &&
                    print_success "Claude Code Router installed" ||
                    print_warning "Failed to install Claude Code Router"
            elif command_exists npm; then
                npm install -g @musistudio/claude-code-router >/dev/null 2>&1 &&
                    print_success "Claude Code Router installed" ||
                    print_warning "Failed to install Claude Code Router"
            fi
        else
            print_success "Claude Code Router already installed"
        fi
    }

    _install_codex() {
        # Always run to install or update to latest version
        if command_exists bun; then
            bun add -g @openai/codex >/dev/null 2>&1 ||
                log_verbose "OpenAI Codex CLI installation skipped (optional)"
        elif command_exists npm; then
            if npm install -g @openai/codex >/dev/null 2>&1; then
                true
            else
                npm install --prefix "$HOME/.local" @openai/codex >/dev/null 2>&1 ||
                    log_verbose "OpenAI Codex CLI installation skipped (optional)"
            fi
        fi
    }

    _install_openclaw() {
        if ! command_exists openclaw; then
            brew install openclaw-cli >/dev/null 2>&1 ||
                log_verbose "OpenClaw CLI installation skipped (optional)"
        fi
    }

    _install_sonar() {
        if ! command_exists sonar; then
            print_step "Installing SonarQube CLI..."
            if curl -o- https://raw.githubusercontent.com/SonarSource/sonarqube-cli/refs/heads/master/user-scripts/install.sh | bash </dev/null 2>&1; then
                # Ensure PATH includes sonar for current session
                export PATH="$HOME/.local/share/sonarqube-cli/bin:$PATH"
                print_success "SonarQube CLI installed: $(sonar --version 2>/dev/null || echo 'installed')"
            else
                print_warning "Failed to install SonarQube CLI"
            fi
        else
            print_success "SonarQube CLI already installed"
        fi
    }

    # Run tool installs sequentially (brew doesn't support parallel operations)
    _install_recall
    _install_beads
    _install_entire
    _install_ccr
    _install_codex
    _install_openclaw
    _install_sonar

    # Codex post-install: generate Fish completions and set up MCP servers
    if command_exists codex; then
        # Fish completions (codex generates its own)
        local fish_comp_dir="$HOME/.config/fish/completions"
        mkdir -p "$fish_comp_dir"
        codex completion fish >"$fish_comp_dir/codex.fish" 2>/dev/null || true

        # MCP servers (mirror key Claude Code MCP servers)
        codex mcp add context7 -- bunx @upstash/context7-mcp >/dev/null 2>&1 || true
        codex mcp add playwright -- bunx @playwright/mcp@latest >/dev/null 2>&1 || true
        log_verbose "Codex CLI: completions and MCP servers configured"
    fi

    # Post-install: beads hooks (depends on beads being installed)
    if command_exists bd; then
        print_step "Configuring beads Claude Code hooks..."
        bd setup claude >/dev/null 2>&1 &&
            print_success "Beads hooks installed" ||
            log_verbose "Beads hook setup skipped"
    fi

    # Post-install: SonarQube Claude Code integration (secrets hooks + MCP server)
    if command_exists sonar && command_exists claude; then
        if sonar auth status 2>&1 | grep -q "No saved connection"; then
            log_verbose "SonarQube: no auth configured. Run 'sonar auth login' then 'sonar integrate claude -g' to enable Claude Code integration"
        else
            print_step "Configuring SonarQube Claude Code integration..."
            sonar install secrets >/dev/null 2>&1 &&
                print_success "SonarQube secrets scanner installed" ||
                log_verbose "SonarQube secrets scanner installation skipped"
            sonar integrate claude -g --non-interactive >/dev/null 2>&1 &&
                print_success "SonarQube Claude Code integration configured (global)" ||
                log_verbose "SonarQube Claude Code integration skipped (run 'sonar integrate claude -g' manually)"
        fi
    fi

    # Setup Claude Code Router configuration
    if [[ -f "$DOTFILES_ROOT/.config/claude-code-router/config.json" ]] && [[ ! -f "$HOME/.claude-code-router/config.json" ]]; then
        print_step "Setting up Claude Code Router configuration..."
        mkdir -p "$HOME/.claude-code-router"
        ln -sf "$DOTFILES_ROOT/.config/claude-code-router/config.json" "$HOME/.claude-code-router/config.json"
        print_success "Claude Code Router configuration linked from dotfiles"
    fi

    # Configure OpenClaw with security-hardened defaults
    if command_exists openclaw; then
        if [[ ! -f "$HOME/.openclaw/openclaw.json" ]]; then
            print_step "Configuring OpenClaw with secure defaults..."
            mkdir -p "$HOME/.openclaw"
            chmod 700 "$HOME/.openclaw"
            cp "$DOTFILES_ROOT/scripts/openclaw/openclaw-base.json" "$HOME/.openclaw/openclaw.json"
            chmod 600 "$HOME/.openclaw/openclaw.json"

            # Generate gateway token
            if [[ ! -f "$HOME/.openclaw/.env" ]]; then
                local oc_token
                oc_token=$(openssl rand -hex 32)
                cat >"$HOME/.openclaw/.env" <<OCEOF
# OpenClaw Gateway Authentication
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
OPENCLAW_GATEWAY_TOKEN=${oc_token}
OCEOF
                chmod 600 "$HOME/.openclaw/.env"
            fi
            print_success "OpenClaw configured with secure defaults"
        else
            print_success "OpenClaw configuration already exists"
        fi

        # Generate exec-approvals.json with secure defaults
        if [[ ! -f "$HOME/.openclaw/exec-approvals.json" ]]; then
            print_step "Creating exec-approvals.json with secure defaults..."
            cat >"$HOME/.openclaw/exec-approvals.json" <<'EAEOF'
{
  "defaults": {
    "require": true,
    "skillAutoAllow": false,
    "allowlist": []
  },
  "agents": {}
}
EAEOF
            chmod 600 "$HOME/.openclaw/exec-approvals.json"
            print_success "Exec approvals configured (require=true, no auto-allow)"
        fi

        # Install launchd service on macOS
        if [[ "$DETECTED_OS" == "macos" ]]; then
            openclaw gateway install >/dev/null 2>&1 || log_verbose "OpenClaw launchd service setup skipped"
        fi
    fi

    # Install iximiuz labctl CLI
    if ! command_exists labctl; then
        print_step "Installing iximiuz labctl CLI..."
        if curl -sf https://labs.iximiuz.com/cli/install.sh | sh </dev/null >/dev/null 2>&1; then
            print_success "iximiuz labctl CLI installed"
        else
            log_verbose "iximiuz labctl installation skipped (optional)"
        fi
    else
        print_success "iximiuz labctl CLI already installed at: $(which labctl)"
    fi

    # Configure Claude Code MCP servers
    if command_exists claude; then
        print_step "Configuring Claude Code MCP servers..."

        # Core MCP servers (sequential — all write to shared settings.json)
        claude mcp add --scope user context7 bunx @upstash/context7-mcp >/dev/null 2>&1 || true
        claude mcp add --scope user steampipe npx @turbot/steampipe-mcp postgresql://steampipe@localhost:9193/steampipe >/dev/null 2>&1 || true
        claude mcp add --scope user playwright bunx @playwright/mcp@latest >/dev/null 2>&1 || true
        claude mcp add --scope user --transport sse deepwiki https://mcp.deepwiki.com/sse >/dev/null 2>&1 || true

        # ClaudeCodeBrowser - Firefox browser automation for Claude Code
        # See docs/claudecodebrowser-security-assessment.md for security details
        CCB_DIR="$HOME/.claudecodebrowser"
        if [ ! -d "$CCB_DIR" ]; then
            print_step "Installing ClaudeCodeBrowser..."
            git clone https://github.com/nanogenomic/ClaudeCodeBrowser.git "$CCB_DIR" </dev/null >/dev/null 2>&1 || print_warning "Failed to clone ClaudeCodeBrowser"
        else
            print_step "Updating ClaudeCodeBrowser..."
            (cd "$CCB_DIR" && git pull </dev/null >/dev/null 2>&1) || print_warning "Failed to update ClaudeCodeBrowser"
        fi

        if [ -d "$CCB_DIR" ]; then
            # CORS hardening - replace wildcard origin with dynamic moz-extension:// allowlist
            # Rejects file://, http://, sandboxed iframe, and arbitrary web page origins
            # Only patch if not already patched (idempotent)
            if [ -f "$CCB_DIR/mcp-server/server.py" ] && ! grep -q "_get_cors_origin" "$CCB_DIR/mcp-server/server.py"; then
                python3 - "$CCB_DIR/mcp-server/server.py" <<'CORSPATCH'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()
# Add _get_cors_origin helper method after class definition line
helper = '''
    def _get_cors_origin(self):
        """Return CORS origin only for moz-extension:// requests."""
        origin = self.headers.get('Origin', '')
        if origin.startswith('moz-extension://'):
            return origin
        return ''
'''
# Insert helper after log_message method
content = re.sub(
    r"(    def log_message\(self, format, \*args\):\n        logger\.info\(f\"HTTP: \{format % args\}\"\)\n)",
    r"\1" + helper,
    content
)
# Replace static CORS headers with dynamic calls
content = content.replace(
    "self.send_header('Access-Control-Allow-Origin', '*')",
    "self.send_header('Access-Control-Allow-Origin', self._get_cors_origin())"
)
content = content.replace(
    "self.send_header('Access-Control-Allow-Origin', 'null')",
    "self.send_header('Access-Control-Allow-Origin', self._get_cors_origin())"
)
with open(path, 'w') as f:
    f.write(content)
print("CORS patched: moz-extension:// allowlist")
CORSPATCH
            fi

            # Make scripts executable
            chmod +x "$CCB_DIR"/native-host/*.py "$CCB_DIR"/mcp-server/*.py 2>/dev/null || true

            # Register native messaging host (macOS)
            NMH_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
            mkdir -p "$NMH_DIR"
            cat >"$NMH_DIR/claudecodebrowser.json" <<NMHEOF
{
  "name": "claudecodebrowser",
  "description": "ClaudeCodeBrowser Native Messaging Host",
  "path": "$CCB_DIR/native-host/claudecodebrowser_host.py",
  "type": "stdio",
  "allowed_extensions": ["claudecodebrowser@ligandal.com"]
}
NMHEOF

            # Register MCP server with Claude Code CLI
            claude mcp add --scope user claudecodebrowser \
                --transport stdio \
                -- python3 "$CCB_DIR/mcp-server/stdio_wrapper.py" >/dev/null 2>&1 || true

            print_success "ClaudeCodeBrowser installed with CORS hardening"
            echo "  Install Firefox extension from:"
            echo "  https://addons.mozilla.org/en-US/firefox/addon/claudecodebrowser/"
        fi

        print_success "Claude Code MCP configuration complete"
        log_verbose "Verify with: claude mcp list"

        # Configure Claude Code global settings
        claude config set --global preferredNotifChannel terminal_bell >/dev/null 2>&1 &&
            print_success "Claude Code notification channel set to terminal_bell" || true

        # Apply all ~/.claude.json settings in a single jq pass (avoids 7 separate read-modify-write cycles)
        if [[ -f "$HOME/.claude.json" ]] && command_exists jq; then
            jq '
                # Auto-updates on latest channel
                .autoUpdatesChannel = "latest" | .autoUpdates = true |
                # Remove legacy auto-compact override if present
                if .autoCompactEnabled == false then del(.autoCompactEnabled) else . end |
                # Agent teams teammate mode
                .teammateMode = "auto" |
                # Remote control for all sessions
                .enableRemoteControl = true |
                # Sandbox settings (filesystem + network isolation)
                .sandbox = {
                    "enabled": true,
                    "autoAllowBashIfSandboxed": true,
                    "excludedCommands": ["docker", "colima"],
                    "filesystem": {
                        "allowWrite": ["~/.kube", "//tmp", "~/.cache", "~/.local"],
                        "denyRead": ["~/.aws/credentials", "~/.ssh/id_*", "~/.gnupg/private-keys-v1.d"]
                    }
                } |
                # Suppress AI attribution in commits/PRs (per CLAUDE.md rules)
                .attribution = {"commit": "", "pr": ""}
            ' "$HOME/.claude.json" >"$HOME/.claude.json.tmp" &&
                mv "$HOME/.claude.json.tmp" "$HOME/.claude.json" &&
                print_success "Claude Code settings configured (updates, sandbox, teams, remote control, attribution)" || true
        fi

        # Enable Agent Teams (experimental) with tmux split-pane mode in settings.json
        # Reference: https://code.claude.com/docs/en/agent-teams
        local global_settings="$HOME/.claude/settings.json"
        if command_exists jq && [[ -f "$global_settings" ]]; then
            jq '.env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1" | .teammateMode = "tmux"' \
                "$global_settings" >"$global_settings.tmp" &&
                mv "$global_settings.tmp" "$global_settings" &&
                print_success "Claude Code Agent Teams enabled (tmux split-pane mode)" || true
        else
            log_verbose "Skipping Agent Teams config: jq or settings.json not found"
        fi

        # Create Claude Code provider profile directory and install template script
        # Provider profiles enable switching between Bedrock, Vertex AI, Foundry, or LLM gateways
        # Usage: cc-provider create bedrock && cc-provider use bedrock
        # See: docs/third-party-integrations.md
        mkdir -p "$HOME/.claude/providers"
        chmod 700 "$HOME/.claude/providers"
        if [[ -f "$DOTFILES_ROOT/scripts/cc-provider-templates.sh" ]]; then
            chmod +x "$DOTFILES_ROOT/scripts/cc-provider-templates.sh"
            print_success "Claude Code provider profiles directory ready (~/.claude/providers/)"
            log_verbose "Create profiles: cc-provider create bedrock|vertex|foundry|gateway"
        fi

        # Install Claude Code plugins from anthropics/claude-code marketplace
        print_step "Installing Claude Code plugins..."

        # Add marketplaces (idempotent — will skip if already added)
        claude plugin marketplace add anthropics/claude-code >/dev/null 2>&1 || true
        claude plugin marketplace add kenryu42/cc-marketplace >/dev/null 2>&1 || true
        claude plugin marketplace add antonbabenko/terraform-skill >/dev/null 2>&1 || true
        claude plugin marketplace add anthropics/skills >/dev/null 2>&1 || true
        claude plugin marketplace add obra/superpowers-marketplace >/dev/null 2>&1 || true
        claude plugin marketplace add steveyegge/beads >/dev/null 2>&1 || true

        # Install plugins (sequential — all write to shared settings.json)
        claude plugin install code-review@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install pr-review-toolkit@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install hookify@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install feature-dev@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install frontend-design@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install plugin-dev@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install ralph-wiggum@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install agent-sdk-dev@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install explanatory-output-style@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install learning-output-style@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install code-simplifier@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install security-guidance@claude-code-plugins >/dev/null 2>&1 || true
        claude plugin install terraform-skill@antonbabenko >/dev/null 2>&1 || true
        claude plugin install beads@steveyegge/beads >/dev/null 2>&1 || true
        claude plugin install example-skills@anthropic-agent-skills >/dev/null 2>&1 || true
        claude plugin install superpowers@superpowers-marketplace >/dev/null 2>&1 || true

        print_success "Claude Code plugins installed (16 plugins, 7 marketplaces)"
        log_verbose "Installed: code-review, pr-review-toolkit, hookify, feature-dev, frontend-design, plugin-dev, ralph-wiggum, agent-sdk-dev, explanatory-output-style, learning-output-style, code-simplifier, security-guidance, terraform-skill, beads, example-skills, superpowers"

        # Claude Code LSP Server Integration
        # LSP plugins give Claude Code native code intelligence (diagnostics, go-to-definition,
        # find-references, hover, symbols) without IDE dependency.
        # Requires: language server binaries in PATH (provided by Nix global devShell or Homebrew)
        print_step "Installing Claude Code LSP plugins..."

        # Add LSP plugin marketplace (boostvolt - broadest language coverage: 22 languages)
        claude plugin marketplace add boostvolt/claude-code-lsps >/dev/null 2>&1 || true

        # Install LSP plugins (sequential — all write to shared settings.json)
        claude plugin install pyright@claude-code-lsps >/dev/null 2>&1 || true       # Python
        claude plugin install typescript@claude-code-lsps >/dev/null 2>&1 || true    # TypeScript/JavaScript
        claude plugin install gopls@claude-code-lsps >/dev/null 2>&1 || true         # Go
        claude plugin install rust-analyzer@claude-code-lsps >/dev/null 2>&1 || true # Rust
        claude plugin install bash-lsp@claude-code-lsps >/dev/null 2>&1 || true      # Bash/Shell
        claude plugin install yaml-lsp@claude-code-lsps >/dev/null 2>&1 || true      # YAML
        claude plugin install terraform@claude-code-lsps >/dev/null 2>&1 || true     # Terraform
        claude plugin install lua-lsp@claude-code-lsps >/dev/null 2>&1 || true       # Lua (Neovim configs)
        claude plugin install nix-lsp@claude-code-lsps >/dev/null 2>&1 || true       # Nix

        print_success "Claude Code LSP plugins installed (9 language servers)"
        log_verbose "LSP plugins: pyright, typescript, gopls, rust-analyzer, bash-lsp, yaml-lsp, terraform, lua-lsp, nix-lsp"
        log_verbose "LSP binaries come from Nix global devShell (nix/global/) or Homebrew. See docs/claude-code-lsp.md"

        # Fix hookify plugin import paths (upstream bug: versioned cache dir hookify/0.1.0/
        # breaks Python's 'from hookify.core...' imports - registers synthetic package via sys.modules)
        if [[ -x "$DOTFILES_ROOT/scripts/fix-hookify-imports.sh" ]]; then
            "$DOTFILES_ROOT/scripts/fix-hookify-imports.sh" || true
        fi

        # frankbria Ralph - external autonomous loop tool (complements ralph-wiggum plugin)
        if [[ ! -d "$HOME/ralph-claude-code" ]]; then
            print_step "Installing frankbria Ralph (autonomous loop tool)..."
            git clone https://github.com/frankbria/ralph-claude-code.git "$HOME/ralph-claude-code" </dev/null >/dev/null 2>&1
            (cd "$HOME/ralph-claude-code" && ./install.sh </dev/null >/dev/null 2>&1)
            print_success "frankbria Ralph installed (ralph, ralph-monitor, ralph-setup)"
        else
            log_verbose "frankbria Ralph already installed"
        fi

        # Symlink Claude Code settings from dotfiles (preserves enabled plugins across devices)
        if [[ -f "$DOTFILES_ROOT/.claude/settings.json" ]] && [[ ! -L "$HOME/.claude/settings.json" ]]; then
            print_step "Linking Claude Code settings from dotfiles..."
            rm -f "$HOME/.claude/settings.json" 2>/dev/null || true
            ln -sf "$DOTFILES_ROOT/.claude/settings.json" "$HOME/.claude/settings.json"
            print_success "Claude Code settings linked (plugin preferences preserved)"
        fi
    fi

    # Install Kubernetes/Helm plugins
    if command_exists helm; then
        if ! helm plugin list 2>/dev/null | grep -q "^diff"; then
            print_step "Installing helm-diff plugin..."
            # Use v3.8.1 for compatibility with Helm 3.15.x
            helm plugin install https://github.com/databus23/helm-diff --version v3.8.1 >/dev/null 2>&1 &&
                print_success "helm-diff plugin installed" ||
                log_verbose "helm-diff plugin installation skipped"
        else
            log_verbose "helm-diff plugin already installed"
        fi
    fi

    # Install krew kubectl plugins
    if command_exists kubectl && kubectl krew version >/dev/null 2>&1; then
        print_step "Installing kubectl krew plugins..."
        # get-all plugin for listing all namespace resources
        if ! kubectl krew list 2>/dev/null | grep -q "get-all"; then
            kubectl krew install get-all >/dev/null 2>&1 &&
                print_success "kubectl get-all plugin installed" ||
                log_verbose "get-all plugin installation skipped"
        fi
        # lineage plugin for resource ownership tree
        if ! kubectl krew list 2>/dev/null | grep -q "lineage"; then
            kubectl krew install lineage >/dev/null 2>&1 &&
                print_success "kubectl lineage plugin installed" ||
                log_verbose "lineage plugin installation skipped"
        fi
    fi

    # Install kubectl-fzf-server for fast completions (macOS only)
    if [[ "$DETECTED_OS" == "macos" ]] && command_exists go; then
        if ! command_exists kubectl-fzf-server; then
            print_step "Installing kubectl-fzf-server..."
            go install github.com/bonnefoa/kubectl-fzf/v3/cmd/kubectl-fzf-server@main >/dev/null 2>&1 &&
                print_success "kubectl-fzf-server installed" ||
                log_verbose "kubectl-fzf-server installation skipped"
        fi
        # Load launchd plist for kubectl-fzf-server
        local kubectl_fzf_plist="$HOME/Library/LaunchAgents/com.kubectl-fzf-server.plist"
        if [[ -f "$kubectl_fzf_plist" ]] && ! launchctl list 2>/dev/null | grep -q "com.kubectl-fzf-server"; then
            launchctl bootstrap "gui/$(id -u)" "$kubectl_fzf_plist" 2>/dev/null &&
                print_success "kubectl-fzf-server service started" ||
                log_verbose "kubectl-fzf-server service start skipped"
        fi
    fi

    # Install consul-template (HashiCorp templating tool)
    if ! command_exists consul-template; then
        print_step "Installing consul-template..."
        local consul_template_version="0.41.3"
        local consul_os="linux"
        local consul_cpu="amd64"
        [[ "$DETECTED_OS" == "macos" ]] && consul_os="darwin"
        [[ "$DETECTED_ARCH" == "arm64" ]] && consul_cpu="arm64"
        local consul_template_arch="${consul_os}_${consul_cpu}"
        local consul_template_url="https://releases.hashicorp.com/consul-template/${consul_template_version}/consul-template_${consul_template_version}_${consul_template_arch}.zip"
        local consul_tmpdir
        consul_tmpdir="$(mktemp -d)"

        if curl -sL "$consul_template_url" -o "$consul_tmpdir/consul-template.zip"; then
            mkdir -p "$HOME/bin"
            unzip -q -o "$consul_tmpdir/consul-template.zip" -d "$consul_tmpdir"
            mv "$consul_tmpdir/consul-template" "$HOME/bin/"
            chmod +x "$HOME/bin/consul-template"
            print_success "consul-template installed to ~/bin/"
        else
            print_warning "Failed to download consul-template"
        fi
        rm -rf "$consul_tmpdir"
    else
        log_verbose "consul-template already installed"
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
        nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 &&
            print_success "Neovim plugins installed successfully" ||
            print_warning "Neovim plugin installation had issues (this is normal on first run)"

        # Install pynvim for Python support
        if command_exists python3; then
            print_step "Installing pynvim for Neovim Python support..."
            python3 -m pip install --user pynvim >/dev/null 2>&1 &&
                print_success "pynvim installed" ||
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

    # Install 1Password CLI (required by tmux-1password plugin)
    if ! command_exists op; then
        print_step "Installing 1Password CLI (required by tmux-1password plugin)..."
        brew install --cask 1password-cli >/dev/null 2>&1 &&
            print_success "1Password CLI installed" ||
            print_warning "Failed to install 1Password CLI - install manually with: brew install --cask 1password-cli"
    else
        print_success "1Password CLI already installed"
    fi

    # Install TPM
    if command_exists tmux && [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        print_step "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" </dev/null 2>&1
    fi

    # Manually install tmux plugins (ensures immediate availability)
    if command_exists tmux && [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        print_step "Installing tmux plugins..."

        local plugins_dir="$HOME/.tmux/plugins"
        # Plugin list synced with .tmux.conf - TPM clean_plugins removes unlisted ones
        local tmux_plugins=(
            "tmux-plugins/tmux-sensible"
            "tmux-plugins/tmux-yank"
            "tmux-plugins/tmux-prefix-highlight"
            "tmux-plugins/tmux-open"
            "tmux-plugins/tmux-copycat"
            "tmux-plugins/tmux-pain-control"
            "tmux-plugins/tmux-sidebar"
            "tmux-plugins/tmux-cpu"
            "christoomey/vim-tmux-navigator" # Vim/tmux seamless navigation
            "fcsonline/tmux-thumbs"          # Rust-based text hints
            "laktak/extrakto"                # Text extraction with FZF
            "rickstaa/tmux-notify"           # macOS notification on command completion
            "yardnsm/tmux-1password"         # 1Password integration
            "roosta/tmux-fuzzback"           # FZF scrollback search
            "sainnhe/tmux-fzf"               # FZF integration for tmux
            "azorng/tmux-smooth-scroll"      # Smooth scrolling
            "fabioluciano/tmux-powerkit"     # Status bar powerline theme
        )

        # Clone missing plugins in parallel
        local clone_pids=()
        for plugin in "${tmux_plugins[@]}"; do
            local plugin_name="${plugin##*/}"
            if [[ ! -d "$plugins_dir/$plugin_name" ]]; then
                log_verbose "Installing $plugin_name..."
                git clone "https://github.com/$plugin.git" "$plugins_dir/$plugin_name" 2>/dev/null &
                clone_pids+=($!)
            fi
        done
        # Wait for all parallel clones to finish
        for pid in "${clone_pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done

        print_success "Tmux plugins installed"

        # Build tmux-thumbs only if binary doesn't exist (skip expensive Rust compilation)
        if [[ -d "$plugins_dir/tmux-thumbs" ]] && command_exists cargo; then
            if [[ ! -f "$plugins_dir/tmux-thumbs/target/release/tmux-thumbs" ]]; then
                print_step "Building tmux-thumbs..."
                (cd "$plugins_dir/tmux-thumbs" &&
                    SDKROOT=$(xcrun --sdk macosx --show-sdk-path) \
                    LIBRARY_PATH="$(xcrun --sdk macosx --show-sdk-path)/usr/lib" \
                        cargo build --release) >/dev/null 2>&1 &&
                    print_success "tmux-thumbs built" ||
                    log_verbose "tmux-thumbs build failed (run manually: cd ~/.tmux/plugins/tmux-thumbs && SDKROOT=\$(xcrun --sdk macosx --show-sdk-path) cargo build --release)"
            else
                print_success "tmux-thumbs already built"
            fi
        fi

        # Update plugins and clean stale ones via TPM (skip update if we just cloned fresh)
        if [[ ${#clone_pids[@]} -eq 0 ]]; then
            print_step "Updating tmux plugins..."
            "$HOME/.tmux/plugins/tpm/bin/update_plugins" all >/dev/null 2>&1 &&
                log_verbose "Tmux plugins updated" ||
                log_verbose "Tmux plugin update completed with warnings"
        else
            log_verbose "Skipping plugin update (just cloned fresh)"
        fi
        "$HOME/.tmux/plugins/tpm/bin/clean_plugins" >/dev/null 2>&1 &&
            log_verbose "Stale tmux plugins cleaned" ||
            log_verbose "Tmux plugin cleanup completed with warnings"
        print_success "Tmux plugins synchronized"

        # Reload tmux config if tmux server is running
        if tmux list-sessions >/dev/null 2>&1; then
            print_step "Reloading tmux configuration..."
            tmux source-file "$HOME/.tmux.conf" 2>/dev/null &&
                print_success "Tmux configuration reloaded" ||
                log_verbose "Tmux config reload completed with warnings"
        fi
    fi

    # Apply Dracula theme customizations
    if [[ -f "$DOTFILES_ROOT/scripts/setup-tmux-dracula.sh" ]]; then
        print_step "Applying Dracula theme customizations..."
        bash "$DOTFILES_ROOT/scripts/setup-tmux-dracula.sh" >/dev/null 2>&1 &&
            print_success "Dracula theme customizations applied" ||
            log_verbose "Dracula theme setup completed with warnings"
    fi

    # Reset Claude activity watcher daemon
    if [[ -f "$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh" ]]; then
        print_step "Resetting Claude activity watcher..."
        "$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh" stop 2>/dev/null
        "$DOTFILES_ROOT/scripts/tmux/tmux-claude-watcher.sh" start </dev/null 2>/dev/null
        print_success "Claude watcher restarted"
    fi

    mark_step_complete "multiplexer"
}

phase_7_shells() {
    [[ "$SKIP_SHELLS" == "true" ]] && return 0
    [[ $(is_step_complete "shells") == "true" ]] && return 0

    print_header "Phase 7: Shell Configuration"

    install_packages_from_profile "$PROFILE" "shells"

    setup_shells_from_profile "$PROFILE"

    # Setup Atuin shell history (import existing history)
    if command_exists atuin && [[ ! -f "$HOME/.local/share/atuin/key" ]]; then
        print_step "Setting up Atuin shell history..."
        atuin import auto 2>/dev/null &&
            print_success "Atuin history imported" ||
            log_verbose "Atuin import skipped (may need manual setup)"
    fi

    # Configure Jujutsu (jj) version control
    if command_exists jj; then
        print_step "Configuring Jujutsu (jj)..."
        if [[ -f "$DOTFILES_ROOT/.config/jj/config.toml" ]]; then
            mkdir -p "$HOME/.config/jj"
            ln -sf "$DOTFILES_ROOT/.config/jj/config.toml" "$HOME/.config/jj/config.toml" 2>/dev/null &&
                print_success "Jujutsu configuration linked" ||
                log_verbose "Jujutsu config will be created by stow"
        else
            log_verbose "Jujutsu config will be created by stow"
        fi
    fi

    mark_step_complete "shells"
}

phase_8_dotfiles() {
    [[ "$SKIP_DOTFILES" == "true" ]] && return 0
    [[ $(is_step_complete "dotfiles") == "true" ]] && return 0

    print_header "Phase 8: Dotfiles"

    stow_dotfiles

    # Configure git template directory for auto-setup hooks (e.g., .gitignore_local)
    if command_exists git; then
        git config --global init.templateDir ~/.config/git/templates
        log_verbose "Git template directory configured"

        # Register union-doc merge driver for documentation files (CLAUDE.md, AGENTS.md)
        # Prevents merge conflicts when multiple worktrees append to the same doc files
        git config --global merge.union-doc.name "Union merge for documentation files"
        git config --global merge.union-doc.driver "$DOTFILES_ROOT/scripts/merge-driver-union.sh %A %O %B %L %P"
        log_verbose "Union-doc merge driver registered"

        # Register Brewfile merge driver - union merge + dedup of tap/brew/cask/mas
        git config --global merge.brewfile.name "Union merge for Brewfile"
        git config --global merge.brewfile.driver "$DOTFILES_ROOT/scripts/merge-driver-brewfile.sh %A %O %B %L %P"
        log_verbose "Brewfile merge driver registered"

        # Register JSON deep-merge driver for settings files
        git config --global merge.json-merge.name "Deep merge for JSON config files"
        git config --global merge.json-merge.driver "$DOTFILES_ROOT/scripts/merge-driver-json.sh %A %O %B %L %P"
        log_verbose "JSON merge driver registered"

        # Register lockfile merge driver - keeps ours for auto-generated lockfiles
        git config --global merge.lockfile.name "Keep ours for lockfiles"
        git config --global merge.lockfile.driver "$DOTFILES_ROOT/scripts/merge-driver-lockfile.sh %A %O %B %L %P"
        log_verbose "Lockfile merge driver registered"

        # Register JSON diff driver - sorts keys for cleaner diffs
        git config --global diff.json.textconv "$DOTFILES_ROOT/scripts/git-diff-json.sh"
        log_verbose "JSON diff driver registered"

        # Register JSON clean filter - normalizes key order on commit
        # Prevents phantom diffs from tools that re-serialize JSON (e.g., Claude Code)
        git config --global filter.json-normalize.clean "$DOTFILES_ROOT/scripts/git-clean-json.sh"
        log_verbose "JSON normalize filter registered"

        # Register plist diff driver - converts to XML for readable diffs
        git config --global diff.plist.textconv "plutil -convert xml1 -o -"
        log_verbose "Plist diff driver registered"
    fi

    # Setup local git excludes (.gitignore_local symlinks) for existing repos
    if [[ -x "$DOTFILES_ROOT/scripts/tools/setup-git-local-excludes.sh" ]]; then
        print_step "Setting up local git excludes..."
        local exclude_script="$DOTFILES_ROOT/scripts/tools/setup-git-local-excludes.sh"

        # Setup for ~/work if it exists
        if [[ -d "$HOME/work" ]]; then
            "$exclude_script" "$HOME/work" >/dev/null 2>&1 &&
                log_verbose "Local git excludes configured for ~/work"
        fi

        # Setup for individual repos: ~/neovim and ~/dotfiles
        for repo in "$HOME/neovim" "$DOTFILES_ROOT"; do
            if [[ -d "$repo/.git" ]]; then
                # Run the script with the parent directory, but it only processes git repos
                # So we create a temp approach: cd to repo and setup manually
                local git_exclude="$repo/.git/info/exclude"
                local gitignore_local="$repo/.gitignore_local"

                # Create info dir if needed
                [[ ! -d "$repo/.git/info" ]] && mkdir -p "$repo/.git/info"

                # Create exclude file if it doesn't exist
                if [[ ! -f "$git_exclude" ]]; then
                    cat >"$git_exclude" <<'EXCLUDE_EOF'
# Local git excludes - patterns that won't be committed
# This file is symlinked to .gitignore_local for easy editing

.gitignore_local
*.local
.env.local
.vscode/
.idea/
.claude/
.codex/
.DS_Store
*.swp
*.swo
*~
.pyrightconfig.json
EXCLUDE_EOF
                fi

                # Create symlink if it doesn't exist
                if [[ ! -L "$gitignore_local" ]]; then
                    (cd "$repo" && ln -sf .git/info/exclude .gitignore_local)
                    log_verbose "Local git excludes configured for $repo"
                fi
            fi
        done

        print_success "Local git excludes configured"
    fi

    # Setup kubectl abbreviations for Fish (universal variables, one-time setup)
    if command_exists fish && [[ -f "$HOME/.config/fish/setup/kubectl-abbr-setup.fish" ]]; then
        print_step "Setting up kubectl abbreviations for Fish..."
        fish -c 'source ~/.config/fish/setup/kubectl-abbr-setup.fish' 2>/dev/null &&
            print_success "kubectl abbreviations installed" ||
            log_verbose "kubectl abbreviations setup skipped"
    fi

    mark_step_complete "dotfiles"
}

phase_9_fonts_and_apps() {
    [[ "$SKIP_PACKAGES" == "true" ]] && return 0
    [[ $(is_step_complete "fonts_and_apps") == "true" ]] && return 0

    print_header "Phase 9: Fonts & Applications"

    [[ "$SKIP_FONTS_APPS" == "true" ]] && {
        print_warning "Skipping fonts/apps (flag)"
        mark_step_complete "fonts_and_apps"
        return 0
    }

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Skipping font and GUI application installation"
        mark_step_complete "fonts_and_apps"
        return 0
    fi

    # macOS-specific installations
    if [[ "$DETECTED_OS" == "macos" ]]; then
        # Install Nerd Fonts (batch — single brew invocation)
        print_step "Installing Nerd Fonts..."
        local fonts=(
            "font-iosevka-nerd-font"
            "font-jetbrains-mono-nerd-font"
            "font-fira-code-nerd-font"
            "font-hack-nerd-font"
        )
        local fonts_to_install=()
        for font in "${fonts[@]}"; do
            if pm_is_installed "$font"; then
                print_success "$font already installed"
            else
                fonts_to_install+=("$font")
            fi
        done
        if [[ ${#fonts_to_install[@]} -gt 0 ]]; then
            brew install --cask "${fonts_to_install[@]}" >/dev/null 2>&1 &&
                print_success "Installed ${#fonts_to_install[@]} fonts" ||
                print_warning "Some fonts failed to install"
        fi

        # Check for DankMono Nerd Font
        if fc-list 2>/dev/null | grep -qi "DankMono"; then
            print_success "DankMono Nerd Font is installed"
        else
            print_warning "DankMono Nerd Font not found - install manually from:"
            echo "  https://github.com/saifulapm/my-fonts"
            echo "  Then: cp /tmp/my-fonts/DankMono\\ Nerd\\ Font/*.otf ~/Library/Fonts/"
        fi

        # Install GUI Applications (batch — single brew invocation)
        print_step "Installing GUI Applications..."
        local gui_apps=(
            "raycast"
            "wezterm"
            "nikitabobko/tap/aerospace"
            "amazon-q"
            "ngrok"
            "altair-graphql-client"
        )
        local apps_to_install=()
        for app in "${gui_apps[@]}"; do
            local app_name="${app##*/}"
            if pm_is_installed "$app_name"; then
                print_success "$app_name already installed"
            else
                apps_to_install+=("$app")
            fi
        done
        if [[ ${#apps_to_install[@]} -gt 0 ]]; then
            brew install --cask "${apps_to_install[@]}" >/dev/null 2>&1 &&
                print_success "Installed ${#apps_to_install[@]} GUI applications" ||
                log_verbose "Some GUI applications failed to install"
        fi

        # Execute macOS defaults configuration
        if [[ -f "$DOTFILES_ROOT/scripts/setup/macos-defaults.sh" ]]; then
            print_step "Applying macOS system defaults..."
            bash "$DOTFILES_ROOT/scripts/setup/macos-defaults.sh" >/dev/null 2>&1 &&
                print_success "macOS defaults configured (Finder, Dock, developer settings)" ||
                log_verbose "macOS defaults completed with warnings"
        fi

        # Setup SSH Key Auto-loading LaunchAgent
        print_step "Setting up SSH key auto-loading..."
        local ssh_plist="$HOME/Library/LaunchAgents/com.user.ssh-add.plist"
        local ssh_plist_source="$DOTFILES_ROOT/Library/LaunchAgents/com.user.ssh-add.plist"
        mkdir -p "$HOME/Library/LaunchAgents"
        if [[ ! -f "$ssh_plist" ]] && [[ -f "$ssh_plist_source" ]]; then
            cp "$ssh_plist_source" "$ssh_plist"
            print_success "SSH LaunchAgent installed"
        fi
        if [[ -f "$ssh_plist" ]]; then
            if ! launchctl list 2>/dev/null | grep -q "com.user.ssh-add"; then
                launchctl bootstrap "gui/$(id -u)" "$ssh_plist" 2>/dev/null &&
                    print_success "SSH key auto-loading enabled" ||
                    log_verbose "SSH LaunchAgent load skipped"
            fi
        fi

        # Setup Ticket Queue LaunchAgent (auto-start daemon on login)
        print_step "Setting up ticket queue daemon..."
        local queue_plist="$HOME/Library/LaunchAgents/com.dotfiles.ticket-queue.plist"
        if [[ -f "$queue_plist" ]]; then
            if ! launchctl list 2>/dev/null | grep -q "com.dotfiles.ticket-queue"; then
                launchctl bootstrap "gui/$(id -u)" "$queue_plist" 2>/dev/null &&
                    print_success "Ticket queue daemon started" ||
                    log_verbose "Ticket queue daemon start skipped"
            else
                log_verbose "Ticket queue daemon already running"
            fi
        fi

        # Setup Mayor LaunchAgent (global coordinator daemon on login)
        print_step "Setting up mayor daemon..."
        local mayor_plist="$HOME/Library/LaunchAgents/com.dotfiles.gwt-mayor.plist"
        if [[ -f "$mayor_plist" ]]; then
            if ! launchctl list 2>/dev/null | grep -q "com.dotfiles.gwt-mayor"; then
                launchctl bootstrap "gui/$(id -u)" "$mayor_plist" 2>/dev/null &&
                    print_success "Mayor daemon started" ||
                    log_verbose "Mayor daemon start skipped"
            else
                log_verbose "Mayor daemon already running"
            fi
        fi

        # Setup Karabiner-Elements (keyboard remapping)
        print_step "Setting up Karabiner-Elements..."
        if [[ -d "$DOTFILES_ROOT/.config/karabiner" ]]; then
            mkdir -p "$HOME/.config/karabiner"
            if [[ ! -f "$HOME/.config/karabiner/karabiner.json" ]]; then
                ln -sf "$DOTFILES_ROOT/.config/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json" 2>/dev/null &&
                    print_success "Karabiner-Elements configuration linked" ||
                    log_verbose "Karabiner config link skipped"
            fi
        fi

        # Setup CopyQ clipboard manager
        if command_exists copyq || [[ -d "/Applications/CopyQ.app" ]]; then
            print_step "Setting up CopyQ..."
            if [[ -f "$DOTFILES_ROOT/scripts/setup/setup-copyq.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/setup/setup-copyq.sh" >/dev/null 2>&1 &&
                    print_success "CopyQ configured" ||
                    log_verbose "CopyQ setup completed with warnings"
            fi
        fi
        # Install ClaudeUsage menu bar app (subscription usage tracker)
        # https://github.com/linuxlewis/claude-usage
        if [[ -d "/Applications/ClaudeUsage.app" ]]; then
            print_success "ClaudeUsage already installed"
        else
            print_step "Installing ClaudeUsage menu bar app..."
            local claude_usage_url
            claude_usage_url=$(curl -sL "https://api.github.com/repos/linuxlewis/claude-usage/releases/latest" |
                grep -o '"browser_download_url":\s*"[^"]*\.zip"' |
                head -1 |
                sed 's/"browser_download_url":\s*"//;s/"$//')

            if [[ -n "$claude_usage_url" ]]; then
                local claude_usage_tmpdir
                claude_usage_tmpdir="$(mktemp -d)"
                if curl -sL "$claude_usage_url" -o "$claude_usage_tmpdir/ClaudeUsage.zip"; then
                    unzip -q -o "$claude_usage_tmpdir/ClaudeUsage.zip" -d "$claude_usage_tmpdir/extracted" 2>/dev/null
                    local app_src="$claude_usage_tmpdir/extracted/ClaudeUsage.app"
                    if [[ ! -d "$app_src" ]]; then
                        app_src=$(find "$claude_usage_tmpdir/extracted" -name "ClaudeUsage.app" -maxdepth 2 -type d 2>/dev/null | head -1)
                    fi
                    if [[ -n "$app_src" && -d "$app_src" ]]; then
                        xattr -cr "$app_src" 2>/dev/null
                        codesign --force --deep --sign - "$app_src" 2>/dev/null
                        mv "$app_src" /Applications/
                        print_success "ClaudeUsage installed to /Applications/"
                    else
                        print_warning "ClaudeUsage.app not found in archive"
                    fi
                else
                    print_warning "Failed to download ClaudeUsage"
                fi
                rm -rf "$claude_usage_tmpdir"
            else
                print_warning "Failed to fetch ClaudeUsage release URL"
            fi
        fi
    else
        # Linux/other OS
        echo "Font and GUI application installation is macOS-specific"
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
            kubelogin convert-kubeconfig >/dev/null 2>&1 &&
                print_success "Azure kubelogin initialized" ||
                log_verbose "kubelogin initialization skipped"
        fi
        print_success "Kubernetes configuration initialized"
    fi

    # Rust tools installation (skip if binaries already exist)
    if command_exists cargo; then
        local cargo_to_install=()
        command_exists stylua || cargo_to_install+=(stylua)
        command_exists s3grep || cargo_to_install+=(s3grep)

        if [[ ${#cargo_to_install[@]} -gt 0 ]]; then
            print_step "Installing Rust development tools: ${cargo_to_install[*]}..."
            cargo install "${cargo_to_install[@]}" >/dev/null 2>&1 &&
                print_success "Rust tools installed (${cargo_to_install[*]})" ||
                log_verbose "Rust tools installation completed with warnings"
        else
            print_success "Rust tools already installed (stylua, s3grep)"
        fi
    fi

    # Personal repositories (optional - check for SSH key)
    if [[ -f "$HOME/.ssh/id_rsa" ]] || [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        print_step "Cloning personal repositories..."

        # Clone Obsidian vault (if configured)
        local obsidian_repo="${OBSIDIAN_REPO:-}"
        if [[ -n "$obsidian_repo" ]] && [[ ! -d "$HOME/obsidian" ]]; then
            git clone "$obsidian_repo" "$HOME/obsidian" </dev/null 2>/dev/null &&
                print_success "Obsidian vault cloned" ||
                log_verbose "Obsidian vault clone skipped"
        fi

        # Clone personal Neovim config (if configured)
        local nvim_repo="${NVIM_REPO:-}"
        if [[ -n "$nvim_repo" ]] && [[ ! -d "$HOME/neovim" ]]; then
            print_step "Cloning personal Neovim configuration..."
            git clone "$nvim_repo" "$HOME/neovim" </dev/null 2>/dev/null &&
                print_success "Personal Neovim config cloned to ~/neovim" ||
                log_verbose "Neovim config clone skipped"

            # Create symlink in home directory (manual symlink, not managed by stow)
            if [[ -d "$HOME/neovim" ]]; then
                if [[ ! -L "$HOME/.config/nvim" ]]; then
                    ln -sf "$HOME/neovim" "$HOME/.config/nvim"
                    print_success "Created symlink: ~/.config/nvim → ~/neovim"
                fi

                # Trust mise configuration if mise is installed
                if command -v mise &>/dev/null && [[ -f "$HOME/neovim/mise.toml" ]]; then
                    mise trust "$HOME/neovim/mise.toml" &>/dev/null &&
                        print_success "Trusted mise configuration for Neovim" ||
                        log_verbose "mise trust skipped"
                fi

                # Configure persistent mise settings (only needed once, not every shell startup)
                if command -v mise &>/dev/null; then
                    mise settings add idiomatic_version_file_enable_tools ruby 2>/dev/null &&
                        print_success "Configured mise idiomatic version file for Ruby" ||
                        log_verbose "mise settings already configured"
                fi
            fi
        fi
    else
        log_verbose "No SSH keys found, skipping personal repository cloning"
    fi

    # Devcontainer Neovim Environment Setup
    # Sets up persistent directory structure for Neovim in devcontainers
    print_step "Setting up devcontainer Neovim environment..."
    local devcontainer_env="$HOME/.devcontainer/env"

    # Create directory structure
    mkdir -p "$devcontainer_env/.config" "$devcontainer_env/.cache" "$devcontainer_env/.local"

    # Symlink Neovim config if ~/neovim exists and not already linked
    if [[ -d "$HOME/neovim" ]] && [[ ! -L "$devcontainer_env/.config/nvim" ]]; then
        ln -sf "$HOME/neovim" "$devcontainer_env/.config/nvim"
        print_success "Linked: ~/.devcontainer/env/.config/nvim -> ~/neovim"
    elif [[ -L "$devcontainer_env/.config/nvim" ]]; then
        log_verbose "Devcontainer Neovim config already linked"
    else
        log_verbose "~/neovim not found - devcontainer will use empty config"
    fi

    print_success "Devcontainer environment ready at ~/.devcontainer/env"

    # Pre-export Claude Code credentials for devcontainer auto-login
    # Extracts OAuth tokens from macOS Keychain so devcontainers can authenticate automatically
    local export_script="$DOTFILES_ROOT/scripts/devcontainer/export-claude-credentials.sh"
    if [[ -f "$export_script" ]] && [[ "$(uname)" == "Darwin" ]]; then
        print_step "Exporting Claude Code credentials for devcontainer auto-login..."
        if bash "$export_script" 2>/dev/null; then
            print_success "Claude Code credentials exported to shared directory"
        else
            print_warning "No Claude Code credentials found - run 'claude login' first"
        fi
    fi

    # Install devcontainer.vim (universal Neovim for any devcontainer)
    if command_exists go && [[ ! -f "$HOME/go/bin/devcontainer.vim" ]]; then
        print_step "Installing devcontainer.vim..."
        go install github.com/mikoto2000/devcontainer.vim@latest >/dev/null 2>&1 &&
            print_success "devcontainer.vim installed" ||
            print_warning "devcontainer.vim installation failed (requires Go)"
    elif [[ -f "$HOME/go/bin/devcontainer.vim" ]]; then
        log_verbose "devcontainer.vim already installed"
    fi

    # Symlink claude-code-plugins devcontainer config from dotfiles
    # This ensures Neovim-enabled devcontainer config persists across plugin updates
    local claude_plugins_devcontainer="$HOME/.claude/plugins/marketplaces/claude-code-plugins/.devcontainer"
    local dotfiles_devcontainer="$DOTFILES_ROOT/devcontainer/claude-code-plugins"
    if [[ -d "$dotfiles_devcontainer" ]] && [[ ! -L "$claude_plugins_devcontainer" ]]; then
        print_step "Linking claude-code-plugins devcontainer config..."
        rm -rf "$claude_plugins_devcontainer" 2>/dev/null || true
        mkdir -p "$(dirname "$claude_plugins_devcontainer")"
        ln -sf "$dotfiles_devcontainer" "$claude_plugins_devcontainer"
        print_success "claude-code-plugins devcontainer linked from dotfiles"
    elif [[ -L "$claude_plugins_devcontainer" ]]; then
        log_verbose "claude-code-plugins devcontainer already linked"
    fi

    # Vault Semantic Search Setup (smart embeddings)
    # Runs independently of SSH keys - only requires ~/obsidian to exist
    if [[ -d "$HOME/obsidian" ]]; then
        local venv_dir="$DOTFILES_ROOT/.venv/vault-search"

        # Check if already set up (venv exists and has sentence-transformers)
        if [[ -d "$venv_dir" ]] && "$venv_dir/bin/python" -c "import sentence_transformers" 2>/dev/null; then
            log_verbose "Vault semantic search already configured"
        else
            print_step "Setting up Obsidian vault semantic search..."
            if "$DOTFILES_ROOT/scripts/smart-connections/setup-vault-search.sh" "$HOME/obsidian" >/dev/null 2>&1; then
                print_success "Vault semantic search configured"
            else
                print_warning "Vault semantic search setup failed (non-critical)"
            fi
        fi
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
            print_step "Installing Nix package manager (Determinate Systems installer)..."
            # Use Determinate Systems installer for better macOS support
            if curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm </dev/null; then
                print_success "Nix package manager installed"
                # Source Nix for current session
                [[ -f '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]] &&
                    source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
            else
                print_warning "Nix installation failed - install manually from https://nixos.org/download"
            fi
        fi

        # Configure Nix
        if command_exists nix; then
            print_step "Configuring Nix..."
            mkdir -p "$HOME/.config/nix"

            # Create nix.conf with flakes and experimental features
            if [[ ! -f "$HOME/.config/nix/nix.conf" ]]; then
                cat >"$HOME/.config/nix/nix.conf" <<'EOF'
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
                print_success "Nix configuration created"
            fi

            # Configure trusted users for Determinate Systems installer (macOS)
            if [[ "$DETECTED_OS" == "macos" ]] && [[ -f "/etc/nix/nix.custom.conf" ]]; then
                if ! sudo grep -q "^trusted-users.*@admin" /etc/nix/nix.custom.conf 2>/dev/null; then
                    print_step "Adding @admin to Nix trusted users..."
                    echo "trusted-users = root @admin" | sudo tee -a /etc/nix/nix.custom.conf >/dev/null
                    # Restart Nix daemon
                    if sudo launchctl list | grep -q "systems.determinate.nix-daemon"; then
                        sudo launchctl kickstart -k system/systems.determinate.nix-daemon
                    fi
                fi
            fi

            # Setup Home Manager
            print_step "Setting up Home Manager..."
            if [[ ! -f "$HOME/.config/home-manager/flake.nix" ]]; then
                # Symlink Home Manager configuration from dotfiles if it exists
                if [[ -d "$DOTFILES_ROOT/.config/home-manager" ]]; then
                    rm -rf "$HOME/.config/home-manager" 2>/dev/null || true
                    ln -sf "$DOTFILES_ROOT/.config/home-manager" "$HOME/.config/home-manager"
                    print_success "Home Manager configuration symlinked from dotfiles"
                else
                    print_warning "Home Manager configuration not found in dotfiles"
                fi
            fi

            # Activate Home Manager if config exists
            if [[ -f "$HOME/.config/home-manager/flake.nix" ]]; then
                print_step "Activating Home Manager configuration..."
                if (cd "$HOME/.config/home-manager" && nix run . -- switch --flake .#default --impure 2>/dev/null); then
                    print_success "Home Manager activated for user: $USER"
                else
                    print_warning "Home Manager activation failed - run 'hm-switch' manually after restarting shell"
                fi
            fi

            # Setup Nix LSP hybrid mode
            print_step "Configuring Nix LSP hybrid setup..."

            # Install global LSPs
            if [[ -f "$DOTFILES_ROOT/scripts/install-lsps-global.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/install-lsps-global.sh" >/dev/null 2>&1 &&
                    log_verbose "Global LSPs installed"
            fi

            # Activate hybrid mode
            if [[ -f "$DOTFILES_ROOT/scripts/activate-nix-lsps.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/activate-nix-lsps.sh" hybrid >/dev/null 2>&1 &&
                    log_verbose "Nix LSP hybrid mode activated"
            fi

            # Check LSP status
            if [[ -f "$DOTFILES_ROOT/scripts/check-lsp-status.sh" ]]; then
                bash "$DOTFILES_ROOT/scripts/check-lsp-status.sh" >/dev/null 2>&1 &&
                    print_success "Nix LSP hybrid setup complete"
            fi
        fi
    fi

    if [[ "${ENABLE_PULSE:-false}" == "true" ]]; then
        print_header "Phase 11: Optional Features - Pulse Coding Tracker"

        # Start Redis service (required for Pulse)
        print_step "Starting Redis service..."
        if command_exists brew; then
            brew services start redis 2>/dev/null || log_verbose "Redis service may already be running"
            print_success "Redis service started"
        elif command_exists systemctl; then
            sudo systemctl enable redis 2>/dev/null || true
            sudo systemctl start redis 2>/dev/null || true
            print_success "Redis service started (systemd)"
        else
            print_warning "Cannot start Redis service automatically"
        fi

        # Build and install Pulse binaries
        if ! command_exists pulse-server || ! command_exists pulse-client; then
            print_step "Building Pulse from source..."

            if ! command_exists go; then
                print_warning "Go not installed - cannot build Pulse. Install with: brew install go"
            else
                local pulse_dir="/tmp/pulse-build"
                rm -rf "$pulse_dir"
                mkdir -p "$HOME/bin"

                if git clone https://github.com/viccon/pulse.git "$pulse_dir" </dev/null 2>/dev/null; then
                    if (cd "$pulse_dir" &&
                        go build -o pulse-server ./cmd/server 2>/dev/null &&
                        go build -o pulse-client ./cmd/client 2>/dev/null); then
                        cp "$pulse_dir/pulse-server" "$HOME/bin/"
                        cp "$pulse_dir/pulse-client" "$HOME/bin/"
                        chmod +x "$HOME/bin/pulse-server" "$HOME/bin/pulse-client"
                        print_success "Pulse binaries installed to ~/bin/"
                    else
                        print_warning "Failed to build Pulse binaries"
                    fi
                    rm -rf "$pulse_dir"
                else
                    print_warning "Failed to clone Pulse repository"
                fi
            fi
        else
            log_verbose "Pulse binaries already installed"
        fi

        # Create Pulse configuration
        if command_exists pulse-server || [[ -f "$HOME/bin/pulse-server" ]]; then
            print_step "Configuring Pulse..."
            mkdir -p "$HOME/.pulse/logs" "$HOME/.pulse/data"

            # Create config.yaml if not exists
            if [[ ! -f "$HOME/.pulse/config.yaml" ]]; then
                cat >"$HOME/.pulse/config.yaml" <<'EOF'
server:
  name: "pulse-server"
  host: "127.0.0.1"
  port: 8080

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
                print_success "Pulse configuration created"
            else
                log_verbose "Pulse configuration already exists"
            fi

            # Setup daemon (OS-specific)
            local pulse_binary
            if [[ -f "$HOME/bin/pulse-server" ]]; then
                pulse_binary="$HOME/bin/pulse-server"
            else
                pulse_binary="$(which pulse-server 2>/dev/null || echo "")"
            fi

            if [[ -n "$pulse_binary" ]]; then
                if [[ "$(uname -s)" == "Darwin" ]]; then
                    print_step "Setting up Pulse daemon (launchd)..."
                    local pulse_plist="$HOME/Library/LaunchAgents/dev.shaheislam.pulse.plist"
                    mkdir -p "$HOME/Library/LaunchAgents"

                    if [[ ! -f "$pulse_plist" ]]; then
                        cat >"$pulse_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.shaheislam.pulse</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.pulse/logs/stderr.log</string>
    <key>StandardOutPath</key>
    <string>$HOME/.pulse/logs/stdout.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/bin</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
        <string>$pulse_binary</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
                        launchctl bootstrap "gui/$(id -u)" "$pulse_plist" 2>/dev/null || true
                        print_success "Pulse daemon configured and started"
                    else
                        log_verbose "Pulse daemon already configured"
                    fi
                else
                    # Linux systemd user service
                    print_step "Setting up Pulse daemon (systemd)..."
                    mkdir -p "$HOME/.config/systemd/user"
                    local pulse_service="$HOME/.config/systemd/user/pulse-tracker.service"

                    cat >"$pulse_service" <<EOF
[Unit]
Description=Pulse Coding Tracker
After=network.target

[Service]
Type=simple
ExecStart=$pulse_binary
Restart=on-failure
RestartSec=5
StandardOutput=append:$HOME/.pulse/logs/stdout.log
StandardError=append:$HOME/.pulse/logs/stderr.log

[Install]
WantedBy=default.target
EOF

                    systemctl --user daemon-reload 2>/dev/null || true
                    systemctl --user enable pulse-tracker.service 2>/dev/null || true
                    systemctl --user start pulse-tracker.service 2>/dev/null || true
                    print_success "Pulse daemon configured and started"
                fi
            fi

            print_success "Pulse tracker configured"
            echo "View logs: tail -f ~/.pulse/logs/stdout.log"
            echo "Query data: redis-cli KEYS \"*\""
        fi
    fi

    if [[ "${ENABLE_PIHOLE:-false}" == "true" ]]; then
        print_header "Phase 11: Optional Features - Pi-hole DNS Ad Blocker"

        if [[ "$DETECTED_OS" != "macos" ]]; then
            print_warning "Pi-hole setup is macOS only (requires Colima). Skipping."
        else
            # Verify prerequisites
            if ! command_exists colima || ! command_exists docker; then
                print_warning "Pi-hole requires colima and docker CLI. Install via: brew bundle --file=$DOTFILES_ROOT/homebrew/Brewfile"
            else
                print_step "Setting up Pi-hole DNS ad blocker..."

                # Start Colima if not running
                if ! colima status &>/dev/null; then
                    print_step "Starting Colima..."
                    colima start --cpu 2 --memory 2 --disk 10 --runtime docker 2>/dev/null &&
                        print_success "Colima started" ||
                        print_warning "Colima start failed - start manually with: colima start"
                fi

                # Start Pi-hole container
                if colima status &>/dev/null; then
                    local pihole_compose="$DOTFILES_ROOT/scripts/pihole/docker-compose.yml"
                    if [[ -f "$pihole_compose" ]]; then
                        docker compose -f "$pihole_compose" up -d 2>/dev/null &&
                            print_success "Pi-hole container started" ||
                            print_warning "Pi-hole container start failed - run manually: ./scripts/pihole/setup-pihole.sh start"

                        print_success "Pi-hole DNS ad blocker configured"
                        echo "  Web Admin: http://localhost:8053/admin"
                        echo "  Activate:  ./scripts/pihole/setup-pihole.sh dns-on"
                        echo "  Status:    ./scripts/pihole/setup-pihole.sh status"
                    else
                        print_warning "Pi-hole docker-compose.yml not found at $pihole_compose"
                    fi
                fi
            fi
        fi
    fi

    if [[ "${ENABLE_SELFHOST_LLM:-false}" == "true" ]]; then
        print_header "Phase 11: Optional Features - Self-Hosted LLM Stack"

        if [[ -f "$DOTFILES_ROOT/scripts/setup-selfhost-llm.sh" ]]; then
            print_step "Running self-hosted LLM setup (Ollama + Open WebUI)..."
            if bash "$DOTFILES_ROOT/scripts/setup-selfhost-llm.sh"; then
                print_success "Self-hosted LLM stack installed"
            else
                print_warning "Self-hosted LLM setup had issues (non-critical)"
            fi
        else
            print_warning "Self-hosted LLM setup script not found"
        fi
    fi

    if [[ "${ENABLE_SONARQUBE:-false}" == "true" ]]; then
        print_header "Phase 11: Optional Features - SonarQube Code Quality"

        if [[ "$DETECTED_OS" != "macos" ]]; then
            print_warning "SonarQube Docker setup is macOS only (requires Colima). Skipping."
        else
            # Verify prerequisites
            if ! command_exists colima || ! command_exists docker; then
                print_warning "SonarQube requires colima and docker CLI. Install via: brew bundle --file=$DOTFILES_ROOT/homebrew/Brewfile"
            else
                print_step "Setting up SonarQube Community Edition..."

                # Verify sonar-scanner is installed
                if ! command_exists sonar-scanner; then
                    print_step "Installing sonar-scanner via Homebrew..."
                    brew install sonar-scanner 2>/dev/null ||
                        print_warning "sonar-scanner installation failed - install manually: brew install sonar-scanner"
                fi

                # Start Colima if not running
                if ! colima status &>/dev/null; then
                    print_step "Starting Colima..."
                    colima start --cpu 2 --memory 4 --disk 20 --runtime docker 2>/dev/null &&
                        print_success "Colima started" ||
                        print_warning "Colima start failed - start manually with: colima start"
                fi

                # Start SonarQube container
                if colima status &>/dev/null; then
                    local sonarqube_compose="$DOTFILES_ROOT/scripts/sonarqube/docker-compose.yml"
                    if [[ -f "$sonarqube_compose" ]]; then
                        # Set vm.max_map_count for Elasticsearch
                        colima ssh -- sudo sysctl -w vm.max_map_count=262144 >/dev/null 2>&1 || true

                        docker compose -f "$sonarqube_compose" up -d 2>/dev/null &&
                            print_success "SonarQube container started" ||
                            print_warning "SonarQube container start failed - run manually: ./scripts/sonarqube/setup-sonarqube.sh start"

                        print_success "SonarQube code quality server configured"
                        echo "  Web UI:    http://localhost:9000"
                        echo "  Default:   admin / admin"
                        echo "  Scan:      sonarqube scan ~/project"
                        echo "  AI scan:   sonar-scan --ai"
                    else
                        print_warning "SonarQube docker-compose.yml not found at $sonarqube_compose"
                    fi
                fi
            fi
        fi
    fi

    mark_step_complete "optional_features"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local start_time=$SECONDS
    parse_args "$@"
    load_modules
    preflight_checks
    show_summary

    # Run installation phases
    # Phases 1-4: sequential (each may depend on packages from earlier phases)
    phase_1_core_packages
    phase_2_cli_tools
    phase_3_development
    phase_4_cloud_tools

    # Phases 5-6: sequential (both use brew which doesn't support concurrent operations)
    phase_5_editors
    phase_6_multiplexer

    # Phases 7-8: sequential (shells setup writes to ~/.config/fish which stow also manages)
    phase_7_shells
    phase_8_dotfiles

    # Phase 9: fonts/apps (uses brew casks)
    phase_9_fonts_and_apps

    # Phase 10: advanced features (cargo, go installs — independent of brew)
    phase_10_advanced_features

    phase_11_optional_features

    # Success
    local elapsed=$((SECONDS - start_time))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    print_header "Setup Complete!"

    echo "Installation Summary:"
    echo "  OS: $DETECTED_OS"
    echo "  Profile: $PROFILE"
    echo "  Mode: $DETECTED_MODE"
    echo "  Duration: ${mins}m ${secs}s"
    echo ""
    echo "Next Steps:"
    echo "  1. Restart your shell (or run: exec fish / source ~/.bashrc)"
    echo "  2. If using tmux: Start tmux and press Ctrl-s + I to install plugins"
    echo "  3. If using Neovim: Run 'nvim' to complete plugin installation"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
    print_success "Setup complete (${mins}m ${secs}s)"
}

# Run main
main "$@"
