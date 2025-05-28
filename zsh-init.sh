#!/bin/zsh
# VS Code/Cursor terminal initialization script

# Ensure HOME is set correctly
export HOME="/Users/shahes"

# Clear any ZDOTDIR that might be set
unset ZDOTDIR

# Set correct history file location
export HISTFILE="$HOME/.zsh_history"

# Source the .zshrc file
if [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc"
fi

# Start an interactive shell
exec /bin/zsh "$@"
