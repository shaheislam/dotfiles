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

    # Batch install all plugins in a single Fisher invocation (one Fish process instead of 9)
    print_step "Installing Fish plugins..."
    fish -c "fisher install ${plugins[*]}" 2>/dev/null || true

    print_success "Fish shell configured with ${#plugins[@]} plugins"
}

set_fish_as_login_shell() {
    if ! command_exists fish; then
        log_verbose "Fish not installed, skipping login shell configuration"
        return 0
    fi

    local fish_path
    fish_path=$(command -v fish)

    local current_shell="${SHELL:-}"
    if command_exists dscl; then
        current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
    elif command_exists getent; then
        current_shell=$(getent passwd "$(whoami)" | cut -d: -f7)
    fi

    if [[ "$current_shell" == "$fish_path" ]]; then
        log_verbose "Fish is already the login shell"
        return 0
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_warning "DRY RUN: Would set login shell to $fish_path"
        return 0
    fi

    if [[ -f /etc/shells ]] && ! grep -qxF "$fish_path" /etc/shells; then
        if [[ "${NO_SUDO:-false}" == "true" ]]; then
            print_warning "$fish_path is not listed in /etc/shells; login shell change skipped in --no-sudo mode"
            print_warning "Set your terminal startup command to '$fish_path' or ask an admin to add it to /etc/shells"
        else
            print_warning "$fish_path is not listed in /etc/shells; add it before running chsh"
        fi
        return 0
    fi

    print_step "Setting Fish as the login shell..."
    if chsh -s "$fish_path" </dev/null 2>/dev/null; then
        print_success "Login shell set to Fish"
    else
        print_warning "Could not change login shell non-interactively. Run: chsh -s $fish_path"
    fi
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

    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # Install Powerlevel10k theme
    if [[ ! -d "$zsh_custom/themes/powerlevel10k" ]]; then
        print_step "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k" </dev/null 2>/dev/null || true
    else
        log_verbose "Powerlevel10k already installed"
    fi

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
        "zsh-syntax-highlighting:zsh-users/zsh-syntax-highlighting"
    )

    # Clone missing plugins in parallel
    local zsh_pids=()
    for plugin_def in "${plugins[@]}"; do
        local plugin_name="${plugin_def%%:*}"
        local plugin_repo="${plugin_def##*:}"

        if [[ ! -d "$zsh_custom/plugins/$plugin_name" ]]; then
            log_verbose "Installing $plugin_name..."
            git clone "https://github.com/$plugin_repo.git" "$zsh_custom/plugins/$plugin_name" </dev/null 2>/dev/null &
            zsh_pids+=($!)
        else
            log_verbose "$plugin_name already installed"
        fi
    done
    for pid in "${zsh_pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    print_success "Zsh shell configured with Powerlevel10k and ${#plugins[@]} plugins"
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
        echo 'eval "$(starship init bash)"' >>"$bashrc"
    fi

    if [[ -f "$zshrc" ]] && ! grep -q "starship init" "$zshrc"; then
        echo 'eval "$(starship init zsh)"' >>"$zshrc"
    fi

    if [[ -f "$fish_config" ]] && ! grep -q "starship init" "$fish_config"; then
        echo 'starship init fish | source' >>"$fish_config"
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
        git clone https://github.com/junegunn/fzf-git.sh.git "$fzf_git_dir" </dev/null 2>/dev/null
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

    local packages
    packages=$(get_package_list_from_profile "$profile" "shells")

    if [[ "$packages" =~ fish ]]; then
        setup_fish
        set_fish_as_login_shell
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
