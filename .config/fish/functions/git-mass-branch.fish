function git-mass-branch -d "Mass git branch operations across all repos in ~/work"
    # Path to the bash script
    set -l script_path "$HOME/dotfiles/scripts/git-mass-branch.sh"

    # Check if script exists
    if not test -f "$script_path"
        echo "Error: Script not found at $script_path" >&2
        return 1
    end

    # Check if script is executable
    if not test -x "$script_path"
        echo "Error: Script is not executable. Run: chmod +x $script_path" >&2
        return 1
    end

    # Pass all arguments to the bash script
    $script_path $argv
end
