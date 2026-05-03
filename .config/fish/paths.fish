# Centralized PATH Management for Fish Shell
# This file contains all PATH configurations for the Fish shell

# PERF: Use Fish's builtin build info instead of spawning uname.
set -l _os Linux
if status buildinfo | string match -qi "*darwin*"
    set _os Darwin
end

# Build PATH in memory, then update fish_user_paths once only if needed.
# Repeated `fish_add_path --move` calls rewrite universal vars and trigger
# __fish_reconstruct_path each time, which shows up on every new shell.
set -l managed_paths

# Keep wrappers first so repo-owned shims win over package-manager installs.
set -a managed_paths $HOME/dotfiles/scripts/bin

# Homebrew must stay before /usr/bin so Homebrew git is used on macOS.
if test "$_os" = Darwin
    set -a managed_paths /opt/homebrew/bin
end

# Preserve the current command-resolution order for user and system bins.
set -a managed_paths \
    $HOME/bin \
    $HOME/.local/bin \
    /usr/bin

# Agent/dev workflow paths, ordered to match the previous resolved PATH.
set -a managed_paths \
    $HOME/.iximiuz/labctl/bin \
    $HOME/.nix-profile/bin \
    /nix/var/nix/profiles/default/bin \
    $HOME/.local/share/mise/shims \
    $HOME/.bun/bin \
    $HOME/.cargo/bin

if test "$_os" = Darwin
    set -a managed_paths \
        /usr/local/bin \
        $HOME/Library/Python/3.9/bin
    set -x PYTHONPATH /opt/homebrew/lib/python3.11/site-packages
else
    set -a managed_paths /usr/local/bin
    # Linux Python path - use glob with fallback to avoid errors when no match
    for pypath in $HOME/.local/lib/python3.*/site-packages
        set -a managed_paths $pypath
    end
    set -x PYTHONPATH /usr/lib/python3/dist-packages
end

set -a managed_paths \
    $HOME/.rd/bin \
    $HOME/.local/share/sonarqube-cli/bin \
    $HOME/dotfiles/scripts

if set -q KREW_ROOT
    set -a managed_paths $KREW_ROOT/.krew/bin
else
    set -a managed_paths $HOME/.krew/bin
end

set -a managed_paths $HOME/work/terraform-provision

if test -d /opt/homebrew/opt/openjdk/bin
    set -a managed_paths /opt/homebrew/opt/openjdk/bin
end

if test -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    set -a managed_paths "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
end

set -l next_fish_user_paths
set -l seen_paths

for p in $managed_paths
    set -l resolved (builtin realpath -s -- $p 2>/dev/null)
    if test -z "$resolved"; or not test -d "$resolved"; or contains -- $resolved $seen_paths
        continue
    end
    set -a next_fish_user_paths $resolved
    set -a seen_paths $resolved
end

# Preserve any user-specific paths not managed above, while dropping stale paths,
# container leaks, and duplicates.
for p in $fish_user_paths
    if string match -q '/home/node/*' $p
        continue
    end
    set -l resolved (builtin realpath -s -- $p 2>/dev/null)
    if test -z "$resolved"; or not test -d "$resolved"; or contains -- $resolved $seen_paths
        continue
    end
    set -a next_fish_user_paths $resolved
    set -a seen_paths $resolved
end

set -l current_paths (string join \n -- $fish_user_paths)
set -l desired_paths (string join \n -- $next_fish_user_paths)
if test "$current_paths" != "$desired_paths"
    set -U fish_user_paths $next_fish_user_paths
end

function __dotfiles_clean_path_entries --description "Remove stale and duplicate active PATH entries"
    # Clean inherited PATH entries after fish_user_paths is settled. Terminal
    # launchers/Zsh can pass through stale dirs (asdf, cryptex, old global envs)
    # that slow command lookup even though they are not in fish_user_paths.
    set -l cleaned_path
    set -l seen_path_entries
    for p in $PATH
        if test -z "$p"; or string match -q '/home/node/*' $p
            continue
        end

        set -l resolved (builtin realpath -s -- $p 2>/dev/null)
        if test -z "$resolved"; or not test -d "$resolved"; or contains -- $resolved $seen_path_entries
            continue
        end

        set -a cleaned_path $resolved
        set -a seen_path_entries $resolved
    end

    set -l current_path_entries (string join \n -- $PATH)
    set -l desired_path_entries (string join \n -- $cleaned_path)
    if test "$current_path_entries" != "$desired_path_entries"
        set -gx PATH $cleaned_path
    end
end

__dotfiles_clean_path_entries
