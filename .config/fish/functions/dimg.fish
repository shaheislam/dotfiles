function dimg --description "[DEPRECATED] Select Docker image with fzf for various operations"
    set -l images (docker images --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}" | tail -n +2)

    if test -z "$images"
        echo "No Docker images found"
        return 1
    end

    set -l selected (printf '%s\n' $images | fzf --multi --prompt="Select images (TAB for multiple, ENTER=run, CTRL-D=delete): " \
        --height=40% --border \
        --header="ENTER=run | CTRL-D=delete (TAB for multiple)" \
        --bind='ctrl-d:execute(echo delete {})+abort')

    if test -n "$selected"
        if string match -q "delete *" "$selected"
            # Handle deletion
            for img in (echo $selected | tail -n +2)
                set -l image_id (string split ' ' -- $img)[1]
                read -P "Delete image $image_id? (y/N): " confirm
                if test "$confirm" = y
                    docker rmi $image_id
                    echo "Deleted image: $image_id"
                end
            end
        else
            # Default action: run container
            for img in $selected
                set -l image_name (string split ' ' -- $img)[2]
                echo "Running container from image: $image_name"
                docker run -it --rm $image_name
            end
        end
    end
end
