# Centralized PATH Management for Fish Shell
# This file contains all PATH configurations for the Fish shell

# PERF: Cache uname result to avoid two subprocess calls (~5ms each).
# fish_add_path deduplicates, so repeated entries are harmless but wasteful.
set -l _os (uname -s)

# OS-specific core paths
if test "$_os" = Darwin
    # macOS Homebrew paths
    fish_add_path /opt/homebrew/bin # Homebrew on Apple Silicon
    fish_add_path /usr/local/bin # Traditional Unix local binaries
else
    # Linux paths
    fish_add_path /usr/local/bin
    fish_add_path /usr/bin
end

# Universal user paths (both OS)
fish_add_path $HOME/bin # User binaries
fish_add_path $HOME/.local/bin # User local binaries

# Development tools (universal)
fish_add_path $HOME/.cargo/bin # Rust/Cargo binaries
fish_add_path $HOME/.bun/bin # Bun JavaScript runtime
fish_add_path $HOME/.rd/bin # Rancher Desktop

# Python (OS-aware)
if test "$_os" = Darwin
    fish_add_path $HOME/Library/Python/3.9/bin # macOS Python user packages
    set -x PYTHONPATH /opt/homebrew/lib/python3.12/site-packages
else
    # Linux Python path - use glob with fallback to avoid errors when no match
    for pypath in $HOME/.local/lib/python3.*/site-packages
        test -d "$pypath" && fish_add_path "$pypath"
    end
    set -x PYTHONPATH /usr/lib/python3/dist-packages
end

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
