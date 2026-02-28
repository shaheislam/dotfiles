function _cd_fzf_tab_complete -d "Zoxide fzf cd picker with scope switching (parity with fzf-lua zoxide)"
    set -l token (commandline --current-token)

    # Defer to fifc for flags (cd -, cd --)
    if string match -q -- '-*' "$token"
        _fifc
        return
    end

    # Path-based completion for filesystem navigation
    # Triggers when token contains '/' or starts with '.' (e.g., ../, ./, ../foo, /usr/, .config)
    # These indicate filesystem paths rather than zoxide fuzzy queries
    if string match -q -r '(/|^\.)' "$token"
        set -l base_dir "$token"
        set -l path_query ""

        # Expand ~ for path resolution
        set -l expanded (string replace -r '^~' "$HOME" -- "$token")

        if test -d "$expanded"
            # Full token is a directory — browse its contents
            set base_dir "$token"
            string match -q '*/' "$base_dir"; or set base_dir "$base_dir/"
        else
            # Split into directory base + trailing query fragment
            set base_dir (string replace -r '[^/]*$' '' -- "$token")
            set path_query (string replace -r '.*/' '' -- "$token")
            set expanded (string replace -r '^~' "$HOME" -- "$base_dir")
            if not test -d "$expanded"
                _fifc
                return
            end
        end

        set -l expanded_base (string replace -r '^~' "$HOME" -- "$base_dir")
        set -l resolved (realpath "$expanded_base" 2>/dev/null)
        if test -z "$resolved"; or not test -d "$resolved"
            _fifc
            return
        end

        # Collect subdirectories (including hidden)
        set -l dir_list
        for d in $resolved/*/
            test -d "$d"; and set -a dir_list (basename "$d")
        end
        for d in $resolved/.*/
            set -l name (basename "$d")
            test "$name" != "." -a "$name" != ".." -a -d "$d"; and set -a dir_list "$name"
        end

        if test (count $dir_list) -eq 0
            _fifc
            return
        end

        set -l result (printf '%s\n' $dir_list \
            | fzf \
                --no-multi \
                --no-sort \
                --scheme=path \
                --print-query \
                --prompt="cd ($base_dir) ❯ " \
                --preview='eza --icons --color=always --group-directories-first -la "'$resolved'/{}" 2>/dev/null || ls -la "'$resolved'/{}"' \
                --preview-window=right:40%:wrap \
                --query="$path_query")

        set -l lines (string split \n -- $result)
        set -l selection $lines[3]

        if test -n "$selection"
            commandline --replace --current-token -- "$base_dir$selection"
        end
        commandline --function repaint
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
