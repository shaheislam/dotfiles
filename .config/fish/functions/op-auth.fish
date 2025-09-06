function op-auth --description "Authenticate with 1Password CLI"
    # Check if op is installed
    if not command -v op >/dev/null
        echo "Error: 1Password CLI (op) is not installed"
        echo "Install with: brew install 1password-cli"
        return 1
    end

    # Check if already authenticated
    if op account get >/dev/null 2>&1
        echo "✓ Already authenticated with 1Password"
        return 0
    end

    # Sign in to 1Password
    echo "Signing in to 1Password..."
    eval (op signin)
    
    if test $status -eq 0
        echo "✓ Successfully authenticated with 1Password"
    else
        echo "✗ Failed to authenticate with 1Password"
        return 1
    end
end