function assume --description "Assume AWS role using Granted"
    # Handle console flag for Firefox containers
    if test "$argv[1]" = -c
        set -l profile $argv[2]
        if test -n "$profile"
            if test "$profile" = sec
                set profile security
            end

            # First assume the profile using bash with suppressed interactive prompts
            set -l env_vars (printf 'n\n' | bash -c "source /opt/homebrew/bin/assume $profile >/dev/null 2>&1 && env | grep -E '^(AWS_|GRANTED_)'")
            if test (count $env_vars) -eq 0
                echo "Failed to assume AWS profile: $profile"
                return 1
            end

            _parse_granted_env $env_vars

            # Then open console with profile-specific container names and colors
            switch $profile
                case labs
                    granted console --firefox --color green --icon tree --container-name labs
                case logging
                    granted console --firefox --color purple --icon circle --container-name logging
                case security
                    granted console --firefox --color purple --icon fingerprint --container-name security
                case management
                    granted console --firefox --color blue --icon briefcase --container-name management
                case petlab
                    granted console --firefox --color pink --icon pet --container-name petlab
                case prod
                    granted console --firefox --color red --icon briefcase --container-name prod
                case '*'
                    granted console --firefox --container-name $profile
            end
            return
        end
    end

    # If no arguments provided, use interactive selection
    if test (count $argv) -eq 0
        # Get available profiles and use fzf for selection
        set -l profiles (aws configure list-profiles 2>/dev/null)
        if test (count $profiles) -eq 0
            echo "No AWS profiles found"
            return 1
        end

        # Use fzf for interactive selection
        set -l selected_profile (printf '%s\n' $profiles | fzf --prompt="Select AWS profile: " --height=40% --border)

        if test -n "$selected_profile"
            # Assume the selected profile
            set -l env_vars (printf 'n\n' | bash -c "source /opt/homebrew/bin/assume $selected_profile >/dev/null 2>&1 && env | grep -E '^(AWS_|GRANTED_)'")
            _parse_granted_env $env_vars
        else
            echo "No profile selected"
        end
        return
    end

    # Regular assume functionality with specific profile
    # Execute assume command in bash and capture AWS environment variables
    set -l env_vars (printf 'n\n' | bash -c "source /opt/homebrew/bin/assume $argv >/dev/null 2>&1 && env | grep -E '^(AWS_|GRANTED_)'")
    _parse_granted_env $env_vars
end
