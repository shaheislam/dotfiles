function aws-whoami --description "Show current AWS account and identity"
    if test -n "$AWS_PROFILE"
        echo "Current profile: $AWS_PROFILE"
        aws sts get-caller-identity --output table
    else
        echo "No AWS profile currently set"
    end
end
