function logsf --description "View logs with fzf and lnav"
    set -l log_files (find /var/log $HOME/logs . -name "*.log" -type f 2>/dev/null | head -50)

    if test -z "$log_files"
        echo "No log files found"
        return 1
    end

    set -l selected (printf '%s\n' $log_files | fzf \
        --prompt="Select log file to view: " \
        --height=60% \
        --border \
        --preview='tail -50 {}' \
        --preview-window=right:80%:wrap)

    if test -n "$selected"
        if test -x /opt/homebrew/bin/lnav
            lnav $selected
        else
            less +F $selected
        end
    end
end
