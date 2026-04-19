function gisdel --description "Delete GitHub gists with fzf selection"
    set -l gists (gh gist list --limit 100 2>/dev/null)

    if test -z "$gists"
        echo "No gists found"
        return 1
    end

    set -l selected (printf '%s\n' $gists | fzf --multi --prompt="Select gists to delete (TAB for multiple): " --height=40% --border)

    if test -n "$selected"
        for gist in $selected
            set -l gist_id (string split ' ' -- $gist)[1]
            read -P "Delete gist $gist_id? (y/N): " confirm
            if test "$confirm" = y
                gh gist delete $gist_id
                echo "Deleted gist: $gist_id"
            end
        end
    end
end
