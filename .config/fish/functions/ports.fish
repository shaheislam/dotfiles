function ports --description "Show all listening ports with fzf filtering"
    set -l port_info (sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | tail -n +2)

    if test -z "$port_info"
        echo "No listening ports found"
        return 1
    end

    printf '%s\n' $port_info | fzf \
        --prompt="Filter listening ports (ESC to exit): " \
        --height=80% \
        --border \
        --header="ENTER: view details | ctrl-/: toggle preview | ESC: exit
COMMAND | PID | USER | FD | TYPE | DEVICE | SIZE/OFF | NODE | NAME" \
        --preview='echo {} | awk "{print \"Process: \" \$1 \"\\nPID: \" \$2 \"\\nUser: \" \$3 \"\\nPort: \" \$9}"' \
        --preview-window=right:40%:wrap
end
