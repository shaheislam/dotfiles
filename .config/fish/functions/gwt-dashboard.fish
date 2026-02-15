function gwt-dashboard --description "Agent monitoring web dashboard"
    set -l dash_script "$HOME/dotfiles/scripts/agent-dashboard.sh"
    if not test -x "$dash_script"
        set dash_script "$HOME/dotfiles-gastown/scripts/agent-dashboard.sh"
    end
    if not test -x "$dash_script"
        echo "Error: agent-dashboard.sh not found"
        return 1
    end

    bash "$dash_script" $argv
end
