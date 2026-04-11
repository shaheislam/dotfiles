function weekly-synth --description 'Generate Obsidian weekly synthesis from Claude session files'
    set -l script "$HOME/dotfiles/scripts/obsidian/weekly-synthesis.sh"

    if not test -x "$script"
        echo "Error: weekly-synthesis.sh not found or not executable at $script" >&2
        return 1
    end

    bash "$script" $argv
end
