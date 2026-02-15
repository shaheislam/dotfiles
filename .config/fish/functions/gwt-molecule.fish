function gwt-molecule --description "Manage molecule workflows (durable multi-step state machine)"
    set -l molecule_script "$HOME/dotfiles/scripts/molecule.sh"
    if not test -x "$molecule_script"
        set molecule_script "$HOME/dotfiles-gastown/scripts/molecule.sh"
    end
    if not test -x "$molecule_script"
        echo "Error: molecule.sh not found"
        return 1
    end

    bash "$molecule_script" $argv
end
