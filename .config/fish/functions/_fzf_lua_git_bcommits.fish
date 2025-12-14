# fzf-lua git_bcommits picker - show commits for a specific file
# Enter = output SHA, Ctrl-y = copy SHA to clipboard

function _fzf_lua_git_bcommits --description "Git buffer commits picker - file history"
    # Requires file path argument
    if test (count $argv) -eq 0
        echo "Usage: _fzf_lua_git_bcommits <file>"
        return 1
    end
    set -l result (_fzf_lua_cli git_bcommits file=$argv[1])
    if test -n "$result"
        echo $result  # Output SHA for piping
    end
    commandline -f repaint
end
