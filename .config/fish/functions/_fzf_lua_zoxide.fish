# fzf-lua zoxide picker - cd to selected directory
# Supports scope switching (Alt-L/S/G) with path filtering
#
# Scopes:
#   Local  - directories under current working directory (prefix stripped)
#   Git    - directories under git repository root (prefix stripped)
#   Global - all directories in zoxide database (shows ~/... notation)

function _fzf_lua_zoxide --description "Zoxide picker - cd to selected directory"
    set -l scope "Local"
    set -l filter_path (pwd)

    while true
        # Build zoxide command with path filtering AND prefix stripping
        set -l zoxide_cmd "zoxide query --list --score"

        if test "$scope" = "Global"
            # Global: show all dirs, replace $HOME with ~ for cleaner display
            set zoxide_cmd "$zoxide_cmd | sed 's|$HOME|~|'"
        else
            # Local/Git: filter to scope, then strip the prefix for cleaner display
            # sed pattern: replace tab+prefix+/ with just tab (keeps score, strips prefix)
            set zoxide_cmd "$zoxide_cmd | grep -F '$filter_path' | sed 's|\t$filter_path/|\t|'"
        end

        set -l result (_fzf_lua_cli zoxide cmd="$zoxide_cmd" prompt="Zoxide ($scope)❯ ")

        if test -z "$result"
            break
        end

        # Check for scope change command: __zoxide_scope__:SCOPE
        if string match -q "__zoxide_scope__:*" -- $result
            set -l new_scope (string replace "__zoxide_scope__:" "" -- $result)

            switch $new_scope
                case "local"
                    set filter_path (pwd)
                    set scope "Local"
                case "git"
                    set filter_path (git rev-parse --show-toplevel 2>/dev/null; or pwd)
                    set scope "Git"
                case "global"
                    set filter_path ""
                    set scope "Global"
            end
            continue
        end

        # CRITICAL: Restore full path before cd
        # The displayed path was stripped, so we need to restore it
        switch $scope
            case "Local"
                set result (pwd)"/"$result
            case "Git"
                set result $filter_path"/"$result
            case "Global"
                # Replace ~ back to $HOME for the actual cd
                set result (string replace "~" $HOME -- $result)
        end

        __zoxide_cd "$result"
        break
    end
    commandline -f repaint
end
