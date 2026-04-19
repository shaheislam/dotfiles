function s3-logs --description "Search and format JSON logs from S3 buckets using s3grep"
    set -l bucket $argv[1]
    set -l pattern $argv[2]
    set -l prefix $argv[3]

    if test -z "$bucket" -o -z "$pattern"
        echo "Usage: s3-logs <bucket> <pattern> [prefix]"
        echo "Example: s3-logs my-log-bucket '\"eventName\":\"AssumeRole\"' logs/2024/01/"
        return 1
    end

    set -l grep_args --bucket $bucket --pattern "$pattern"
    test -n "$prefix"; and set grep_args $grep_args --prefix "$prefix"

    s3grep $grep_args 2>/dev/null | while read -l line
        # Split on .gz: to properly separate filepath from JSON
        set -l parts (string split -m 1 ".gz:" $line)
        if test (count $parts) -eq 2
            set -l filepath $parts[1].gz
            set -l json $parts[2]
            set -l filename (basename $filepath)

            echo "📄 File: $filename"
            echo $json | jq '.' 2>/dev/null || begin
                echo "Raw content (jq failed):"
                echo $json | head -c 500
                echo "..."
            end
            echo "═══════════════════════════════════════════════════════════════"
        else
            echo "Unparsed line: $line"
        end
    end
end
