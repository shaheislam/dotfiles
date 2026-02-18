function killp --description "Kill process with fzf selection"
    set -l processes (procs --color=disable | tail -n +2)

    if test -z "$processes"
        echo "No processes found"
        return 1
    end

    set -l selected (printf '%s\n' $processes | fzf --multi \
        --prompt="Select process to kill (TAB for multiple): " \
        --height=80% \
        --border \
        --header="TAB: select | ENTER: confirm | ESC: cancel | ctrl-a: select all
PID | User | CPU% | MEM% | Command" \
        --preview='echo {}' \
        --preview-window=down:3:wrap)

    if test -n "$selected"
        for proc in $selected
            set -l pid (echo $proc | awk '{print $1}')
            set -l cmd (echo $proc | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^    //')
            if test -n "$pid"
                echo "Killing PID $pid: $cmd"
                kill -9 $pid
            end
        end
    end
end
