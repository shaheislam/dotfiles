function procmon --description "Interactive process monitor with fzf"
    while true
        set -l selected (procs --color=disable | fzf \
            --prompt="Process Monitor (ENTER=details, CTRL-K=kill, CTRL-R=refresh, ESC=exit): " \
            --height=100% \
            --border \
            --header-lines=1 \
            --header="ctrl-k: kill | ctrl-r: refresh | ctrl-/: toggle preview | ENTER: details | ESC: exit" \
            --bind='ctrl-k:execute(kill -9 {1})+reload(procs --color=disable)' \
            --bind='ctrl-r:reload(procs --color=disable)' \
            --preview='procs {1} --tree' \
            --preview-window=right:50%:wrap)

        if test -z "$selected"
            break
        end

        set -l pid (echo $selected | awk '{print $1}')
        echo "Details for PID $pid:"
        procs $pid --tree
        read -P "Press Enter to continue..."
    end
end
