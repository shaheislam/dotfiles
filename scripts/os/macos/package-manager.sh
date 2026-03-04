#!/usr/bin/env bash

# macOS Package Manager Implementation - Homebrew
# Implements the abstract package manager interface for macOS

# ============================================================================
# Homebrew Detection & Installation
# ============================================================================

ensure_homebrew() {
    if command_exists brew; then
        log_verbose "Homebrew already installed"
        return 0
    fi

    print_step "Installing Homebrew..."

    if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null; then
        # Add brew to PATH for Apple Silicon
        if [[ $(detect_arch) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        print_success "Homebrew installed"
        return 0
    else
        print_error "Failed to install Homebrew"
        return 1
    fi
}

# ============================================================================
# Package Manager Interface Implementation
# ============================================================================

pm_init() {
    ensure_homebrew || return 1

    export PACKAGE_MANAGER="homebrew"
    log "Package manager initialized: Homebrew"
    return 0
}

pm_update() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would update Homebrew"
        return 0
    fi
    print_step "Updating Homebrew..."
    # Tolerate partial failures (e.g., network errors fetching metadata)
    brew update 2>&1 || log_verbose "Homebrew update completed with warnings"
}

pm_install() {
    local package=$(pm_map_package_name "$1")

    if [[ -z "$package" ]]; then
        return 1
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install $package via brew"
        return 0
    fi
    brew install "$package" 2>&1 | grep -v "already installed" || return 0
}

pm_install_batch() {
    local packages=("$@")
    local mapped=()

    for pkg in "${packages[@]}"; do
        local name
        name=$(pm_map_package_name "$pkg")
        # Skip packages that map to empty (not available on this OS)
        [[ -n "$name" ]] && mapped+=("$name")
    done

    if [[ ${#mapped[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install batch via brew: ${mapped[*]}"
        return 0
    fi
    brew install "${mapped[@]}" 2>&1 | grep -v "already installed" || return 0
}

pm_is_installed() {
    local package=$(pm_map_package_name "$1")
    brew list "$package" &>/dev/null
}

pm_search() {
    brew search "$1"
}

pm_remove() {
    local package=$(pm_map_package_name "$1")
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would uninstall $package via brew"
        return 0
    fi
    brew uninstall "$package"
}

pm_cleanup() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would run brew cleanup"
        return 0
    fi
    brew cleanup
}

pm_map_package_name() {
    local generic=$1

    case "$generic" in
    # Core tools
    build-essential) echo "" ;; # Not needed on macOS
    development-tools) echo "" ;;

    # CLI tools - most have same names
    ripgrep | fd | fzf | bat | jq | htop | curl | wget | git | stow | tmux) echo "$generic" ;;

    # Modern CLI tools
    eza) echo "eza" ;;
    zoxide) echo "zoxide" ;;
    starship) echo "starship" ;;
    direnv) echo "direnv" ;;

    # Shells
    fish) echo "fish" ;;
    zsh) echo "zsh" ;; # Built-in but brew version newer

    # Editors
    neovim) echo "neovim" ;;

    # Development
    nodejs) echo "node" ;;
    python) echo "python@3.11" ;;
    golang) echo "go" ;;
    rust) echo "rust" ;;

    # Cloud tools
    awscli) echo "awscli" ;;
    kubectl) echo "kubectl" ;;
    helm) echo "helm" ;;
    terraform) echo "terraform" ;;

    # Casks (require --cask flag)
    ollama) echo "--cask ollama" ;;

    # Default: return as-is
    *) echo "$generic" ;;
    esac
}

log_verbose "macOS package manager module loaded"
