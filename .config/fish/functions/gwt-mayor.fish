function gwt-mayor --description "Global coordinator daemon (Mayor pattern)"
    set -l mayor_script "$HOME/dotfiles/scripts/gwt-mayor.sh"
    if not test -x "$mayor_script"
        set mayor_script "$HOME/dotfiles-gastown/scripts/gwt-mayor.sh"
    end
    if not test -x "$mayor_script"
        echo "Error: gwt-mayor.sh not found"
        return 1
    end

    bash "$mayor_script" $argv
end
