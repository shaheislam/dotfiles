function git-smart --description "Smart git wrapper that checks SSH key before push/pull"
    # Check if this is a push or pull operation
    if test "$argv[1]" = "push" -o "$argv[1]" = "pull" -o "$argv[1]" = "fetch"
        # Get the remote URL
        set -l remote_url (git config --get remote.origin.url 2>/dev/null)
        
        if test -n "$remote_url"
            # Get current GitHub identity
            set -l current_identity (ssh -T git@github.com 2>&1 | grep "Hi" | sed 's/Hi \(.*\)!.*/\1/')
            
            # Check for mismatches
            set -l mismatch 0
            
            if string match -q "*shaheislam/*" $remote_url
                if test "$current_identity" != "shaheislam"
                    echo "⚠️  SSH Key Mismatch Detected!"
                    echo "   Repository: Personal (shaheislam)"
                    echo "   Current identity: $current_identity"
                    echo ""
                    echo "   Run: ssh-switch personal"
                    echo ""
                    set mismatch 1
                end
                
            else if string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url
                if test "$current_identity" != "shaheislamdfe"
                    echo "⚠️  SSH Key Mismatch Detected!"
                    echo "   Repository: DFE"
                    echo "   Current identity: $current_identity"
                    echo ""
                    echo "   Run: ssh-switch dfe"
                    echo ""
                    set mismatch 1
                end
            end
            
            if test $mismatch -eq 1
                read -P "Continue anyway? [y/N] " -n 1 response
                echo ""
                if test "$response" != "y" -a "$response" != "Y"
                    echo "Operation cancelled."
                    return 1
                end
            end
        end
    end
    
    # Execute the original git command
    command git $argv
end

# Optional: Create an alias to use git-smart by default
# alias git=git-smart