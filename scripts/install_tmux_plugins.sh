#!/bin/bash

# Create plugins directory if it doesn't exist
mkdir -p ~/.tmux/plugins

# Install TPM if not already installed
if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# Install plugins
~/.tmux/plugins/tpm/bin/install_plugins

# Source tmux config
tmux source-file ~/.tmux.conf
