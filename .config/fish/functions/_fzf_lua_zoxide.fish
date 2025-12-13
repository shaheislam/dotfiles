# fzf-lua zoxide picker - cd to selected directory

function _fzf_lua_zoxide --description "Zoxide picker - cd to selected directory"
    set -l result (_fzf_lua_cli zoxide)
    if test -n "$result"
        __zoxide_cd "$result"
    end
    commandline -f repaint
end
