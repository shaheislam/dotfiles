function fix_terminal --description "Fix terminal issues including arrow keys and paste"
    # Disable bracketed paste if it's causing issues
    printf "\e[?2004l"

    # Clear any stray characters
    commandline -f repaint

    # Fix arrow key bindings for vi mode
    if test "$fish_key_bindings" = "fish_vi_key_bindings"
        # Vi insert mode
        bind -M insert -e \e\[B  # Erase any existing binding first
        bind -M insert \e\[B down-or-search
        bind -M insert \e\[A up-or-search
        bind -M insert \e\[C forward-char
        bind -M insert \e\[D backward-char

        # Vi default/normal mode
        bind -M default -e \e\[B  # Erase any existing binding first
        bind -M default \e\[B down-line
        bind -M default \e\[A up-line
        bind -M default \e\[C forward-char
        bind -M default \e\[D backward-char
    else
        # Default emacs mode
        bind -e \e\[B  # Erase any existing binding first
        bind \e\[B down-or-search
        bind \e\[A up-or-search
        bind \e\[C forward-char
        bind \e\[D backward-char
    end

    echo "Terminal fixed. Try arrow keys now."
end