# fzf-lua zoxide picker - cd to selected directory
# Supports scope switching (Alt-L/S/G) with path filtering
#
# Scopes:
#   Local  - directories under current working directory
#   Git    - directories under git repository root
#   Global - all directories in zoxide database

function _fzf_lua_zoxide --description "Zoxide picker - cd to selected directory"
    set -l scope "Local"
    set -l filter_path (pwd)

    while true
        # Build zoxide command with path filtering
        set -l zoxide_cmd "zoxide query --list --score"
        if test "$scope" != "Global"
            # Filter to only show dirs under filter_path using grep
            set zoxide_cmd "$zoxide_cmd | grep -F '$filter_path'"
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

        # Normal selection - cd to directory
        __zoxide_cd "$result"
        break
    end
    commandline -f repaint
end
