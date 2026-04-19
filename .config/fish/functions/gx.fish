function gx --description "Interactively delete git branches with fzf"
    set -l branches (git branch --list | grep -v "^[ *]*main\$" | sed 's/^[* ]*//')

    if test -z "$branches"
        echo "No branches to delete (main is protected)"
        return 1
    end

    set -l selected (printf '%s\n' $branches | fzf --multi --prompt="Select branches to delete (TAB to select multiple): " --height=40% --border)

    if test -n "$selected"
        for branch in $selected
            echo "Deleting branch: $branch"
            git branch -d $branch
        end
    else
        echo "No branches selected"
    end
end
