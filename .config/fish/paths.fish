# Centralized PATH Management for Fish Shell
# This file contains all PATH configurations for the Fish shell

# PERF: Cache uname result to avoid two subprocess calls (~5ms each).
# fish_add_path deduplicates, so repeated entries are harmless but wasteful.
set -l _os (uname -s)

# OS-specific core paths
# PERF: --move ensures Homebrew comes before /usr/bin (from /etc/paths).
# Without this, macOS system git (2.39.5, ~1.2s git status) is used
# instead of Homebrew git (2.49+, ~45ms git status).
if test "$_os" = Darwin
    fish_add_path --move /opt/homebrew/bin # Homebrew on Apple Silicon — MUST be before /usr/bin
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

# Clean leaked container paths from fish_user_paths (devcontainer sessions
# can persist /home/node/* paths into universal variables)
if set -q fish_user_paths
    set -l cleaned
    for p in $fish_user_paths
        if not string match -q '/home/node/*' $p
            set -a cleaned $p
        end
    end
    if test (count $cleaned) -ne (count $fish_user_paths)
        set -U fish_user_paths $cleaned
    end
end
