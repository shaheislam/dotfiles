function portmon --description "Interactive port monitor with fzf"
    while true
        set -l selected (sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | fzf \
            --prompt="Port Monitor (ENTER=details, CTRL-K=kill process, CTRL-R=refresh, ESC=exit): " \
            --height=100% \
            --border \
            --header-lines=1 \
            --header="ctrl-k: kill process | ctrl-r: refresh | ctrl-/: toggle preview | ENTER: details | ESC: exit" \
            --bind='ctrl-k:execute(kill -9 {2})+reload(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
            --bind='ctrl-r:reload(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null)' \
            --preview='echo "Process: {1}\nPID: {2}\nUser: {3}\nPort: {9}"' \
            --preview-window=down:4:wrap)

        if test -z "$selected"
            break
        end

        set -l pid (echo $selected | awk '{print $2}')
        echo "Details for PID $pid:"
        sudo lsof -p $pid
        read -P "Press Enter to continue..."
    end
end
