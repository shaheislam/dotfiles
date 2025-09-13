#!/bin/bash

# Create plugins directory if it doesn't exist
mkdir -p ~/.tmux/plugins

# List of plugins to install
plugins=(
    "tmux-plugins/tpm"
    "tmux-plugins/tmux-sensible"
    "tmux-plugins/tmux-resurrect"
    "tmux-plugins/tmux-continuum"
    "tmux-plugins/tmux-yank"
    "tmux-plugins/tmux-prefix-highlight"
    "alexwforsythe/tmux-which-key"
    "tmux-plugins/tmux-open"
    "tmux-plugins/tmux-copycat"
    "tmux-plugins/tmux-pain-control"
    "tmux-plugins/tmux-sidebar"
    "Morantron/tmux-fingers"
    "tmux-plugins/tmux-battery"
)

# Install each plugin
for plugin in "${plugins[@]}"; do
    plugin_name=$(basename "$plugin")
    echo "Installing $plugin..."
    if [ ! -d ~/.tmux/plugins/$plugin_name ]; then
        git clone "https://github.com/$plugin" ~/.tmux/plugins/$plugin_name
    else
        echo "$plugin_name already exists, updating..."
        cd ~/.tmux/plugins/$plugin_name
        git pull
    fi
done

# Source tmux config
tmux source-file ~/.tmux.conf

echo "Plugin installation complete!"
