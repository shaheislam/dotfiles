function __fish_complete_aws_profiles
    aws configure list-profiles 2>/dev/null
end