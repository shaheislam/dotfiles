#!/usr/bin/env bash

# shell-setup.sh - Shell configuration module
# Sets up Fish, Zsh, and shell plugins

source "$SCRIPT_DIR/lib/common.sh"

# ============================================================================
# Fish Shell Setup
# ============================================================================

setup_fish() {
    if ! command_exists fish; then
        log_verbose "Fish not installed, skipping setup"
        return 0
    fi

    print_header "Setting up Fish Shell"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install Fisher and Fish plugins"
        return 0
    fi

    # Install Fisher plugin manager
    if [[ ! -f "$HOME/.config/fish/functions/fisher.fish" ]]; then
        print_step "Installing Fisher..."
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    fi

    # Install plugins
    local plugins=(
        "jethrokuan/z"
        "PatrickF1/fzf.fish"
        "jorgebucaran/autopair.fish"
        "franciscolourenco/done"
        "gazorby/fish-abbreviation-tips"
        "patrickf3139/colored-man-pages"
        "evanlucas/fish-kubectl-completions"
        "oh-my-fish/plugin-bang-bang"
        "jhillyerd/plugin-git"
    )

    print_step "Installing Fish plugins..."
    for plugin in "${plugins[@]}"; do
        print_info "Installing $plugin..."
        fish -c "fisher install $plugin" 2>/dev/null || true
    done

    print_success "Fish shell configured with ${#plugins[@]} plugins"
}

# ============================================================================
# Zsh Shell Setup
# ============================================================================

setup_zsh() {
    if ! command_exists zsh; then
        log_verbose "Zsh not installed, skipping setup"
        return 0
    fi

    print_header "Setting up Zsh Shell"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would install Oh My Zsh and plugins"
        return 0
    fi

    # Install Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_step "Installing Oh My Zsh..."
        RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    # Install plugins
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    print_step "Installing Zsh plugins..."

    # Core plugins
    local plugins=(
        "fast-syntax-highlighting:zdharma-continuum/fast-syntax-highlighting"
        "zsh-autosuggestions:zsh-users/zsh-autosuggestions"
        "zsh-completions:zsh-users/zsh-completions"
        "fzf-tab:Aloxaf/fzf-tab"
        "zsh-kubectl-prompt:superbrothers/zsh-kubectl-prompt"
        "docker-zsh-completion:greymd/docker-zsh-completion"
        "zsh-history-substring-search:zsh-users/zsh-history-substring-search"
        "zsh-vi-mode:jeffreytse/zsh-vi-mode"
    )

    for plugin_def in "${plugins[@]}"; do
        local plugin_name="${plugin_def%%:*}"
        local plugin_repo="${plugin_def##*:}"

        if [[ ! -d "$zsh_custom/plugins/$plugin_name" ]]; then
            print_info "Installing $plugin_name..."
            git clone "https://github.com/$plugin_repo.git" "$zsh_custom/plugins/$plugin_name" 2>/dev/null || true
        else
            log_verbose "$plugin_name already installed"
        fi
    done

    print_success "Zsh shell configured with ${#plugins[@]} plugins"
}

# ============================================================================
# Starship Prompt
# ============================================================================

setup_starship() {
    if ! command_exists starship; then
        log_verbose "Starship not installed, skipping setup"
        return 0
    fi

    print_step "Configuring Starship prompt..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would add starship init to shell configs"
        return 0
    fi

    # Init in shells
    local bashrc="$HOME/.bashrc"
    local zshrc="$HOME/.zshrc"
    local fish_config="$HOME/.config/fish/config.fish"

    if [[ -f "$bashrc" ]] && ! grep -q "starship init" "$bashrc"; then
        echo 'eval "$(starship init bash)"' >> "$bashrc"
    fi

    if [[ -f "$zshrc" ]] && ! grep -q "starship init" "$zshrc"; then
        echo 'eval "$(starship init zsh)"' >> "$zshrc"
    fi

    if [[ -f "$fish_config" ]] && ! grep -q "starship init" "$fish_config"; then
        echo 'starship init fish | source' >> "$fish_config"
    fi

    print_success "Starship configured"
}

# ============================================================================
# FZF Git Integration
# ============================================================================

setup_fzf_git() {
    if ! command_exists fzf; then
        log_verbose "FZF not installed, skipping fzf-git setup"
        return 0
    fi

    print_step "Setting up FZF Git integration..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would clone fzf-git integration"
        return 0
    fi

    local fzf_git_dir="$HOME/fzf-git.sh"
    if [[ ! -d "$fzf_git_dir" ]]; then
        git clone https://github.com/junegunn/fzf-git.sh.git "$fzf_git_dir" 2>/dev/null
        print_success "FZF Git integration installed"
    else
        log_verbose "FZF Git integration already installed"
    fi
}

# ============================================================================
# Main Setup
# ============================================================================

setup_shells_from_profile() {
    local profile=$1

    local packages=$(get_package_list_from_profile "$profile" "shells")

    if [[ "$packages" =~ fish ]]; then
        setup_fish
    fi

    if [[ "$packages" =~ zsh ]]; then
        setup_zsh
    fi

    if [[ "$packages" =~ starship ]]; then
        setup_starship
    fi

    # FZF Git integration (if fzf is available)
    setup_fzf_git
}

log_verbose "Shell setup module loaded"
