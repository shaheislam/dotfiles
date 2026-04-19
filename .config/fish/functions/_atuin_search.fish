function _atuin_search --argument-names filter_mode --description "Atuin search with configurable filter"
    set -l keymap_mode
    switch $fish_key_bindings
        case fish_vi_key_bindings
            switch $fish_bind_mode
                case default
                    set keymap_mode vim-normal
                case insert
                    set keymap_mode vim-insert
            end
        case '*'
            set keymap_mode emacs
    end

    set -l ATUIN_H (ATUIN_SHELL_FISH=t ATUIN_LOG=error ATUIN_QUERY=(commandline -b) atuin search --keymap-mode=$keymap_mode --filter-mode=$filter_mode -i 3>&1 1>&2 2>&3 | string collect)

    if test -n "$ATUIN_H"
        if string match --quiet '__atuin_accept__:*' "$ATUIN_H"
            set -l ATUIN_HIST (string replace "__atuin_accept__:" "" -- "$ATUIN_H" | string collect)
            # Sanitize UTF-8 to prevent Rust panics on invalid bytes
            set -l sanitized (printf '%s' "$ATUIN_HIST" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)
            commandline -r "$sanitized"
            commandline -f repaint
            commandline -f execute
            return
        else
            commandline -r (printf '%s' "$ATUIN_H" | iconv -f UTF-8 -t UTF-8//IGNORE 2>/dev/null)
        end
    end

    commandline -f repaint
end
