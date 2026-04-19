function cat --description "Cat with automatic log colorization"
    # Check if we're viewing a log file
    if string match -q -- "*.log" "$argv"; or string match -q -- "*.json" "$argv"
        command cat $argv | splash
    else
        # Use bat for other files if available, otherwise regular cat
        if test -x /opt/homebrew/bin/bat
            bat $argv
        else
            command cat $argv
        end
    end
end
