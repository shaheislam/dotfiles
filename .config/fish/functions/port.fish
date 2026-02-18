function port --description "Show what's listening on a given port (with fzf if no port specified)"
    if test -z "$argv[1]"
        # No port specified, use fzf to select from all listening ports
        set -l all_ports (sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | tail -n +2 | awk '{print $9}' | command cut -d: -f2 | sort -nu)

        if test -z "$all_ports"
            echo "No listening ports found"
            return 1
        end

        set -l selected_port (printf '%s\n' $all_ports | fzf --prompt="Select port to inspect: " --height=40% --border)

        if test -n "$selected_port"
            echo "Port $selected_port:"
            sudo lsof -iTCP:$selected_port -sTCP:LISTEN
        end
    else
        sudo lsof -iTCP:$argv[1] -sTCP:LISTEN
    end
end
