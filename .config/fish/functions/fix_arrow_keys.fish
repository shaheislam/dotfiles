function fix_arrow_keys --description "Fix arrow key bindings in Fish vi mode"
    # For vi insert mode - bind arrow keys to history search
    bind -M insert \e\[A up-or-search
    bind -M insert \e\[B down-or-search
    bind -M insert \e\[C forward-char
    bind -M insert \e\[D backward-char

    # Alternative sequences some terminals send
    bind -M insert \eOA up-or-search
    bind -M insert \eOB down-or-search
    bind -M insert \eOC forward-char
    bind -M insert \eOD backward-char

    # For default/normal mode in vi
    bind -M default k up-or-search
    bind -M default j down-or-search
    bind -M default h backward-char
    bind -M default l forward-char

    # Also ensure arrow keys work in default mode
    bind -M default \e\[A up-or-search
    bind -M default \e\[B down-or-search
    bind -M default \e\[C forward-char
    bind -M default \e\[D backward-char
end