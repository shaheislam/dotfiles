function gds-aws-env --description "Export GDS AWS credentials to fish environment"
    # Clear any existing AWS credentials
    set -e AWS_CREDENTIAL_FILE 2>/dev/null
    set -e AWS_DEFAULT_PROFILE 2>/dev/null
    set -e AWS_PROFILE 2>/dev/null
    set -e AWS_ACCESS_KEY_ID 2>/dev/null
    set -e AWS_SECRET_ACCESS_KEY 2>/dev/null
    set -e AWS_SESSION_TOKEN 2>/dev/null
    set -e AWS_REGION 2>/dev/null
    set -e AWS_DEFAULT_REGION 2>/dev/null

    # Get credentials from gds aws
    set -l output (gds aws $argv -e 2>&1)

    # Extract and set each variable using grep and sed
    set -l region (echo $output | grep -o "AWS_REGION='[^']*'" | sed "s/AWS_REGION='//;s/'//")
    set -l default_region (echo $output | grep -o "AWS_DEFAULT_REGION='[^']*'" | sed "s/AWS_DEFAULT_REGION='//;s/'//")
    set -l access_key (echo $output | grep -o "AWS_ACCESS_KEY_ID='[^']*'" | sed "s/AWS_ACCESS_KEY_ID='//;s/'//")
    set -l secret_key (echo $output | grep -o "AWS_SECRET_ACCESS_KEY='[^']*'" | sed "s/AWS_SECRET_ACCESS_KEY='//;s/'//")
    set -l session_token (echo $output | grep -o "AWS_SESSION_TOKEN='[^']*'" | sed "s/AWS_SESSION_TOKEN='//;s/'//")

    if test -z "$access_key"
        echo "Error: Could not get credentials"
        echo "Output was: $output"
        return 1
    end

    # Export the variables
    set -gx AWS_REGION $region
    set -gx AWS_DEFAULT_REGION $default_region
    set -gx AWS_ACCESS_KEY_ID $access_key
    set -gx AWS_SECRET_ACCESS_KEY $secret_key
    set -gx AWS_SESSION_TOKEN $session_token

    echo "AWS credentials exported for: $argv"
    aws sts get-caller-identity
end
