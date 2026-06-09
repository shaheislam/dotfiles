function db --description "Manage per-project database sandboxes"
    set -l sandbox "$HOME/dotfiles/scripts/db-sandbox.sh"
    if not test -x "$sandbox"
        echo "Error: db-sandbox.sh not found or not executable at $sandbox" >&2
        return 1
    end

    bash "$sandbox" $argv
end
