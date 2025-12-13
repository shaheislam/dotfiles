# fzf-lua git_files picker - open in nvim

function _fzf_lua_git_files_edit --description "Git files picker - open in nvim"
    set -l result (_fzf_lua_cli git_files $argv)
    if test -n "$result"
        nvim "$result"
    end
    commandline -f repaint
end
