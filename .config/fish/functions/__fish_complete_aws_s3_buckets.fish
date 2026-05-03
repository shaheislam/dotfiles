function __fish_complete_aws_s3_buckets
    command -q aws; or return
    if test -n "$AWS_PROFILE"
        aws s3 ls 2>/dev/null | awk '{print $3}' | head -20
    end
end
