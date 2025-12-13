# fzf-lua oldfiles/recent picker - open in nvim
# Supports multi-select (Tab/Shift-Tab in picker)

function _fzf_lua_oldfiles_edit --description "Recent files picker - open in nvim"
    set -l result (_fzf_lua_cli oldfiles $argv)
    if test -n "$result"
        # Handle multiple files (one per line from multi-select)
        set -l files (string split \n -- $result)
        if test (count $files) -gt 0
            nvim $files
        end
    end
    commandline -f repaint
end
