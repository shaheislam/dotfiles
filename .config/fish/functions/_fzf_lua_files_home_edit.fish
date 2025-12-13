# fzf-lua files picker from home directory - open in nvim

function _fzf_lua_files_home_edit --description "Files picker from home - open in nvim"
    set -l result (_fzf_lua_cli files cwd=$HOME)
    if test -n "$result"
        nvim "$result"
    end
    commandline -f repaint
end
