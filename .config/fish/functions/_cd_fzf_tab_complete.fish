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

    # Path-based token: resolve base directory and start in Path scope
    # Triggers on tokens containing '/' or starting with '.' (e.g., ../, ./, ../foo, /usr/)
    set -l path_base ""
    if string match -q -r '(/|^\.)' "$token"
        set -l expanded (string replace -r '^~' "$HOME" -- "$token")

        if test -d "$expanded"
            # Full token is a directory — browse its contents
            set path_base "$token"
            string match -q '*/' "$path_base"; or set path_base "$path_base/"
            set query ""
        else
            # Split into directory base + trailing query fragment
            set -l base (string replace -r '[^/]*$' '' -- "$token")
            set -l base_expanded (string replace -r '^~' "$HOME" -- "$base")
            if test -d "$base_expanded"
                set path_base "$base"
                set query (string replace -r '.*/' '' -- "$token")
            end
        end

        if test -n "$path_base"
            set scope Path
        end
    end

    while true
        set -l dirs
        set -l preview_cmd

        switch $scope
            case Path
                set -l expanded_base (string replace -r '^~' "$HOME" -- "$path_base")
                set -l resolved (realpath "$expanded_base" 2>/dev/null)
                if test -z "$resolved"; or not test -d "$resolved"
                    _fifc
                    return
                end
                # List real filesystem directories (non-hidden + hidden)
                for d in $resolved/*/
                    test -d "$d"; and set -a dirs (basename "$d")
                end
                for d in $resolved/.*/
                    set -l name (basename "$d")
                    test "$name" != "." -a "$name" != ".." -a -d "$d"; and set -a dirs "$name"
                end
                set preview_cmd 'eza --icons --color=always --group-directories-first -la "'$resolved'/{}" 2>/dev/null || ls -la "'$resolved'/{}"'
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

        # Build header — include Path shortcut only when a path base was resolved
        set -l header "alt-l:Local  alt-g:Git  alt-s:Global  alt-p:Parents"
        set -l expect "alt-l,alt-g,alt-s,alt-p"
        if test -n "$path_base"
            set header "alt-d:Path  $header"
            set expect "alt-d,$expect"
        end

        set -l result (printf '%s\n' $dirs \
            | fzf \
                --no-multi \
                --no-sort \
                --exit-0 \
                --scheme=path \
                --print-query \
                --prompt="cd ($scope) ❯ " \
                --header="$header" \
                --expect="$expect" \
                --preview="$preview_cmd" \
                --preview-window=right:40%:wrap \
                --query="$query")

        set -l lines (string split \n -- $result)
        set -l typed_query $lines[1]
        set -l key $lines[2]
        set -l selection $lines[3]

        # Scope change — preserve query and re-run
        switch "$key"
            case alt-d
                if test -n "$path_base"
                    set scope Path
                    set query "$typed_query"
                    continue
                end
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
                case Path
                    # Preserve the original relative path prefix (e.g., ../, ../../)
                    set selection "$path_base$selection"
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
            # Path scope keeps relative notation; others use ~ shorthand
            if test "$scope" = Path
                commandline --replace --current-token -- "$selection"
            else
                commandline --replace --current-token -- (string replace "$HOME" '~' -- "$selection")
            end
        end
        break
    end
    commandline --function repaint
end
