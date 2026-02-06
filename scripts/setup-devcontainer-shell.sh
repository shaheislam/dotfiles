#!/usr/bin/env bash
# setup-devcontainer-shell.sh
# Minimal shell config setup for devcontainers
# Only symlinks fish and starship configs from dotfiles repo

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/dotfiles}"

echo "Setting up shell configs from ${DOTFILES_DIR}..."

# Determine actual .config location (might be symlinked by setup-nvim-env.sh)
if [[ -L "${HOME}/.config" ]]; then
    CONFIG_DIR=$(readlink -f "${HOME}/.config")
    echo "  .config is symlinked to ${CONFIG_DIR}"
else
    CONFIG_DIR="${HOME}/.config"
    mkdir -p "${CONFIG_DIR}"
fi

# Symlink fish config directory
if [[ -d "${DOTFILES_DIR}/.config/fish" ]]; then
    rm -rf "${CONFIG_DIR}/fish"
    ln -sf "${DOTFILES_DIR}/.config/fish" "${CONFIG_DIR}/fish"
    echo "  Linked fish config -> ${DOTFILES_DIR}/.config/fish"
else
    echo "  Warning: fish config not found at ${DOTFILES_DIR}/.config/fish"
fi

# Symlink starship config
if [[ -f "${DOTFILES_DIR}/.config/starship.toml" ]]; then
    rm -f "${CONFIG_DIR}/starship.toml"
    ln -sf "${DOTFILES_DIR}/.config/starship.toml" "${CONFIG_DIR}/starship.toml"
    echo "  Linked starship.toml -> ${DOTFILES_DIR}/.config/starship.toml"
else
    echo "  Warning: starship.toml not found at ${DOTFILES_DIR}/.config/starship.toml"
fi

# Initialize atuin for shell history (Ctrl+R integration)
if command -v atuin &>/dev/null; then
    echo "Initializing atuin..."
    ATUIN_DATA_DIR="${HOME}/.local/share/atuin"
    ATUIN_CONFIG_DIR="${CONFIG_DIR}/atuin"

    mkdir -p "${ATUIN_DATA_DIR}" "${ATUIN_CONFIG_DIR}"

    # Create atuin config if it doesn't exist
    # Use local (offline) mode - no sync server needed in devcontainer
    if [[ ! -f "${ATUIN_CONFIG_DIR}/config.toml" ]]; then
        cat > "${ATUIN_CONFIG_DIR}/config.toml" <<'ATUIN_EOF'
## Atuin config for devcontainer (offline mode)
# No sync - history stays local to this container
sync_address = ""
auto_sync = false

# Search settings
search_mode = "fuzzy"
filter_mode = "directory"
filter_mode_shell_up_key_binding = "directory"
style = "compact"

# History settings
history_filter = [
  "^ls$",
  "^cd ",
  "^pwd$",
  "^clear$",
  "^exit$",
]
ATUIN_EOF
        echo "  Created atuin config at ${ATUIN_CONFIG_DIR}/config.toml"
    else
        echo "  Atuin config already exists"
    fi

    echo "  Atuin initialized (offline mode)"
else
    echo "  Warning: atuin not found, Ctrl+R history search will use fzf fallback"
fi

# Set fish as default shell for the user if not already
if command -v fish &>/dev/null; then
    FISH_PATH=$(command -v fish)
    CURRENT_SHELL=$(getent passwd "$(whoami)" | cut -d: -f7)
    if [[ "${CURRENT_SHELL}" != "${FISH_PATH}" ]]; then
        # Add fish to /etc/shells if not present (requires sudo)
        if ! grep -q "${FISH_PATH}" /etc/shells 2>/dev/null; then
            echo "${FISH_PATH}" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
        fi
        sudo chsh -s "${FISH_PATH}" "$(whoami)" 2>/dev/null || true
        echo "  Set default shell to fish"
    fi
fi

echo "Shell config setup complete!"
