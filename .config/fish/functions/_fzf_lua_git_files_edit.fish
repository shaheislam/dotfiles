# fzf-lua git_files picker - open in nvim
# Supports multi-select (Tab/Shift-Tab in picker)

function _fzf_lua_git_files_edit --description "Git files picker - open in nvim"
    set -l result (_fzf_lua_cli git_files $argv)
    if test -n "$result"
        # Handle multiple files (one per line from multi-select)
        set -l files (string split \n -- $result)
        if test (count $files) -gt 0
            nvim $files
        end
    end
    commandline -f repaint
end
