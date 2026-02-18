function topmon --description "Interactive top-like monitor with btop/htop selection"
    set -l monitors "btop (Beautiful Resource Monitor)" "htop (Interactive Process Viewer)" "procs (Modern Process Viewer)"
    set -l selected (printf '%s\n' $monitors | fzf --prompt="Select monitor: " --height=30% --border)

    if test -n "$selected"
        switch $selected
            case "*btop*"
                btop
            case "*htop*"
                htop
            case "*procs*"
                procs --watch --watch-interval 1
        end
    end
end
