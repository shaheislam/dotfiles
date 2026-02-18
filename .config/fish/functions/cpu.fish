function cpu --description "Show CPU usage by process with fzf filtering"
    procs --sortd cpu | fzf \
        --prompt="Filter processes by CPU (ESC to exit): " \
        --height=80% \
        --border \
        --header-lines=1 \
        --header="Sorted by CPU usage | ENTER: view | ctrl-/: toggle preview | ESC: exit" \
        --preview='echo {} | awk "{print \"PID: \" \$1 \"\\nCPU: \" \$3 \"\\nMemory: \" \$4 \"\\nCommand: \"}" && echo {} | command cut -d" " -f5-' \
        --preview-window=right:40%:wrap
end
