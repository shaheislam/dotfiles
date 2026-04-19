function dps --description "[DEPRECATED] Select Docker container with fzf for various operations"
    set -l containers (docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" | tail -n +2)

    if test -z "$containers"
        echo "No Docker containers found"
        return 1
    end

    set -l selected (printf '%s\n' $containers | fzf --prompt="Select container (ENTER=logs, CTRL-S=shell, CTRL-R=restart, CTRL-D=delete): " \
        --height=40% --border \
        --header="ENTER=logs | CTRL-S=shell | CTRL-R=restart | CTRL-D=delete" \
        --bind='ctrl-s:execute(echo shell {})+abort' \
        --bind='ctrl-r:execute(echo restart {})+abort' \
        --bind='ctrl-d:execute(echo delete {})+abort')

    if test -n "$selected"
        set -l container_id (string split ' ' -- $selected)[1]

        if string match -q "shell *" "$selected"
            set container_id (string split ' ' -- $selected)[2]
            echo "Opening shell in container: $container_id"
            docker exec -it $container_id sh
        else if string match -q "restart *" "$selected"
            set container_id (string split ' ' -- $selected)[2]
            echo "Restarting container: $container_id"
            docker restart $container_id
        else if string match -q "delete *" "$selected"
            set container_id (string split ' ' -- $selected)[2]
            read -P "Delete container $container_id? (y/N): " confirm
            if test "$confirm" = y
                docker rm -f $container_id
                echo "Deleted container: $container_id"
            end
        else
            # Default action: show logs
            echo "Showing logs for container: $container_id"
            docker logs -f $container_id
        end
    end
end
