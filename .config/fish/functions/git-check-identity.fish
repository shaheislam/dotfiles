function git-check-identity --description "Check which SSH key should be used for current repository"
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

    # Check current GitHub identity
    echo ""
    echo "Current GitHub identity:"
    ssh -T git@github.com 2>&1 | grep "Hi" || echo "  Not authenticated"

    # Determine which key should be used based on the repository
    if string match -q "*shaheislam/*" $remote_url
        echo ""
        echo "✓ This is a personal repository (shaheislam)"
        echo "  You should use: ssh-switch personal"

        # Check if current identity matches
        if ssh -T git@github.com 2>&1 | grep -q "Hi shaheislam!"
            echo "  ✓ Correct SSH key is active"
        else
            echo "  ⚠ Wrong SSH key is active!"
            echo ""
            echo "Run: ssh-switch personal"
        end

    else if string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url
        echo ""
        echo "✓ This is a DFE repository"
        echo "  You should use: ssh-switch dfe"

        # Check if current identity matches
        if ssh -T git@github.com 2>&1 | grep -q "Hi shaheislamdfe!"
            echo "  ✓ Correct SSH key is active"
        else
            echo "  ⚠ Wrong SSH key is active!"
            echo ""
            echo "Run: ssh-switch dfe"
        end

    else if string match -q "*bitbucket.org*" $remote_url
        echo ""
        echo "✓ This is a Bitbucket repository"
        echo "  You should use: ssh-switch petlab"

    else
        echo ""
        echo "⚠ Unknown repository owner"
        echo "  Remote: $remote_url"
    end

    # Show current SSH keys
    echo ""
    echo "Current SSH agent keys:"
    ssh-add -l | sed 's/^/  /'
end

# Create an alias for convenience
abbr -a gci git-check-identity
