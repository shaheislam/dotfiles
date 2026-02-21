function _make_fzf_tab_complete -d "FZF-powered make target tab completion"
    set -l token (commandline --current-token)

    # If typing a flag or variable assignment, defer to fifc
    if string match -q -- '-*' "$token"; or string match -q '*=*' -- "$token"
        _fifc
        return
    end

    # Find the Makefile (respect -f flag if present)
    set -l makefile ""
    set -l cmd (commandline -opc)
    for i in (seq 2 (count $cmd))
        if test "$cmd[$i]" = -f; or test "$cmd[$i]" = --file
            set -l next (math $i + 1)
            if test $next -le (count $cmd)
                set makefile "$cmd[$next]"
            end
        end
    end

    if test -z "$makefile"
        if test -f GNUmakefile
            set makefile GNUmakefile
        else if test -f makefile
            set makefile makefile
        else if test -f Makefile
            set makefile Makefile
        end
    end

    if test -z "$makefile"; or not test -f "$makefile"
        _fifc
        return
    end

    # Parse targets: "target: ## description" or plain "target:"
    # Format as "target\tdescription" for fzf display
    set -l targets (grep -E '^[a-zA-Z_][a-zA-Z0-9_.-]*:' "$makefile" \
        | grep -v '^\.' \
        | sed 's/:.*##/\t/; s/:.*//' \
        | string trim)

    if test -z "$targets"
        _fifc
        return
    end

    set -l result (printf '%s\n' $targets \
        | fzf \
            --no-multi \
            --select-1 \
            --exit-0 \
            -d '\t' \
            --with-nth=1.. \
            --prompt='make ❯ ' \
            --header='Makefile targets' \
            --preview="grep -A 5 '^{1}:' $makefile | head -10" \
            --preview-window=right:40%:wrap \
            --query="$token" \
        | awk -F'\t' '{print $1}')

    if test -n "$result"
        commandline --replace --current-token -- "$result"
    end
    commandline --function repaint
end
