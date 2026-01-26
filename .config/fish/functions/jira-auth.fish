function jira-auth --description "Authenticate Jira CLI with 1Password"
    # Check if 1Password CLI is available
    if not command -q op
        echo "1Password CLI (op) not installed"
        return 1
    end

    # Check if signed in to 1Password
    if not op account list &>/dev/null
        echo "Not signed in to 1Password. Run: eval (op signin)"
        return 1
    end

    # Get token from 1Password (--reveal required for sensitive fields)
    set -l token (op item get "Jira API Token" --fields password --reveal 2>/dev/null)
    if test -z "$token"
        # Try alternative field names
        set token (op item get "Jira API Token" --fields credential --reveal 2>/dev/null)
    end

    if test -z "$token"
        echo "Failed to get Jira API token from 1Password"
        echo "Ensure you have an item named 'Jira API Token' with a 'credential' or 'password' field"
        return 1
    end

    # Authenticate with acli
    echo $token | acli jira auth login \
        --site "petlab.atlassian.net" \
        --email "shahe.islam@thepetlabco.com" \
        --token

    # Check status
    if acli jira auth status 2>/dev/null | grep -q "Logged in"
        echo "Successfully authenticated with Jira"
    else
        echo "Authentication may have failed - check 'acli jira auth status'"
        return 1
    end
end
