function psg --description "Search processes with grep and fzf"
    if test -z "$argv[1]"
        echo "Usage: psg <search_term>"
        echo "Example: psg chrome"
        return 1
    end

    set -l matches (procs --color=disable | grep -i "$argv[1]" 2>/dev/null)

    if test -z "$matches"
        echo "No processes matching '$argv[1]' found"
        return 1
    end

    # Add header from procs
    set -l header (procs --color=disable | head -n 1)
    set -l selected (printf '%s\n%s\n' "$header" "$matches" | fzf \
        --prompt="Processes matching '$argv[1]' (ENTER=details, CTRL-K=kill): " \
        --height=80% \
        --border \
        --header-lines=1 \
        --bind='ctrl-k:execute-silent(kill -9 {1})' \
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
