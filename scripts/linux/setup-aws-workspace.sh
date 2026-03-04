#!/usr/bin/env bash

# setup-aws-workspace.sh - AWS Linux Workspace Setup Script
# Sets up development environment with Neovim, Fish/Zsh, tmux, and dev tools
# Distribution-agnostic with support for Amazon Linux, Ubuntu, RHEL, etc.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Flags
DRY_RUN=false
SKIP_NEOVIM=false
SKIP_SHELLS=false
SKIP_STOW=false
MINIMAL=false
VERBOSE=false

# Installation tracking
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
SKIPPED_STEPS=()

# ============================================================================
# Utility Functions
# ============================================================================

print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_verbose() {
    if [[ $VERBOSE == true ]]; then
        echo -e "${MAGENTA}[VERBOSE] $1${NC}"
    fi
}

# ============================================================================
# Help Function
# ============================================================================

show_help() {
    cat <<EOF
AWS Linux Workspace Setup Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run           Preview actions without executing
    --minimal           Install only core tools (skip dev tools)
    --skip-neovim       Skip Neovim installation and configuration
    --skip-shells       Skip Fish and Zsh shell setup
    --skip-stow         Skip dotfiles symlinking with stow
    --verbose           Show detailed output
    -h, --help          Show this help message

EXAMPLES:
    $0                              # Full setup
    $0 --minimal                    # Core tools only
    $0 --skip-neovim --skip-shells  # Skip editor and shells
    $0 --dry-run                    # Preview what would be installed

DESCRIPTION:
    This script sets up a development environment on Linux systems with:
    - Core CLI tools (git, ripgrep, fzf, bat, etc.)
    - Neovim with your configuration
    - Fish and Zsh shells with plugins
    - tmux with plugins and themes
    - Development tools (Node.js, Python, Go, Rust)
    - AWS and Kubernetes tools
    - Dotfiles symlinking via stow

    The script auto-detects your Linux distribution and adapts accordingly.
    It works with Amazon Linux, Ubuntu, RHEL, CentOS, Debian, and more.

EOF
}

# ============================================================================
# Parse Command Line Arguments
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --minimal)
            MINIMAL=true
            shift
            ;;
        --skip-neovim)
            SKIP_NEOVIM=true
            shift
            ;;
        --skip-shells)
            SKIP_SHELLS=true
            shift
            ;;
        --skip-stow)
            SKIP_STOW=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
        esac
    done
}

# ============================================================================
# Source Package Manager Functions
# ============================================================================

source_package_manager() {
    local pkg_script="$SCRIPT_DIR/linux-packages.sh"

    if [[ ! -f "$pkg_script" ]]; then
        print_error "Package manager script not found: $pkg_script"
        exit 1
    fi

    print_step "Loading package manager functions..."
    # shellcheck source=./linux-packages.sh
    source "$pkg_script"
    print_success "Package manager initialized: $PACKAGE_MANAGER"
}

# ============================================================================
# Phase 1: Core Package Installation
# ============================================================================

install_core_tools() {
    print_header "Phase 1: Installing Core Tools"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would install core packages"
        return
    fi

    print_step "Updating package cache..."
    update_package_cache

    print_step "Installing essential packages..."
    install_core_packages

    print_success "Core tools installed"
}

# ============================================================================
# Phase 2: CLI Utilities
# ============================================================================

install_cli_utilities() {
    print_header "Phase 2: Installing CLI Utilities"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would install CLI utilities"
        return
    fi

    # Install available CLI tools
    print_step "Installing modern CLI tools..."
    install_cli_tools

    # Install eza (modern ls replacement)
    install_eza

    # Install zoxide (smart cd)
    install_zoxide

    # Install starship prompt
    install_starship

    # Install direnv
    install_direnv

    print_success "CLI utilities installed"
}

install_eza() {
    if command -v eza &>/dev/null; then
        log_verbose "eza already installed"
        return
    fi

    print_step "Installing eza..."

    if [[ $HAS_SUDO == true ]]; then
        case $PACKAGE_MANAGER in
        apt)
            # eza is available in Ubuntu 24.04+ repos
            if install_package "eza" 2>/dev/null; then
                print_success "eza installed from repository"
            else
                # Install from GitHub releases
                install_eza_from_binary
            fi
            ;;
        *)
            install_eza_from_binary
            ;;
        esac
    else
        install_eza_from_binary
    fi
}

install_eza_from_binary() {
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"

    print_step "Installing eza from GitHub releases..."
    local latest_url="https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"

    if curl -L "$latest_url" | tar xz -C "$install_dir"; then
        print_success "eza installed to $install_dir"
    else
        print_warning "Failed to install eza"
    fi
}

install_zoxide() {
    if command -v zoxide &>/dev/null; then
        log_verbose "zoxide already installed"
        return
    fi

    print_step "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

install_starship() {
    if command -v starship &>/dev/null; then
        log_verbose "starship already installed"
        return
    fi

    print_step "Installing starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
}

install_direnv() {
    if command -v direnv &>/dev/null; then
        log_verbose "direnv already installed"
        return
    fi

    print_step "Installing direnv..."

    if ! install_package "direnv"; then
        # Install from binary
        local install_dir="$HOME/.local/bin"
        mkdir -p "$install_dir"
        curl -sfL https://direnv.net/install.sh | bash
    fi
}

# ============================================================================
# Phase 3: Development Tools
# ============================================================================

install_development_tools() {
    if [[ $MINIMAL == true ]]; then
        print_warning "Skipping development tools (minimal mode)"
        SKIPPED_STEPS+=("Development tools")
        return
    fi

    print_header "Phase 3: Installing Development Tools"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would install development tools"
        return
    fi

    # Install base development packages
    install_development_tools

    # Install Node.js
    install_nodejs

    # Install Python tools
    install_python_tools

    # Install Go
    install_golang

    # Install Rust
    install_rust

    print_success "Development tools installed"
}

install_nodejs() {
    if command -v node &>/dev/null; then
        log_verbose "Node.js already installed: $(node --version)"
        return
    fi

    print_step "Installing Node.js via nvm..."

    # Install nvm
    if [[ ! -d "$HOME/.nvm" ]]; then
        local nvm_version
        nvm_version=$(curl -sL https://api.github.com/repos/nvm-sh/nvm/releases/latest 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        nvm_version=${nvm_version:-v0.40.1}
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash </dev/null

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    # Install LTS version
    nvm install --lts
    nvm use --lts

    print_success "Node.js installed: $(node --version)"

    # Install pnpm
    if ! command -v pnpm &>/dev/null; then
        npm install -g pnpm
        print_success "pnpm installed"
    fi
}

install_python_tools() {
    print_step "Installing Python tools..."

    if command -v pip3 &>/dev/null; then
        pip3 install --user --upgrade pip
        pip3 install --user pipx
        pip3 install --user black isort ruff
        print_success "Python tools installed"
    else
        print_warning "pip3 not found, skipping Python tools"
    fi
}

install_golang() {
    if command -v go &>/dev/null; then
        log_verbose "Go already installed: $(go version)"
        return
    fi

    print_step "Installing Go..."

    if install_package "golang" || install_package "golang-go"; then
        print_success "Go installed from package manager"
    else
        # Install from binary
        local go_version="1.22.0"
        local go_url="https://go.dev/dl/go${go_version}.linux-amd64.tar.gz"

        curl -L "$go_url" | sudo tar -C /usr/local -xzf -

        # Add to PATH
        if [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >>~/.bashrc
        fi

        print_success "Go installed from binary"
    fi
}

install_rust() {
    if command -v rustc &>/dev/null; then
        log_verbose "Rust already installed: $(rustc --version)"
        return
    fi

    print_step "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Source cargo env
    source "$HOME/.cargo/env"

    print_success "Rust installed: $(rustc --version)"
}

# ============================================================================
# Phase 4: AWS and Kubernetes Tools
# ============================================================================

install_aws_k8s_tools() {
    if [[ $MINIMAL == true ]]; then
        print_warning "Skipping AWS/K8s tools (minimal mode)"
        SKIPPED_STEPS+=("AWS/Kubernetes tools")
        return
    fi

    print_header "Phase 4: Installing AWS and Kubernetes Tools"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would install AWS/K8s tools"
        return
    fi

    # Install AWS CLI
    install_awscli

    # Install kubectl
    install_kubectl

    # Install helm
    install_helm

    print_success "AWS and Kubernetes tools installed"
}

install_awscli() {
    if command -v aws &>/dev/null; then
        log_verbose "AWS CLI already installed: $(aws --version)"
        return
    fi

    print_step "Installing AWS CLI v2..."

    local install_dir="$HOME/.local/aws-cli"
    mkdir -p "$install_dir"

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install -i "$install_dir" -b "$HOME/.local/bin"

    rm -rf /tmp/aws /tmp/awscliv2.zip

    print_success "AWS CLI installed"
}

install_kubectl() {
    if command -v kubectl &>/dev/null; then
        log_verbose "kubectl already installed: $(kubectl version --client --short 2>/dev/null)"
        return
    fi

    print_step "Installing kubectl..."

    if ! install_package "kubectl"; then
        # Install from binary
        local kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/$kubectl_version/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv kubectl "$HOME/.local/bin/"
    fi

    print_success "kubectl installed"
}

install_helm() {
    if command -v helm &>/dev/null; then
        log_verbose "helm already installed: $(helm version --short)"
        return
    fi

    print_step "Installing helm..."

    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    print_success "helm installed"
}

# ============================================================================
# Phase 5: Shell Setup
# ============================================================================

setup_shells() {
    if [[ $SKIP_SHELLS == true ]]; then
        print_warning "Skipping shell setup"
        SKIPPED_STEPS+=("Shell setup")
        return
    fi

    print_header "Phase 5: Setting Up Shells"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would set up shells"
        return
    fi

    # Install shells
    print_step "Installing Fish and Zsh..."
    install_shell_packages

    # Setup Fish
    setup_fish_shell

    # Setup Zsh
    setup_zsh_shell

    print_success "Shell setup complete"
}

setup_fish_shell() {
    if ! command -v fish &>/dev/null; then
        print_warning "Fish not installed, skipping Fish setup"
        return
    fi

    print_step "Setting up Fish shell..."

    # Install Fisher plugin manager
    if [[ ! -f "$HOME/.config/fish/functions/fisher.fish" ]]; then
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    fi

    # Install Fish plugins
    local fish_plugins=(
        "jethrokuan/z"
        "PatrickF1/fzf.fish"
        "jorgebucaran/autopair.fish"
        "gazorby/fish-abbreviation-tips"
        "meaningful-ooo/sponge"
        "franciscolourenco/done"
        "decors/fish-colored-man"
    )

    for plugin in "${fish_plugins[@]}"; do
        fish -c "fisher install $plugin" 2>/dev/null || true
    done

    print_success "Fish shell configured"
}

setup_zsh_shell() {
    if ! command -v zsh &>/dev/null; then
        print_warning "Zsh not installed, skipping Zsh setup"
        return
    fi

    print_step "Setting up Zsh shell..."

    # Install Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    # Install zsh plugins
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # Fast syntax highlighting
    if [[ ! -d "$zsh_custom/plugins/fast-syntax-highlighting" ]]; then
        git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$zsh_custom/plugins/fast-syntax-highlighting"
    fi

    # Autosuggestions
    if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    fi

    # Completions
    if [[ ! -d "$zsh_custom/plugins/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions "$zsh_custom/plugins/zsh-completions"
    fi

    print_success "Zsh shell configured"
}

# ============================================================================
# Phase 6: Neovim Setup
# ============================================================================

setup_neovim() {
    if [[ $SKIP_NEOVIM == true ]]; then
        print_warning "Skipping Neovim setup"
        SKIPPED_STEPS+=("Neovim setup")
        return
    fi

    print_header "Phase 6: Setting Up Neovim"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would set up Neovim"
        return
    fi

    # Run Neovim setup script
    local nvim_script="$SCRIPT_DIR/setup-neovim-linux.sh"

    if [[ -f "$nvim_script" ]]; then
        print_step "Running Neovim setup script..."
        bash "$nvim_script"
    else
        print_error "Neovim setup script not found: $nvim_script"
    fi
}

# ============================================================================
# Phase 7: tmux Setup
# ============================================================================

setup_tmux() {
    print_header "Phase 7: Setting Up tmux"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would set up tmux"
        return
    fi

    # Install tmux
    if ! command -v tmux &>/dev/null; then
        print_step "Installing tmux..."
        install_package "tmux"
    fi

    # Install Tmux Plugin Manager (TPM)
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        print_step "Installing Tmux Plugin Manager..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        print_success "TPM installed"
    fi

    print_success "tmux setup complete"
    print_warning "Run 'tmux' then press 'Ctrl-s + I' to install tmux plugins"
}

# ============================================================================
# Phase 8: Dotfiles Symlinking
# ============================================================================

setup_dotfiles() {
    if [[ $SKIP_STOW == true ]]; then
        print_warning "Skipping dotfiles symlinking"
        SKIPPED_STEPS+=("Dotfiles symlinking")
        return
    fi

    print_header "Phase 8: Symlinking Dotfiles"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would symlink dotfiles with stow"
        return
    fi

    # Check if stow is installed
    if ! command -v stow &>/dev/null; then
        print_error "stow not installed"
        return 1
    fi

    # Navigate to dotfiles directory
    cd "$DOTFILES_DIR"

    print_step "Running stow to symlink dotfiles..."

    if stow . --adopt --verbose 2>&1; then
        print_success "Dotfiles symlinked successfully"
    else
        print_error "Stow failed, please check for conflicts"
        return 1
    fi

    # Create necessary directories
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.config"

    print_success "Dotfiles setup complete"
}

# ============================================================================
# Phase 9: Final Configuration
# ============================================================================

final_configuration() {
    print_header "Phase 9: Final Configuration"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN: Would perform final configuration"
        return
    fi

    # Install Nerd Fonts
    install_nerd_fonts

    # Set Fish as default shell (if not minimal)
    if [[ $SKIP_SHELLS == false && $MINIMAL == false ]]; then
        set_default_shell
    fi

    # Add ~/.local/bin to PATH if not already there
    ensure_local_bin_in_path

    print_success "Final configuration complete"
}

install_nerd_fonts() {
    print_step "Installing Nerd Fonts..."

    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"

    # Install JetBrainsMono Nerd Font
    if [[ ! -f "$fonts_dir/JetBrainsMonoNerdFont-Regular.ttf" ]]; then
        local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        curl -L "$font_url" -o /tmp/JetBrainsMono.zip
        unzip -q /tmp/JetBrainsMono.zip -d "$fonts_dir"
        rm /tmp/JetBrainsMono.zip

        # Update font cache
        if command -v fc-cache &>/dev/null; then
            fc-cache -f "$fonts_dir"
        fi

        print_success "JetBrainsMono Nerd Font installed"
    else
        log_verbose "JetBrainsMono Nerd Font already installed"
    fi
}

set_default_shell() {
    if ! command -v fish &>/dev/null; then
        print_warning "Fish not installed, cannot set as default shell"
        return
    fi

    local fish_path=$(command -v fish)

    # Check if fish is in /etc/shells
    if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
        if [[ $HAS_SUDO == true ]]; then
            print_step "Adding Fish to /etc/shells..."
            echo "$fish_path" | sudo tee -a /etc/shells
        else
            print_warning "Cannot add Fish to /etc/shells (no sudo)"
            return
        fi
    fi

    # Change default shell
    if [[ "$SHELL" != "$fish_path" ]]; then
        print_step "Setting Fish as default shell..."
        if chsh -s "$fish_path" 2>/dev/null; then
            print_success "Fish set as default shell"
            print_warning "Log out and back in for changes to take effect"
        else
            print_warning "Could not change default shell"
        fi
    fi
}

ensure_local_bin_in_path() {
    local bashrc="$HOME/.bashrc"

    if [[ -f "$bashrc" ]] && ! grep -q '.local/bin' "$bashrc"; then
        print_step "Adding ~/.local/bin to PATH..."
        echo '' >>"$bashrc"
        echo '# Add local bin to PATH' >>"$bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$bashrc"
        print_success "Added ~/.local/bin to PATH in ~/.bashrc"
    fi
}

# ============================================================================
# Summary Report
# ============================================================================

print_summary() {
    print_header "Setup Complete!"

    echo -e "${GREEN}Installation Summary:${NC}"
    echo -e "  Distribution: ${BLUE}$DISTRO${NC}"
    echo -e "  Package Manager: ${BLUE}$PACKAGE_MANAGER${NC}"
    echo -e "  Sudo Access: ${BLUE}$HAS_SUDO${NC}"

    if [[ ${#SKIPPED_STEPS[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Skipped Steps:${NC}"
        for step in "${SKIPPED_STEPS[@]}"; do
            echo -e "  - $step"
        done
    fi

    echo -e "\n${CYAN}Next Steps:${NC}"
    echo -e "  1. Log out and back in for shell changes to take effect"
    echo -e "  2. Run ${BLUE}tmux${NC} then press ${BLUE}Ctrl-s + I${NC} to install tmux plugins"
    echo -e "  3. Run ${BLUE}nvim${NC} to start Neovim and let plugins install"
    echo -e "  4. Run ${BLUE}fish${NC} to start Fish shell"

    echo -e "\n${GREEN}Happy coding! 🚀${NC}\n"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    # Parse command line arguments
    parse_args "$@"

    # Print banner
    print_header "AWS Linux Workspace Setup"

    if [[ $DRY_RUN == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi

    # Initialize package manager
    source_package_manager

    # Run setup phases
    install_core_tools
    install_cli_utilities
    install_development_tools
    install_aws_k8s_tools
    setup_shells
    setup_neovim
    setup_tmux
    setup_dotfiles
    final_configuration

    # Print summary
    print_summary
}

# Run main function
main "$@"
