# fzf-lua files picker - open in nvim

function _fzf_lua_files_edit --description "Files picker - open in nvim"
    set -l result (_fzf_lua_cli files $argv)
    if test -n "$result"
        nvim "$result"
    end
    commandline -f repaint
end
