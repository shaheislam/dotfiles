function nvimjson --description "Open JSON in Neovim with syntax highlighting and folding"
    if not isatty stdin
        # Piped input
        nvim -c 'set ft=json | normal zR' -
    else if test (count $argv) -gt 0
        # File argument
        nvim -c 'set ft=json' $argv[1]
    else
        # Clipboard
        nvim -c 'set ft=json | normal "+pggdd'
    end
end
