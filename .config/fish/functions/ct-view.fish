function ct-view --description "Search and analyze AWS CloudTrail logs in S3 buckets"
    set -l bucket ""
    set -l pattern ""
    set -l prefix ""

    # Parse arguments - if first arg is not a bucket, assume it's a pattern
    if test (count $argv) -ge 1
        # Check if first arg is likely a bucket name (no special chars, looks like S3 naming)
        if string match -q "*-*" -- $argv[1]; and not string match -q "*[/:\"']*" -- $argv[1]
            # Looks like a bucket name
            set bucket $argv[1]
            set pattern $argv[2]
            set prefix $argv[3]
        else
            # First arg is probably a pattern (event name, etc.)
            set pattern $argv[1]
            set prefix $argv[2]
        end
    end

    # If no bucket specified, use fzf to select
    if test -z "$bucket"
        set -l buckets (aws s3 ls 2>/dev/null | grep trail | awk '{print $3}')
        if test -z "$buckets"
            echo "No CloudTrail log buckets found"
            return 1
        end
        set bucket (printf '%s\n' $buckets | fzf --prompt="Select CloudTrail bucket: " --height=40% --border)
        test -z "$bucket"; and return 0
    end

    s3-logs $bucket "$pattern" "$prefix" | while read -l line
        if string match -q "📄 File:*" "$line"
            echo $line
        else if string match -q "═*" "$line"
            echo $line
        else
            # Try to parse as CloudTrail event
            set -l json $line
            echo $json | jq -r 'if .userIdentity != null then
                "🔐 Event: \(.eventName // "Unknown") | Source: \(.eventSource // "Unknown")
                👤 User: \(.userIdentity.userName // .userIdentity.arn // .userIdentity.principalId // "System")
                🌍 IP: \(.sourceIPAddress // "N/A") | Region: \(.awsRegion // "N/A")
                🕐 Time: \(.eventTime // "Unknown")
                ───────────────────────────────────────────────────────────────"
                else
                    "🔐 Event: \(.eventName // "Unknown") | Source: \(.eventSource // "Unknown")
👤 User: \(.userIdentity.userName // .userIdentity.arn // .userIdentity.principalId // "System")
🌍 IP: \(.sourceIPAddress // "N/A") | Region: \(.awsRegion // "N/A")
🕐 Time: \(.eventTime // "Unknown")
───────────────────────────────────────────────────────────────"
                end' 2>/dev/null || begin
                echo "Raw JSON (jq failed):"
                echo $json | head -c 500
                echo "..."
            end
            echo ""
        else
            echo $line
        end
    end
end
