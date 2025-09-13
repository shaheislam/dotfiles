#!/usr/bin/env bash
# Link global .envrc to current directory

DOTFILES_DIR="$HOME/dotfiles"
GLOBAL_ENVRC="$DOTFILES_DIR/.envrc.global"

if [ ! -f "$GLOBAL_ENVRC" ]; then
    echo "Error: Global .envrc not found at $GLOBAL_ENVRC"
    exit 1
fi

# Create symlink in current directory
ln -sf "$GLOBAL_ENVRC" .envrc
echo "✓ Linked .envrc from dotfiles"

# Auto-allow it
direnv allow
echo "✓ Allowed direnv for this directory"

echo ""
echo "You can create .envrc.local for project-specific overrides"