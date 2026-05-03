function __fish_complete_aws_profiles
    command -q aws; or return
    aws configure list-profiles 2>/dev/null
end
