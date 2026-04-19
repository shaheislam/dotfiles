function gstash --description "Manage git stashes with fzf"
    set -l stashes (git stash list 2>/dev/null)

    if test -z "$stashes"
        echo "No stashes found"
        return 1
    end

    set -l selected (printf '%s\n' $stashes | fzf --prompt="Select stash (ENTER=apply, CTRL-P=pop, CTRL-D=drop): " \
        --height=40% --border \
        --header="ENTER=apply | CTRL-P=pop | CTRL-D=drop" \
        --bind='ctrl-p:execute(echo pop {})+abort' \
        --bind='ctrl-d:execute(echo drop {})+abort')

    if test -n "$selected"
        set -l stash_id (echo $selected | command cut -d: -f1)

        if string match -q "pop *" "$selected"
            set stash_id (string split ':' -- (string split ' ' -- $selected)[2])[1]
            echo "Popping stash: $stash_id"
            git stash pop $stash_id
        else if string match -q "drop *" "$selected"
            set stash_id (string split ':' -- (string split ' ' -- $selected)[2])[1]
            read -P "Drop stash $stash_id? (y/N): " confirm
            if test "$confirm" = y
                git stash drop $stash_id
                echo "Dropped stash: $stash_id"
            end
        else
            # Default action: apply stash
            echo "Applying stash: $stash_id"
            git stash apply $stash_id
        end
    end
end
