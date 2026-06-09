# Centralized PATH Management for Fish Shell
# Managed path entries live in ~/.config/shell/paths.list so Bash, Zsh, and
# Fish resolve the same script-facing commands.

# PERF: Use Fish's builtin build info instead of spawning uname.
set -l _os Linux
if status buildinfo | string match -qi "*darwin*"
    set _os Darwin
end

# Build PATH in memory, then update fish_user_paths once only if needed.
# Repeated `fish_add_path --move` calls rewrite universal vars and trigger
# __fish_reconstruct_path each time, which shows up on every new shell.
set -l managed_paths

set -l managed_paths_file "$DOTFILES_HOME/.config/shell/paths.list"
if not test -f "$managed_paths_file"
    set managed_paths_file "$HOME/.config/shell/paths.list"
end
if test -f "$managed_paths_file"
    for entry in (string split \n -- (string collect <$managed_paths_file))
        set entry (string trim -- $entry)
        if test -z "$entry"; or string match -q '#*' -- $entry
            continue
        end

        set -l expanded $entry
        set expanded (string replace -a '$HOME' "$HOME" -- $expanded)
        set expanded (string replace -a '${HOME}' "$HOME" -- $expanded)
        set expanded (string replace -a '$DOTFILES_HOME' (set -q DOTFILES_HOME; and echo $DOTFILES_HOME; or echo "$HOME/dotfiles") -- $expanded)
        set expanded (string replace -a '${DOTFILES_HOME}' (set -q DOTFILES_HOME; and echo $DOTFILES_HOME; or echo "$HOME/dotfiles") -- $expanded)
        if set -q KREW_ROOT
            set expanded (string replace -a '${KREW_ROOT:-$HOME/.krew}' "$KREW_ROOT" -- $expanded)
        else
            set expanded (string replace -a '${KREW_ROOT:-$HOME/.krew}' "$HOME/.krew" -- $expanded)
        end
        set -a managed_paths $expanded
    end
else
    # Fallback for pre-stow/bootstrap shells.
    set -a managed_paths $HOME/dotfiles/scripts/bin /opt/homebrew/bin $HOME/bin $HOME/.local/bin /usr/bin /usr/local/bin
end

if test "$_os" = Darwin
    set -x PYTHONPATH /opt/homebrew/lib/python3.11/site-packages
else
    # Linux Python path - use glob with fallback to avoid errors when no match
    for pypath in $HOME/.local/lib/python3.*/site-packages
        set -a managed_paths $pypath
    end
    set -x PYTHONPATH /usr/lib/python3/dist-packages
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
