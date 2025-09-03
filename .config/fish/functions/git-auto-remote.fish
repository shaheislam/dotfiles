function git-auto-remote --description "Automatically set git remote URL based on repository owner"
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end
    
    # Get the current remote URL
    set -l remote_url (git config --get remote.origin.url 2>/dev/null)
    
    if test -z "$remote_url"
        echo "No origin remote configured"
        return 1
    end
    
    # Check if it's a DFE repository
    if string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url
        # Extract repo path
        set -l repo_path (echo $remote_url | sed -E 's/.*[:\/]([^\/]+\/[^\/]+)(\.git)?$/\1/')
        
        # Set to use github.com (standard) for DFE repos
        # DFE key should be second in 1Password config
        git remote set-url origin git@github.com:$repo_path.git
        echo "✓ Set remote to standard GitHub for DFE repo: $repo_path"
        
    else if string match -q "*shaheislam/*" $remote_url
        # Extract repo path  
        set -l repo_path (echo $remote_url | sed -E 's/.*[:\/]([^\/]+\/[^\/]+)(\.git)?$/\1/')
        
        # Set to use github.com (standard) for personal repos
        # Personal key should be first in 1Password config
        git remote set-url origin git@github.com:$repo_path.git
        echo "✓ Set remote to standard GitHub for personal repo: $repo_path"
    end
    
    # Show current remote
    echo "Current remote: "(git config --get remote.origin.url)
end

# Create an alias for convenience
abbr -a gar git-auto-remote