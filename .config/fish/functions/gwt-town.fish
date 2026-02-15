function gwt-town --description "Manage town-level beads (cross-project memory)"
    set -l town_script "$HOME/dotfiles/scripts/town-beads.sh"
    if not test -x "$town_script"
        set town_script "$HOME/dotfiles-gastown/scripts/town-beads.sh"
    end
    if not test -x "$town_script"
        echo "Error: town-beads.sh not found"
        return 1
    end

    bash "$town_script" $argv
end
