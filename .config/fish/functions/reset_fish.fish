function reset_fish --description "Reset Fish shell to clean state"
    # Clear command line
    commandline -r ""
    commandline -f repaint

    # Clear any clipboard issues (cross-platform)
    echo -n "" | clipboard_copy

    # Reset key bindings for vi mode
    if test "$fish_key_bindings" = "fish_vi_key_bindings"
        # Clear ALL bindings for down arrow first
        bind -M insert -e \e\[B 2>/dev/null
        bind -M default -e \e\[B 2>/dev/null
        bind -M visual -e \e\[B 2>/dev/null

        # Re-add correct bindings
        bind -M insert \e\[B down-or-search
        bind -M insert \e\[A up-or-search

        bind -M default \e\[B down-line
        bind -M default \e\[A up-line
    end

    # Clear history search
    commandline -f history-search-backward
    commandline -f history-search-forward
    commandline -r ""

    echo "Fish shell reset. Arrow keys should work now."
end