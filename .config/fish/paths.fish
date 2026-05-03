# Centralized PATH Management for Fish Shell
# This file contains all PATH configurations for the Fish shell

# PERF: Use Fish's builtin build info instead of spawning uname.
set -l _os Linux
if status buildinfo | string match -qi "*darwin*"
    set _os Darwin
end

# OS-specific core paths
# Keep user-managed bins ahead of package-manager bins so native installers
# (for example Claude Code in ~/.local/bin) win over legacy Homebrew/npm shims.
fish_add_path --move $HOME/.local/bin # User local binaries
fish_add_path --move $HOME/bin # User binaries

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

# Development tools (universal)
fish_add_path $HOME/.cargo/bin # Rust/Cargo binaries
fish_add_path $HOME/.bun/bin # Bun JavaScript runtime
fish_add_path $HOME/.rd/bin # Rancher Desktop
fish_add_path $HOME/.local/share/sonarqube-cli/bin # SonarQube CLI

# Python (OS-aware)
if test "$_os" = Darwin
    fish_add_path $HOME/Library/Python/3.9/bin # macOS Python user packages
    set -x PYTHONPATH /opt/homebrew/lib/python3.11/site-packages
else
    # Linux Python path - use glob with fallback to avoid errors when no match
    for pypath in $HOME/.local/lib/python3.*/site-packages
        test -d "$pypath" && fish_add_path "$pypath"
    end
    set -x PYTHONPATH /usr/lib/python3/dist-packages
end

# Dotfiles scripts
fish_add_path --move $HOME/dotfiles/scripts/bin

# Application-specific paths (conditional)
# Add VSCode bin to PATH if it exists
if test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
end

# Clean stale paths from fish_user_paths: non-existent dirs, container leaks, duplicates.
# Reduces PATH size → faster command -q scans on every command lookup.
if set -q fish_user_paths
    set -l cleaned
    set -l seen
    for p in $fish_user_paths
        # Skip container paths leaked from devcontainer sessions
        if string match -q '/home/node/*' $p
            continue
        end
        # Skip non-existent directories
        if not test -d "$p"
            continue
        end
        # Skip duplicates
        if contains -- $p $seen
            continue
        end
        set -a cleaned $p
        set -a seen $p
    end
    if test (count $cleaned) -ne (count $fish_user_paths)
        set -U fish_user_paths $cleaned
    end
end
