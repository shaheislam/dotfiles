# fzf-lua files picker - open in nvim
# Supports multi-select (Tab/Shift-Tab) and scope switching (Alt-L/S/G)

function _fzf_lua_files_edit --description "Files picker - open in nvim"
    set -l cwd (pwd)
    set -l query ""
    set -l scope "Local"

    while true
        set -l result (_fzf_lua_cli files cwd="$cwd" query="$query" prompt="Files ($scope)❯ " $argv)

        if test -z "$result"
            break
        end

        # Check for scope change command: __scope__:SCOPE:PICKER:QUERY
        if string match -q "__scope__:*" -- $result
            set -l parts (string split ":" -- $result)
            set -l new_scope $parts[2]
            # parts[3] is picker type (files/grep)
            set query $parts[4]

            switch $new_scope
                case "local"
                    set cwd (pwd)
                    set scope "Local"
                case "git"
                    set cwd (git rev-parse --show-toplevel 2>/dev/null; or pwd)
                    set scope "Git"
                case "global"
                    set cwd $HOME
                    set scope "Global"
            end
            continue
        end

        # Normal selection - open files
        set -l files (string split \n -- $result)
        if test (count $files) -gt 0
            nvim $files
        end
        break
    end
    commandline -f repaint
end
