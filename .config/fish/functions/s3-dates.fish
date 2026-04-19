function s3-dates --description "List and explore S3 log dates with fzf selection"
    set -l bucket $argv[1]
    set -l prefix $argv[2]
    set -l days $argv[3]

    if test -z "$bucket"
        # Use fzf to select bucket if not provided
        set -l buckets (aws s3 ls 2>/dev/null | awk '{print $3}')
        if test -z "$buckets"
            echo "No S3 buckets found"
            return 1
        end

        set bucket (printf '%s\n' $buckets | fzf --prompt="Select S3 bucket: " --height=40% --border)
        test -z "$bucket"; and return 0
    end

    test -z "$days"; and set days 30

    echo "📅 Fetching dates from s3://$bucket/$prefix..."
    set -l dates (aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null \
        | awk '{print $1}' | sort -u | tail -n $days)

    if test -z "$dates"
        echo "No dates found in s3://$bucket/$prefix"
        return 1
    end

    set -l selected_date (printf '%s\n' $dates | fzf --reverse --prompt="Select date to explore: " --height=40% --border)

    if test -n "$selected_date"
        set -l date_path (string replace -a "/" "/" $selected_date)

        # List files for selected date
        echo "Files for $selected_date:"
        set -l files (aws s3 ls s3://$bucket/$prefix --recursive 2>/dev/null | grep "$date_path" | awk '{print $4}' | head -20)

        if test -n "$files"
            set -l selected_file (printf '%s\n' $files | fzf --prompt="Select file to view: " --height=40% --border)

            if test -n "$selected_file"
                echo "Viewing: $selected_file"
                aws s3 cp s3://$bucket/$selected_file - 2>/dev/null | head -100 | jq '.' 2>/dev/null || aws s3 cp s3://$bucket/$selected_file - 2>/dev/null | head -100
            end
        else
            echo "No files found for date: $selected_date"
        end
    end
end
