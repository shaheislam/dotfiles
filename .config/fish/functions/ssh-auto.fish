function ssh-auto --description "Automatically switch to the correct SSH key based on current git repository"
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

    # Get current GitHub identity
    set -l current_identity (ssh -T git@github.com 2>&1 | grep "Hi" | sed 's/Hi \(.*\)!.*/\1/')

    echo "Repository: $remote_url"
    echo "Current identity: $current_identity"

    # Auto-switch based on repository
    if string match -q "*shaheislam/*" $remote_url
        if test "$current_identity" != "shaheislam"
            echo ""
            echo "Switching to personal SSH key..."
            ssh-switch personal
        else
            echo "✓ Already using correct SSH key (personal)"
        end

    else if string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url
        if test "$current_identity" != "shaheislamdfe"
            echo ""
            echo "Switching to DFE SSH key..."
            ssh-switch dfe
        else
            echo "✓ Already using correct SSH key (DFE)"
        end

    else if string match -q "*bitbucket.org*" $remote_url
        echo ""
        echo "Adding Bitbucket SSH key..."
        ssh-switch petlab

    else
        echo ""
        echo "⚠ Unknown repository owner, no auto-switch performed"
    end
end

# Create an alias for convenience
abbr -a ssa ssh-auto
