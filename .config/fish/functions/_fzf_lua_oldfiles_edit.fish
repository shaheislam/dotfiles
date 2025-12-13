# fzf-lua oldfiles/recent picker - open in nvim

function _fzf_lua_oldfiles_edit --description "Recent files picker - open in nvim"
    set -l result (_fzf_lua_cli oldfiles $argv)
    if test -n "$result"
        nvim "$result"
    end
    commandline -f repaint
end
