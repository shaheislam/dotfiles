function s3grep
    if test -z "$AWS_PROFILE"
        echo "No AWS profile set. Run 'aws-sso <profile>' first."
        return 1
    end
    command s3grep $argv
end
