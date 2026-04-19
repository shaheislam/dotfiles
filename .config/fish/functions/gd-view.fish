function gd-view --description "Search and analyze AWS GuardDuty security findings in S3"
    set -l bucket ""
    set -l pattern ""
    set -l prefix ""

    # Parse arguments - if first arg doesn't look like a bucket name, treat it as pattern
    if test (count $argv) -ge 1
        # Check if first arg looks like a search pattern (contains quotes, brackets, colons, etc.)
        if string match -q "*[\"':{\[\]]*" -- $argv[1]; or string match -q "*severity*" -- $argv[1]
            # First arg is a pattern, need to select bucket
            set pattern $argv[1]
            set prefix $argv[2]
        else
            # First arg is a bucket
            set bucket $argv[1]
            set pattern $argv[2]
            set prefix $argv[3]
        end
    end

    # If no bucket specified, use fzf to select
    if test -z "$bucket"
        set -l buckets (aws s3 ls 2>/dev/null | grep guardduty | awk '{print $3}')
        if test -z "$buckets"
            echo "No GuardDuty log buckets found"
            return 1
        end
        set bucket (printf '%s\n' $buckets | fzf --prompt="Select GuardDuty bucket: " --height=40% --border)
        test -z "$bucket"; and return 0
    end

    s3-logs $bucket "$pattern" "$prefix" | while read -l line
        if string match -q "📄 File:*" "$line"
            echo $line
        else if string match -q "═*" "$line"
            echo $line
        else
            # Try to parse as GuardDuty finding
            echo $line | jq -r 'select(.type != null) |
                "🔍 \(.type)
                📊 Severity: \(.severity) | \(.title // "No title")
                👤 Resource: \(.resource.resourceType // "Unknown")
                🌍 Region: \(.region // "Unknown")
                🕐 Time: \(.createdAt // .updatedAt // "Unknown")
                📝 \(.description // "No description")"' 2>/dev/null || echo $line
        end
    end
end
