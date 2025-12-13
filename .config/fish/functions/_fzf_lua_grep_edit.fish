# fzf-lua live_grep picker - open result in nvim

function _fzf_lua_grep_edit --description "Live grep - open result in nvim"
    set -l result (_fzf_lua_cli live_grep $argv)
    if test -n "$result"
        nvim "$result"
    end
    commandline -f repaint
end
