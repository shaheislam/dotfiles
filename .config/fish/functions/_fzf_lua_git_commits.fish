# fzf-lua git_commits picker - output SHA for piping
# Enter = output SHA, Ctrl-y = copy SHA to clipboard

function _fzf_lua_git_commits --description "Git commits picker - output SHA"
    set -l result (_fzf_lua_cli git_commits $argv)
    if test -n "$result"
        echo $result  # Output SHA for piping
    end
    commandline -f repaint
end
