function obsidian-concepts --description "Generate or update Obsidian Concept/MOC pages from Claude sessions"
    # Usage:
    #   obsidian-concepts                     # regenerate all concepts (min 3 refs)
    #   obsidian-concepts --dry-run           # preview without writing
    #   obsidian-concepts --min-refs 5        # stricter threshold
    #   obsidian-concepts --limit 20          # more sessions per page
    #   obsidian-concepts --entities "fish,tmux,neovim"  # specific entities only

    set -l dotfiles_root ~/dotfiles
    set -l script "$dotfiles_root/scripts/obsidian/generate-concept-pages.py"

    if not test -f $script
        echo "Error: $script not found" >&2
        echo "Run: stow . from ~/dotfiles, or check dotfiles path" >&2
        return 1
    end

    python3 $script $argv
end
