function ssh-switch --description "Switch between SSH keys for GitHub"
    set -l key $argv[1]
    
    if test -z "$key"
        echo "Usage: ssh-switch <key>"
        echo "Available keys:"
        echo "  personal - Use shaheislam-github key"
        echo "  dfe      - Use shaheislamdfe key"
        echo "  petlab   - Add bitbucket SSH key for PetLab"
        echo ""
        echo "Current active key:"
        ssh -T git@github.com 2>&1 | grep "Hi"
        return 1
    end

    switch $key
        case personal
            # Update SSH config to use personal key as default
            sed -i '' 's|IdentityFile ~/.ssh/shaheislamdfe|IdentityFile ~/.ssh/shaheislam-github|' ~/.ssh/config
            echo "Switched to personal SSH key (shaheislam)"
            ssh -T git@github.com 2>&1 | grep "Hi"
            
        case dfe
            # Update SSH config to use DFE key as default
            sed -i '' 's|IdentityFile ~/.ssh/shaheislam-github|IdentityFile ~/.ssh/shaheislamdfe|' ~/.ssh/config
            echo "Switched to DFE SSH key (shaheislamdfe)"
            ssh -T git@github.com 2>&1 | grep "Hi"
            
        case petlab
            # Add bitbucket SSH key for PetLab
            ssh-add ~/.ssh/bitbucket
            echo "Added bitbucket SSH key for PetLab"
            ssh -T git@bitbucket.org 2>&1 | grep -E "(logged in as|You can use git)"
            
        case \*
            echo "Unknown key: $key"
            echo "Use 'personal', 'dfe', or 'petlab'"
            return 1
    end
end