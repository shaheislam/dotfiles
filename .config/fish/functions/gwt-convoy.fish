function gwt-convoy --description "Manage convoy batches (grouped ticket tracking)"
    set -l convoy_script "$HOME/dotfiles/scripts/convoy.sh"
    if not test -x "$convoy_script"
        set convoy_script "$HOME/dotfiles-gastown/scripts/convoy.sh"
    end
    if not test -x "$convoy_script"
        echo "Error: convoy.sh not found"
        return 1
    end

    bash "$convoy_script" $argv
end
