function aws-sso --description "Authenticate with AWS SSO with fzf profile selection"
    set -l profile $argv[1]

    if test -z "$profile"
        # Use fzf to select profile
        set -l profiles (aws configure list-profiles 2>/dev/null)
        if test -z "$profiles"
            echo "No AWS profiles configured"
            return 1
        end

        set profile (printf '%s\n' $profiles | fzf --prompt="Select AWS SSO profile: " --height=40% --border)
        test -z "$profile"; and return 0
    end

    echo "Logging in to AWS SSO profile: $profile"
    aws sso login --profile "$profile"
    eval (aws configure export-credentials --profile "$profile" --format env)
    set -gx AWS_DEFAULT_PROFILE "$profile"
    set -gx AWS_PROFILE "$profile"

    if aws sts get-caller-identity >/dev/null 2>&1
        echo "Successfully authenticated as:"
        aws sts get-caller-identity --output table
    else
        echo "Failed to get credentials"
        return 1
    end
end
