function psf --description "Interactive process search with fzf"
    set -l processes (procs --color=disable)

    if test -z "$processes"
        echo "No processes found"
        return 1
    end

    set -l selected (printf '%s\n' $processes | fzf \
        --prompt="Process Search (ENTER=details, CTRL-K=kill, CTRL-R=refresh): " \
        --height=80% \
        --border \
        --header-lines=1 \
        --header="ENTER: view details | ctrl-k: kill | ctrl-r: refresh | ctrl-/: toggle preview" \
        --bind='ctrl-k:execute-silent(kill -9 {1})+reload(procs --color=disable)' \
        --bind='ctrl-r:reload(procs --color=disable)' \
        --preview='procs {1} --tree' \
        --preview-window=right:50%:wrap)

    if test -n "$selected"
        set -l pid (echo $selected | awk '{print $1}')
        if test "$pid" != PID # Skip header if selected
            echo "Details for PID $pid:"
            procs $pid --tree
        end
    end
end
