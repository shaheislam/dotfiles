# Centralized PATH Management for Fish Shell
# This file contains all PATH configurations for the Fish shell

# OS-specific core paths
if test (uname -s) = "Darwin"
    # macOS Homebrew paths
    fish_add_path /opt/homebrew/bin          # Homebrew on Apple Silicon
    fish_add_path /usr/local/bin             # Traditional Unix local binaries
else
    # Linux paths
    fish_add_path /usr/local/bin
    fish_add_path /usr/bin
end

# Universal user paths (both OS)
fish_add_path $HOME/bin                  # User binaries
fish_add_path $HOME/.local/bin           # User local binaries

# Development tools (universal)
fish_add_path $HOME/.cargo/bin           # Rust/Cargo binaries
fish_add_path $HOME/.bun/bin             # Bun JavaScript runtime
fish_add_path $HOME/.rd/bin              # Rancher Desktop

# Python (OS-aware)
if test (uname -s) = "Darwin"
    fish_add_path $HOME/Library/Python/3.9/bin  # macOS Python user packages
    set -x PYTHONPATH /opt/homebrew/lib/python3.12/site-packages
else
    fish_add_path $HOME/.local/lib/python3.*/site-packages
    set -x PYTHONPATH /usr/lib/python3/dist-packages
end

# Claude Code
fish_add_path -p $HOME/.claude/local     # Claude local installation (prioritized)
fish_add_path $HOME/.claude/local/bin    # Claude local binaries

# Dotfiles scripts
fish_add_path $HOME/dotfiles/scripts/bin

# Application-specific paths (conditional)
# Add VSCode bin to PATH if it exists
if test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
end

# Add Cursor bin to PATH if it exists
if test -d "/Applications/Cursor.app/Contents/Resources/app/bin"
    fish_add_path "/Applications/Cursor.app/Contents/Resources/app/bin"
end
