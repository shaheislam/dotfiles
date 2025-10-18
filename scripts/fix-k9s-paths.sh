#!/usr/bin/env bash
# Fix hardcoded paths in k9s plugins.yaml for the current system

set -e

K9S_CONFIG="$HOME/dotfiles/.config/k9s/plugins.yaml"

if [[ ! -f "$K9S_CONFIG" ]]; then
    echo "K9s plugins.yaml not found at $K9S_CONFIG"
    exit 1
fi

echo "Updating K9s plugin paths for user: $USER"

# Backup original
cp "$K9S_CONFIG" "$K9S_CONFIG.bak"

# Update the paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|/Users/[^/]*/dotfiles|$HOME/dotfiles|g" "$K9S_CONFIG"
else
    # Linux
    sed -i "s|/Users/[^/]*/dotfiles|$HOME/dotfiles|g" "$K9S_CONFIG"
    sed -i "s|/home/[^/]*/dotfiles|$HOME/dotfiles|g" "$K9S_CONFIG"
fi

echo "K9s plugin paths updated successfully!"
echo "Backup saved to $K9S_CONFIG.bak"