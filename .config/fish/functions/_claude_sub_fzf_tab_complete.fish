function _claude_sub_fzf_tab_complete -d "FZF-powered --sub tab completion for subscription profile selection"
    set -l token (commandline --current-token)

    # Build profile entries: name<TAB>info
    set -l entries

    # Default profile (~/.claude/)
    set -l default_info (_claude_sub_get_info "$HOME/.claude")
    set -a entries (printf '%s\t%s' "default" "$default_info")

    # Named profiles (~/.claude-*/)
    for dir in $HOME/.claude-*/
        if not test -d "$dir"
            continue
        end
        set -l dir_name (basename "$dir")
        set -l name (string replace '.claude-' '' "$dir_name")
        set -l info (_claude_sub_get_info "$dir")
        set -a entries (printf '%s\t%s' "$name" "$info")
    end

    if test (count $entries) -eq 0
        commandline --function repaint
        return
    end

    set -l result (printf '%s\n' $entries \
        | fzf \
            --exit-0 \
            --no-multi \
            -d '\t' \
            --with-nth=1.. \
            --prompt='sub ❯ ' \
            --header='name / org | plan | email' \
            --query="$token" \
        | cut -f1)

    if test -n "$result"
        commandline --replace --current-token -- "$result"
        commandline --insert ' '
    end
    commandline --function repaint
end
