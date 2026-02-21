function _cd_zoxide_tab_complete -d "Zoxide-powered cd tab completion"
    set -l token (commandline --current-token)

    # Defer to fifc for: paths with /, dot-prefixed, flags (- or --)
    if string match -q '*/*' -- "$token"
        or string match -q '.*' -- "$token"
        or string match -q -- '-*' "$token"
        _fifc
        return
    end

    set -l query (string trim -- "$token")

    # Fallback to fifc if zoxide is unavailable
    set -l zoxide_list (zoxide query --list 2>/dev/null)
    if test $status -ne 0; or test -z "$zoxide_list"
        _fifc
        return
    end

    # Query zoxide (frecency-ranked), display full paths so fzf preview works
    set -l result (printf '%s\n' $zoxide_list \
        | fzf \
            --no-multi \
            --no-sort \
            --select-1 \
            --exit-0 \
            --scheme=path \
            --prompt='cd ❯ ' \
            --header='zoxide (frecency)' \
            --preview='eza --icons --color=always --group-directories-first -la {} 2>/dev/null || ls -la {}' \
            --query="$query")

    if test -n "$result"
        # Replace $HOME with ~ for a cleaner command line
        commandline --replace --current-token -- (string replace "$HOME" '~' -- "$result")
    end
    commandline --function repaint
end
