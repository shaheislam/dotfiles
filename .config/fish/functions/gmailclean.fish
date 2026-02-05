function gmailclean --description "Gmail inbox cleanup tool"
    set -l script_dir ~/dotfiles/scripts/gmailclean

    if not test -d "$script_dir/.venv"
        echo "Setting up gmailclean..."
        bash "$script_dir/setup.sh"
    end

    "$script_dir/.venv/bin/python3" "$script_dir/gmailclean.py" $argv
end
