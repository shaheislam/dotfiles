function git-check-identity --description "Check Git user configuration for current repository"
    # Get the current directory
    set -l current_dir (pwd)

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    # Get the remote URL
    set -l remote_url (git config --get remote.origin.url 2>/dev/null)

    if test -z "$remote_url"
        echo "No origin remote configured"
        return 1
    end

    echo "Repository: $remote_url"

    # Check current Git user configuration
    echo ""
    echo "Current Git configuration:"
    set -l git_user (git config user.name)
    set -l git_email (git config user.email)
    echo "  User: $git_user"
    echo "  Email: $git_email"
    
    # Check current GitHub identity via 1Password SSH
    echo ""
    echo "GitHub authentication (via 1Password SSH):"
    ssh -T git@github.com 2>&1 | grep "Hi" || echo "  Not authenticated"

    # Determine recommended configuration based on repository
    if string match -q "*shaheislam/*" $remote_url
        echo ""
        echo "✓ This is a personal repository (shaheislam)"
        echo "  Recommended Git config:"
        echo "    git config user.name 'Shahe Islam'"
        echo "    git config user.email 'shaheislam@hotmail.co.uk'"

    else if string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url
        echo ""
        echo "✓ This is a DFE repository"
        echo "  Recommended Git config:"
        echo "    git config user.name 'Shahe Islam'"
        echo "    git config user.email 'shahe.islam@education.gov.uk'"

    else if string match -q "*bitbucket.org*" $remote_url
        echo ""
        echo "✓ This is a Bitbucket repository"
        echo "  Using 1Password SSH for authentication"

    else
        echo ""
        echo "⚠ Unknown repository owner"
        echo "  Remote: $remote_url"
    end

    # Show 1Password SSH agent status
    echo ""
    echo "1Password SSH Agent:"
    if test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        echo "  ✓ Socket is available"
        SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ssh-add -l 2>/dev/null | head -1 | sed 's/^/  /' || echo "  No identities available"
    else
        echo "  ⚠ Socket not found - check 1Password SSH agent settings"
    end
end

# Create an alias for convenience
abbr -a gci git-check-identity
