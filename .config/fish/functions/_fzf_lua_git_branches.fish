# fzf-lua git_branches picker - checkout selected branch
# Enter = checkout branch, Ctrl-y = copy branch name

function _fzf_lua_git_branches --description "Git branches picker - checkout selected"
    set -l result (_fzf_lua_cli git_branches $argv)
    if test -n "$result"
        # Check for checkout command prefix from fzf-lua action
        if string match -q "__checkout__:*" -- $result
            set -l branch (string replace "__checkout__:" "" -- $result)
            if test -n "$branch"
                git checkout $branch
            end
        end
    end
    commandline -f repaint
end
