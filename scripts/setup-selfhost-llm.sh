#!/usr/bin/env bash

# setup-selfhost-llm.sh - Set up self-hosted LLM infrastructure
#
# Resilience layer: if Claude, Codex, or other cloud AI services go down,
# this provides local LLM capabilities for coding and general use.
#
# Usage:
#   ./scripts/setup-selfhost-llm.sh              # Install everything
#   ./scripts/setup-selfhost-llm.sh --verbose     # With detailed output
#   ./scripts/setup-selfhost-llm.sh --uninstall   # Remove everything
#   ./scripts/setup-selfhost-llm.sh --models-only # Just pull recommended models
#   ./scripts/setup-selfhost-llm.sh --help        # Show help
#
# What this script does:
#   1. Installs Ollama (local LLM runtime)
#   2. Installs Open WebUI (browser-based chat interface)
#   3. Pulls recommended models for coding and general use
#   4. Configures launchd to auto-start Ollama on boot
#   5. Sets up environment variables for API compatibility

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common utilities
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific state
VERBOSE="${VERBOSE:-false}"
UNINSTALL=false
MODELS_ONLY=false

# Default models to pull (coding-focused + general purpose)
# These are selected for a balance of capability and resource usage
CODING_MODELS=(
    "qwen2.5-coder:7b"    # Strong coding model, reasonable size
    "deepseek-coder-v2:16b" # Deep reasoning for complex code tasks
    "qwen3-coder"          # Agentic coding model, 256K context (OpenCode/Claude Code)
)

GENERAL_MODELS=(
    "llama3.1:8b"          # Meta's general-purpose model, fast
    "mistral:7b"           # Good all-rounder, low resource usage
)

LARGE_MODELS=(
    "qwen2.5-coder:32b"    # Premium coding - needs 32GB+ RAM
    "llama3.1:70b"          # Premium general - needs 64GB+ RAM
)

# Open WebUI configuration
OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-8080}"

# ============================================================================
# Help
# ============================================================================

show_help() {
    cat << EOF
Self-Hosted LLM Setup - Local AI resilience layer

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --verbose       Show detailed output
    --uninstall     Remove Ollama, Open WebUI, and downloaded models
    --models-only   Only pull/update recommended models (skip installation)
    --large-models  Also pull large models (needs 32GB+ RAM)
    --help          Show this help message

DESCRIPTION:
    Sets up a local LLM stack as a fallback when cloud AI services
    (Claude, Codex, etc.) are unavailable. Components:

    1. Ollama       - Local LLM runtime (runs models on your hardware)
    2. Open WebUI   - Browser-based chat interface (localhost:${OPEN_WEBUI_PORT})
    3. Models       - Pre-pulled coding and general-purpose models

MODELS INSTALLED:
    Coding:
      - qwen2.5-coder:7b      (~4GB)  Fast coding assistant
      - deepseek-coder-v2:16b  (~9GB)  Deep reasoning for complex code
      - qwen3-coder            (~5GB)  Agentic coding, 256K context

    General:
      - llama3.1:8b            (~4GB)  Fast general-purpose
      - mistral:7b             (~4GB)  Balanced all-rounder

    Large (--large-models):
      - qwen2.5-coder:32b     (~18GB) Premium coding (32GB+ RAM)
      - llama3.1:70b           (~40GB) Premium general (64GB+ RAM)

ENVIRONMENT VARIABLES:
    OPEN_WEBUI_PORT     Port for Open WebUI (default: 8080)

AFTER INSTALLATION:
    - Open WebUI:    http://localhost:${OPEN_WEBUI_PORT}
    - Ollama API:    http://localhost:11434
    - Fish commands: llm, llm-chat, llm-code, llm-status, llm-pull

EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

PULL_LARGE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose)     VERBOSE=true; shift ;;
        --uninstall)   UNINSTALL=true; shift ;;
        --models-only) MODELS_ONLY=true; shift ;;
        --large-models) PULL_LARGE=true; shift ;;
        --help|-h)     show_help; exit 0 ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# Uninstall
# ============================================================================

uninstall() {
    print_header "Uninstalling Self-Hosted LLM Stack"

    # Stop Ollama service
    print_step "Stopping Ollama service..."
    if command -v ollama &>/dev/null; then
        pkill -f "ollama serve" 2>/dev/null || true
        # Remove launchd plist if exists
        local plist="$HOME/Library/LaunchAgents/com.ollama.server.plist"
        if [[ -f "$plist" ]]; then
            launchctl unload "$plist" 2>/dev/null || true
            rm -f "$plist"
            print_success "Removed Ollama launchd service"
        fi
    fi

    # Remove Open WebUI
    print_step "Removing Open WebUI..."
    if command -v pip3 &>/dev/null; then
        pip3 uninstall -y open-webui 2>/dev/null || true
        print_success "Open WebUI removed"
    fi

    # Remove Ollama and models
    print_step "Removing Ollama and downloaded models..."
    if [[ "$(detect_os)" == "macos" ]]; then
        brew uninstall --cask ollama 2>/dev/null || true
    fi
    rm -rf "$HOME/.ollama" 2>/dev/null || true
    print_success "Ollama and models removed"

    print_success "Self-hosted LLM stack uninstalled"
    print_warning "Note: Brewfile entry remains - remove manually if desired"
}

if [[ "$UNINSTALL" == "true" ]]; then
    uninstall
    exit 0
fi

# ============================================================================
# Installation
# ============================================================================

install_ollama() {
    print_header "Phase 1: Ollama Runtime"

    if command -v ollama &>/dev/null; then
        local version
        version=$(ollama --version 2>/dev/null || echo "unknown")
        print_success "Ollama already installed (${version})"
        return 0
    fi

    print_step "Installing Ollama..."
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            if command -v brew &>/dev/null; then
                brew install --cask ollama
                print_success "Ollama installed via Homebrew"
            else
                print_error "Homebrew required for macOS installation"
                return 1
            fi
            ;;
        linux)
            # Official Ollama install script
            curl -fsSL https://ollama.com/install.sh | sh
            print_success "Ollama installed via official script"
            ;;
        *)
            print_error "Unsupported OS: $os_type"
            return 1
            ;;
    esac
}

start_ollama() {
    print_step "Ensuring Ollama is running..."

    # Check if already running
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        print_success "Ollama is already running"
        return 0
    fi

    # Start Ollama
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            # On macOS, Ollama.app manages its own server
            if [[ -d "/Applications/Ollama.app" ]]; then
                open -a Ollama
                print_step "Starting Ollama.app..."
            else
                ollama serve &>/dev/null &
                print_step "Starting ollama serve..."
            fi
            ;;
        linux)
            if systemctl is-enabled ollama &>/dev/null; then
                sudo systemctl start ollama
            else
                ollama serve &>/dev/null &
            fi
            ;;
    esac

    # Wait for Ollama to be ready
    local attempts=0
    while ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; do
        sleep 1
        attempts=$((attempts + 1))
        if [[ $attempts -ge 30 ]]; then
            print_error "Ollama failed to start within 30 seconds"
            return 1
        fi
    done

    print_success "Ollama is running (localhost:11434)"
}

pull_models() {
    print_header "Phase 2: Pulling Models"

    local models_to_pull=("${CODING_MODELS[@]}" "${GENERAL_MODELS[@]}")
    if [[ "$PULL_LARGE" == "true" ]]; then
        models_to_pull+=("${LARGE_MODELS[@]}")
        print_warning "Including large models - this will use significant disk space"
    fi

    local total=${#models_to_pull[@]}
    local current=0

    for model in "${models_to_pull[@]}"; do
        current=$((current + 1))
        print_step "[$current/$total] Pulling $model..."

        # Check if model is already available
        if ollama list 2>/dev/null | grep -q "^${model%%:*}"; then
            log_verbose "$model already available, checking for updates..."
        fi

        if ollama pull "$model" 2>&1 | tail -1; then
            print_success "$model ready"
        else
            print_warning "Failed to pull $model (will retry on next run)"
        fi
    done

    print_success "Model downloads complete"
    echo ""
    print_step "Installed models:"
    ollama list 2>/dev/null || true
}

install_open_webui() {
    print_header "Phase 3: Open WebUI"

    # Check if already installed
    if command -v open-webui &>/dev/null; then
        print_success "Open WebUI already installed"
        return 0
    fi

    print_step "Installing Open WebUI..."

    # Use pipx for isolated installation (preferred), fallback to pip
    if command -v pipx &>/dev/null; then
        pipx install open-webui 2>&1 | tail -3
        print_success "Open WebUI installed via pipx"
    elif command -v pip3 &>/dev/null; then
        pip3 install --user open-webui 2>&1 | tail -3
        print_success "Open WebUI installed via pip3"
    else
        print_warning "Neither pipx nor pip3 found - skipping Open WebUI"
        print_warning "Install manually: pipx install open-webui"
        return 0
    fi
}

configure_autostart() {
    print_header "Phase 4: Auto-Start Configuration"

    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        macos)
            # On macOS, Ollama.app auto-starts itself when installed as a cask
            # We just need to ensure it's in Login Items
            if [[ -d "/Applications/Ollama.app" ]]; then
                print_success "Ollama.app manages auto-start via Login Items"
                print_step "If not auto-starting: System Settings > General > Login Items > Add Ollama"
            fi
            ;;
        linux)
            # Enable systemd service if available
            if systemctl list-unit-files | grep -q ollama; then
                sudo systemctl enable ollama
                print_success "Ollama systemd service enabled"
            fi
            ;;
    esac
}

configure_opencode() {
    print_header "Phase 5: OpenCode Configuration"

    if ! command -v opencode &>/dev/null; then
        print_warning "OpenCode not installed - skipping configuration"
        print_step "Install with: brew install opencode"
        return 0
    fi

    local config_dir="$HOME/.config/opencode"
    local config_file="$config_dir/opencode.json"
    local dotfiles_config="$DOTFILES_ROOT/.config/opencode/opencode.json"

    # Config is managed by stow - just verify it's in place
    if [[ -f "$config_file" ]]; then
        if grep -q '"ollama"' "$config_file" 2>/dev/null; then
            print_success "OpenCode Ollama provider already configured"
        else
            print_warning "OpenCode config exists but missing Ollama provider"
            print_step "Run 'stow .' from dotfiles root to update symlinks"
        fi
    else
        print_step "OpenCode config will be symlinked by stow"
        print_step "Run 'cd ~/dotfiles && stow .' to create symlinks"
    fi

    print_success "OpenCode ready for local LLM use (opencode-local)"
}

print_summary() {
    print_header "Setup Complete"

    echo ""
    echo -e "${GREEN}Self-Hosted LLM Stack Ready${NC}"
    echo ""
    echo "  Ollama API:    http://localhost:11434"
    echo "  Open WebUI:    http://localhost:${OPEN_WEBUI_PORT}"
    echo ""
    echo "  Quick start:"
    echo "    ollama run qwen2.5-coder:7b    # Coding assistant"
    echo "    ollama run llama3.1:8b          # General chat"
    echo "    open-webui serve                # Web interface"
    echo ""
    echo "  Coding agents (local):"
    echo "    opencode-local                  # OpenCode + Ollama (primary)"
    echo "    claude-local                    # Claude Code + Ollama (alternative)"
    echo ""
    echo "  Fish shell commands (after fish reload):"
    echo "    llm <prompt>                    # Quick query (default model)"
    echo "    llm-chat                        # Interactive chat session"
    echo "    llm-code <prompt>               # Code-focused query"
    echo "    llm-status                      # Check Ollama status and models"
    echo "    llm-pull <model>                # Pull a new model"
    echo "    llm-web                         # Launch Open WebUI"
    echo ""
    echo "  API-compatible endpoint (for tools expecting OpenAI API):"
    echo "    OPENAI_API_BASE=http://localhost:11434/v1"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    print_header "Self-Hosted LLM Setup"
    echo "Setting up local LLM infrastructure for AI resilience..."
    echo ""

    if [[ "$MODELS_ONLY" == "true" ]]; then
        start_ollama
        pull_models
        exit 0
    fi

    install_ollama
    start_ollama
    pull_models
    install_open_webui
    configure_autostart
    configure_opencode
    print_summary
}

main
