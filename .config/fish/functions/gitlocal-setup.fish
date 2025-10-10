function gitlocal-setup --description "Setup local git excludes for repositories"
    # Get the path to the script
    set -l script_path ~/dotfiles/scripts/tools/setup-git-local-excludes.sh

    # Check if script exists
    if not test -f $script_path
        echo "Error: setup-git-local-excludes.sh not found at $script_path"
        return 1
    end

    # Run the script with all passed arguments
    bash $script_path $argv
end

# Add completions for the function
complete -c gitlocal-setup -f -a "(ls -d ~/*/)" -d "Directory to process"
complete -c gitlocal-setup -l dry-run -d "Show what would be done without making changes"
complete -c gitlocal-setup -l add-pattern -x -d "Add custom pattern to all exclude files"
complete -c gitlocal-setup -l verbose -s v -d "Show detailed output"
complete -c gitlocal-setup -l help -s h -d "Show help message"