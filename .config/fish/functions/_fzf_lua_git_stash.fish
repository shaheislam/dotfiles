# fzf-lua git_stash picker - apply or drop stashes
# Enter = apply stash, Ctrl-x = drop stash, Ctrl-y = copy stash ref

function _fzf_lua_git_stash --description "Git stash picker - apply/drop stash"
    set -l result (_fzf_lua_cli git_stash $argv)
    if test -n "$result"
        if string match -q "__stash_apply__:*" -- $result
            set -l ref (string replace "__stash_apply__:" "" -- $result)
            if test -n "$ref"
                git stash apply $ref
            end
        else if string match -q "__stash_drop__:*" -- $result
            set -l ref (string replace "__stash_drop__:" "" -- $result)
            if test -n "$ref"
                git stash drop $ref
            end
        end
    end
    commandline -f repaint
end
