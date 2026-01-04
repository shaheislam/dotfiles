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

echo "Shell config setup complete!"
