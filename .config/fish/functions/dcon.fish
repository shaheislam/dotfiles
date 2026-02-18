function dcon --description "[DEPRECATED] Select Docker container with fzf"
    if not test -x /opt/homebrew/bin/docker
        echo "Docker not installed"
        return 1
    end

    set -l containers (docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" | tail -n +2)
    if test -z "$containers"
        echo "No running containers found"
        return 1
    end

    set -l selected (printf '%s\n' $containers | fzf \
        --prompt="Container: " \
        --height=80% \
        --border \
        --multi \
        --bind 'tab:toggle+down,shift-tab:toggle+up' \
        --header="TAB: select multiple | CTRL-E=exec, CTRL-S=stop, CTRL-R=restart" \
        --bind='ctrl-e:execute(docker exec -it {1} /bin/sh)' \
        --bind='ctrl-s:execute(docker stop {1})' \
        --bind='ctrl-r:execute(docker restart {1})' \
        --preview='docker logs --tail 50 {1}')

    if test -n "$selected"
        for line in $selected
            set -l container_id (echo $line | awk '{print $1}')
            echo "=== Container: $container_id ==="
            docker logs --tail 100 $container_id
            echo ""
        end
    end
end
