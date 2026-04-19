function gco --description "Git checkout branch/tag with fzf"
    set -l branches (git branch -a 2>/dev/null | grep -v HEAD | sed 's/.* //' | sed 's|remotes/[^/]*/||' | sort -u)

    if test -z "$branches"
        echo "No branches found"
        return 1
    end

    set -l selected (printf '%s\n' $branches | fzf --prompt="Checkout branch: " --height=40% --border)

    if test -n "$selected"
        git checkout $selected
    end
end
