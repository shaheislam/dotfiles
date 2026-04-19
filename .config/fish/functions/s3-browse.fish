function s3-browse --description "Interactive browser for exploring S3 log buckets with fzf"
    set -l bucket $argv[1]

    if test -z "$bucket"
        # Use fzf to select from available buckets
        set -l buckets (aws s3 ls 2>/dev/null | awk '{print $3}')
        if test -z "$buckets"
            echo "No S3 buckets found"
            return 1
        end

        set bucket (printf '%s\n' $buckets | fzf --prompt="Select S3 bucket: " --height=40% --border)
        test -z "$bucket"; and return 0
    end

    echo "S3 Log Browser: $bucket"
    echo "======================"

    # Use fzf to select prefix
    set -l prefixes (aws s3 ls s3://$bucket/ 2>/dev/null | grep PRE | awk '{print $2}')

    if test -n "$prefixes"
        set -l selected_prefix (printf '%s\n' $prefixes | fzf --prompt="Select prefix: " --height=40% --border)

        if test -n "$selected_prefix"
            s3-dates $bucket $selected_prefix
        end
    else
        # No prefixes, try root
        s3-dates $bucket ""
    end
end
