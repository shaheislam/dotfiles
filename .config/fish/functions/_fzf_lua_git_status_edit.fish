# fzf-lua git_status picker - open modified files in nvim
# Supports multi-select (Tab/Shift-Tab in picker)

function _fzf_lua_git_status_edit --description "Git status picker - open in nvim"
    set -l result (_fzf_lua_cli git_status $argv)
    if test -n "$result"
        # Handle multiple files (one per line from multi-select)
        set -l files (string split \n -- $result)
        if test (count $files) -gt 0
            nvim $files
        end
    end
    commandline -f repaint
end
