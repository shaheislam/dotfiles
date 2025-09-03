function git-smart --description "Smart git wrapper that checks Git configuration before operations"
    # Check if this is a push operation
    if test "$argv[1]" = "push"
        # Get the remote URL
        set -l remote_url (git config --get remote.origin.url 2>/dev/null)
        
        if test -n "$remote_url"
            # Get current Git configuration
            set -l git_user (git config user.name)
            set -l git_email (git config user.email)
            
            # Check for configuration mismatches
            set -l mismatch 0
            
            if string match -q "*shaheislam/*" $remote_url
                if test "$git_email" != "shaheislam@hotmail.co.uk"
                    echo "⚠️  Git Configuration Notice!"
                    echo "   Repository: Personal (shaheislam)"
                    echo "   Current email: $git_email"
                    echo ""
                    echo "   Recommended:"
                    echo "   git config user.email 'shaheislam@hotmail.co.uk'"
                    echo ""
                    set mismatch 1
                end
                
            else if string match -q "*DFE-Digital/*" $remote_url; or string match -q "*dfe-*" $remote_url
                if test "$git_email" != "shahe.islam@education.gov.uk"
                    echo "⚠️  Git Configuration Notice!"
                    echo "   Repository: DFE"
                    echo "   Current email: $git_email"
                    echo ""
                    echo "   Recommended:"
                    echo "   git config user.email 'shahe.islam@education.gov.uk'"
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