function logs --description "Quick AWS log search with fzf bucket selection"
    set -l pattern $argv[1]
    set -l bucket $argv[2]

    if test -z "$pattern"
        echo "Usage: logs <pattern> [bucket]"
        echo "Examples:"
        echo "  logs AssumeRole                    # Search with bucket selection"
        echo "  logs '\"severity\":[5-9]' my-bucket  # Search specific bucket"
        echo ""
        echo "Common patterns:"
        echo "  AssumeRole           - Role assumptions"
        echo "  CreateBucket         - Bucket creation events"
        echo "  UnauthorizedAccess   - GuardDuty unauthorized access"
        echo "  '\"severity\":[5-9]'  - GuardDuty medium+ severity"
        echo "  root                 - Root account usage"
        return 1
    end

    if test -z "$bucket"
        # Use fzf to select bucket or search all log buckets
        set -l log_buckets (aws s3 ls 2>/dev/null | grep -E "(log|trail|guard|audit)" | awk '{print $3}')

        if test -n "$log_buckets"
            # Add option to search all
            set -l options "Search all log buckets"
            set options $options $log_buckets

            set -l selected (printf '%s\n' $options | fzf --prompt="Select bucket to search: " --height=40% --border)

            if test "$selected" = "Search all log buckets"
                echo "Searching all log buckets..."
                for b in $log_buckets
                    echo "🔍 Searching $b..."
                    s3-logs $b "$pattern" | head -5
                end
            else if test -n "$selected"
                set bucket $selected
                echo "Searching $bucket..."
                s3-logs $bucket "$pattern"
            end
        else
            # Fallback to known buckets
            echo "No log buckets found, trying default buckets..."

            # Try CloudTrail bucket
            if aws s3 ls s3://petlab-centralize-logging/ >/dev/null 2>&1
                echo "🔍 Searching CloudTrail logs..."
                s3-logs petlab-centralize-logging "$pattern" AWSLogs/ | head -10
            end

            # Try GuardDuty bucket
            if aws s3 ls s3://petlab-guardduty-logging/ >/dev/null 2>&1
                echo "🔍 Searching GuardDuty logs..."
                s3-logs petlab-guardduty-logging "$pattern" AWSLogs/ | head -10
            end
        end
    else
        # Search specific bucket
        echo "Searching $bucket..."
        s3-logs $bucket "$pattern"
    end
end
