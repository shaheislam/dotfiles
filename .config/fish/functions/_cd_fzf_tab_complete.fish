function _cd_fzf_tab_complete -d "Zoxide fzf cd picker with scope switching (parity with fzf-lua zoxide)"
    set -l token (commandline --current-token)

    # Defer to fifc for flags (cd -, cd --)
    if string match -q -- '-*' "$token"
        _fifc
        return
    end

    set -l scope Global
    set -l query (string trim -- "$token")
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null; or echo "")

    while true
        set -l dirs
        set -l preview_cmd

        switch $scope
            case Global
                set dirs (zoxide query --list 2>/dev/null | sed "s|$HOME|~|")
                set preview_cmd 'd={}; d="${d/#\~/'$HOME'}"; eza --icons --color=always --group-directories-first -la "$d" 2>/dev/null || ls -la "$d"'
            case Local
                set dirs (zoxide query --list 2>/dev/null | string match -r "^"(string escape --style=regex -- (pwd))"/.*" | sed "s|"(pwd)"/||")
                set preview_cmd 'eza --icons --color=always --group-directories-first -la "'(pwd)'/{}" 2>/dev/null || ls -la "'(pwd)'/{}"'
            case Git
                set -l root (test -n "$git_root"; and echo "$git_root"; or pwd)
                set dirs (zoxide query --list 2>/dev/null | string match -r "^"(string escape --style=regex -- "$root")"/.*" | sed "s|$root/||")
                set preview_cmd 'eza --icons --color=always --group-directories-first -la "'$root'/{}" 2>/dev/null || ls -la "'$root'/{}"'
            case Parents
                set -l current (pwd)
                while test "$current" != /
                    set -a dirs $current
                    set current (dirname $current)
                end
                set -a dirs /
                set preview_cmd 'eza --icons --color=always --group-directories-first -la {} 2>/dev/null || ls -la {}'
        end

        if test -z "$dirs"
            _fifc
            return
        end

        set -l result (printf '%s\n' $dirs \
            | fzf \
                --no-multi \
                --no-sort \
                --exit-0 \
                --scheme=path \
                --print-query \
                --prompt="cd ($scope) ❯ " \
                --header="alt-l:Local  alt-g:Git  alt-s:Global  alt-p:Parents" \
                --expect=alt-l,alt-g,alt-s,alt-p \
                --preview="$preview_cmd" \
                --preview-window=right:40%:wrap \
                --query="$query")

        set -l lines (string split \n -- $result)
        set -l typed_query $lines[1]
        set -l key $lines[2]
        set -l selection $lines[3]

        # Scope change — preserve query and re-run
        switch "$key"
            case alt-l
                set scope Local
                set query "$typed_query"
                continue
            case alt-g
                set scope Git
                set query "$typed_query"
                continue
            case alt-s
                set scope Global
                set query "$typed_query"
                continue
            case alt-p
                set scope Parents
                set query "$typed_query"
                continue
        end

        # Selection made — restore full path based on scope
        if test -n "$selection"
            switch $scope
                case Local
                    set selection (pwd)"/$selection"
                case Git
                    set -l root (test -n "$git_root"; and echo "$git_root"; or pwd)
                    set selection "$root/$selection"
                case Global
                    set selection (string replace "~" "$HOME" -- "$selection")
                case Parents
                    # Already full paths
            end
            commandline --replace --current-token -- (string replace "$HOME" '~' -- "$selection")
        end
        break
    end
    commandline --function repaint
end
