function gisls --description "List and manage GitHub gists with fzf"
    set -l gists (gh gist list --limit 100 2>/dev/null)

    if test -z "$gists"
        echo "No gists found"
        return 1
    end

    set -l selected (printf '%s\n' $gists | fzf --prompt="Select gist (ENTER=view, CTRL-E=edit, CTRL-D=delete): " \
        --height=40% --border \
        --header="ENTER=view | CTRL-E=edit | CTRL-D=delete" \
        --bind='ctrl-e:execute(echo edit {})+abort' \
        --bind='ctrl-d:execute(echo delete {})+abort')

    if test -n "$selected"
        set -l gist_id (string split ' ' -- $selected)[1]

        # Check if user wants to edit or delete
        if string match -q "edit *" "$selected"
            set gist_id (string split ' ' -- $selected)[2]
            echo "Editing gist: $gist_id"
            gh gist edit $gist_id
        else if string match -q "delete *" "$selected"
            set gist_id (string split ' ' -- $selected)[2]
            read -P "Delete gist $gist_id? (y/N): " confirm
            if test "$confirm" = y
                gh gist delete $gist_id
                echo "Deleted gist: $gist_id"
            end
        else
            # Default action: view the gist
            gh gist view $gist_id
        end
    end
end
