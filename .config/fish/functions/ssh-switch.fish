function ssh-switch --description "Switch between SSH keys for GitHub"
    set -l key $argv[1]

    if test -z "$key"
        echo "Usage: ssh-switch <key>"
        echo "Available keys:"
        echo "  personal - Use shaheislam-github key"
        echo "  dfe      - Use shaheislamdfe key"
        echo "  petlab   - Add bitbucket SSH key for PetLab"
        echo ""
        echo "Current active keys in SSH agent:"
        ssh-add -l 2>/dev/null || echo "  No keys loaded"
        echo ""
        echo "Current GitHub identity:"
        ssh -T git@github.com 2>&1 | grep "Hi" || echo "  Not authenticated"
        return 1
    end

    # Define key paths
    set -l personal_key ~/.ssh/shaheislam-github
    set -l dfe_key ~/.ssh/shaheislamdfe
    set -l bitbucket_key ~/.ssh/bitbucket

    switch $key
        case personal
            # Clear all keys and add only personal key
            ssh-add -D 2>/dev/null

            # Add the personal key
            if test -f $personal_key
                ssh-add $personal_key
                echo "✓ Loaded personal SSH key"
            else
                echo "✗ Personal key not found at $personal_key"
                return 1
            end

            # Update SSH config to use personal key as default
            # Handle symlinks by resolving the actual file path
            set -l config_file ~/.ssh/config
            if test -L $config_file
                set config_file (readlink $config_file)
            end

            # Update the config file
            if test -f $config_file
                sed -i '' 's|IdentityFile ~/.ssh/shaheislamdfe|IdentityFile ~/.ssh/shaheislam-github|' $config_file
                echo "✓ Updated SSH config"
            else
                echo "⚠ SSH config not found at $config_file"
            end

            echo ""
            echo "Switched to personal SSH key (shaheislam)"
            ssh -T git@github.com 2>&1 | grep "Hi"

        case dfe
            # Clear all keys and add only DFE key
            ssh-add -D 2>/dev/null

            # Add the DFE key
            if test -f $dfe_key
                ssh-add $dfe_key
                echo "✓ Loaded DFE SSH key"
            else
                echo "✗ DFE key not found at $dfe_key"
                return 1
            end

            # Update SSH config to use DFE key as default
            # Handle symlinks by resolving the actual file path
            set -l config_file ~/.ssh/config
            if test -L $config_file
                set config_file (readlink $config_file)
            end

            # Update the config file
            if test -f $config_file
                sed -i '' 's|IdentityFile ~/.ssh/shaheislam-github|IdentityFile ~/.ssh/shaheislamdfe|' $config_file
                echo "✓ Updated SSH config"
            else
                echo "⚠ SSH config not found at $config_file"
            end

            echo ""
            echo "Switched to DFE SSH key (shaheislamdfe)"
            ssh -T git@github.com 2>&1 | grep "Hi"

        case petlab
            # Don't clear keys for petlab, just add the bitbucket key
            if test -f $bitbucket_key
                ssh-add $bitbucket_key
                echo "✓ Added bitbucket SSH key for PetLab"
            else
                echo "✗ Bitbucket key not found at $bitbucket_key"
                return 1
            end

            echo ""
            ssh -T git@bitbucket.org 2>&1 | grep -E "(logged in as|You can use git)"

        case \*
            echo "Unknown key: $key"
            echo "Use 'personal', 'dfe', or 'petlab'"
            return 1
    end

    # Show current SSH agent state
    echo ""
    echo "Current SSH agent keys:"
    ssh-add -l | sed 's/^/  /'

    # Check if we're in a git repository and warn about potential mismatches
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l remote_url (git config --get remote.origin.url 2>/dev/null)
        if test -n "$remote_url"
            echo ""
            echo "Current repository: "(basename $remote_url .git)

            # Warn if there's a potential mismatch
            if string match -q "*shaheislam/*" $remote_url; and test "$key" != "personal"
                echo "⚠️  Warning: This is a personal repository but you switched to $key"
            else if begin; string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url; end; and test "$key" != "dfe"
                echo "⚠️  Warning: This is a DFE repository but you switched to $key"
            end
        end
    end
end
