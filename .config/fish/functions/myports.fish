function myports --description "Monitor your own ports (no sudo required)"
    while true
        set -l selected (lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | fzf \
            --prompt="Your Ports (ENTER=details, CTRL-K=kill, CTRL-R=refresh, ESC=exit): " \
            --height=100% \
            --border \
            --header-lines=1 \
            --bind='ctrl-k:execute(kill -9 {2})+reload(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
            --bind='ctrl-r:reload(lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
            --preview='echo "Process: {1}\nPID: {2}\nUser: {3}\nPort: {9}"' \
            --preview-window=down:4:wrap)

        if test -z "$selected"
            break
        end

        set -l pid (echo $selected | awk '{print $2}')
        echo "Details for PID $pid:"
        lsof -p $pid
        read -P "Press Enter to continue..."
    end
end
