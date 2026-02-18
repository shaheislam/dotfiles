function mem --description "Show memory usage by process with fzf filtering"
    procs --sortd mem | fzf \
        --prompt="Filter processes by memory (ESC to exit): " \
        --height=80% \
        --border \
        --header-lines=1 \
        --header="Sorted by memory usage | ENTER: view | ctrl-/: toggle preview | ESC: exit" \
        --preview='echo {} | awk "{print \"PID: \" \$1 \"\\nMemory: \" \$4 \"\\nCPU: \" \$3 \"\\nCommand: \"}" && echo {} | command cut -d" " -f5-' \
        --preview-window=right:40%:wrap
end
