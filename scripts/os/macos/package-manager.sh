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

    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
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

pm_upgrade() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would upgrade all Homebrew packages"
        return 0
    fi
    print_step "Upgrading Homebrew packages..."
    brew upgrade 2>&1 || log_verbose "Homebrew upgrade completed with warnings"
}

pm_install() {
    local package
    local output status

    package=$(pm_map_package_name "$1")

    if [[ -z "$package" ]]; then
        return 1
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install $package via brew"
        return 0
    fi
    if pm_is_cask_package "$1"; then
        output=$(brew install --cask "$package" 2>&1)
        status=$?
        printf '%s\n' "$output" | grep -v "already installed" || true
        return $status
    fi

    output=$(brew install "$package" 2>&1)
    status=$?
    printf '%s\n' "$output" | grep -v "already installed" || true
    return $status
}

pm_install_batch() {
    local packages=("$@")
    local formulae=()
    local casks=()

    for pkg in "${packages[@]}"; do
        local name
        name=$(pm_map_package_name "$pkg")
        # Skip packages that map to empty (not available on this OS)
        [[ -z "$name" ]] && continue
        if pm_is_cask_package "$pkg"; then
            casks+=("$name")
        else
            formulae+=("$name")
        fi
    done

    if [[ ${#formulae[@]} -eq 0 && ${#casks[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install batch via brew: ${formulae[*]} ${casks[*]}"
        return 0
    fi

    local status=0
    if [[ ${#formulae[@]} -gt 0 ]]; then
        local output formula_status
        output=$(brew install "${formulae[@]}" 2>&1)
        formula_status=$?
        printf '%s\n' "$output" | grep -v "already installed" || true
        status=$formula_status
    fi
    if [[ ${#casks[@]} -gt 0 ]]; then
        local output cask_status
        output=$(brew install --cask "${casks[@]}" 2>&1)
        cask_status=$?
        printf '%s\n' "$output" | grep -v "already installed" || true
        [[ $cask_status -ne 0 ]] && status=$cask_status
    fi

    return $status
}

pm_is_installed() {
    local package
    package=$(pm_map_package_name "$1")

    if pm_is_cask_package "$1"; then
        brew list --cask "$package" &>/dev/null
    else
        brew list "$package" &>/dev/null
    fi
}

pm_search() {
    brew search "$1"
}

pm_remove() {
    local package
    package=$(pm_map_package_name "$1")

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

    # Casks are still returned as package names; install/check functions add --cask.
    ollama) echo "ollama" ;;

    # Default: return as-is
    *) echo "$generic" ;;
    esac
}

pm_is_cask_package() {
    case "$1" in
    ollama) return 0 ;;
    *) return 1 ;;
    esac
}

log_verbose "macOS package manager module loaded"
