function git-context-aware --description "Git wrapper that handles multiple GitHub accounts"
    # Get the current directory
    set -l current_dir (pwd)
    
    # Check if this is a work/DFE project
    if string match -q "*/work/*" $current_dir; or string match -q "*DFE-Digital*" (git remote get-url origin 2>/dev/null)
        # For DFE repos, we need the DFE key first
        # Note: This would require swapping the key order in agent.toml
        # For now, just notify the user
        set -l remote_url (git remote get-url origin 2>/dev/null)
        if string match -q "*DFE-Digital*" $remote_url
            echo "📘 DFE Repository detected"
        end
    else if string match -q "*shaheislam/*" (git remote get-url origin 2>/dev/null)
        echo "🏠 Personal Repository detected"
    end
    
    # Execute the git command
    command git $argv
end

# Optional: Create an alias to use this wrapper
# alias git=git-context-aware