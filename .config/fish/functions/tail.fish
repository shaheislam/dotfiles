function tail --description "Tail with automatic log colorization"
    # Check if we're tailing a log file or using -f flag
    if string match -q -- "*-f*" "$argv"; or string match -q -- "*.log" "$argv"
        command tail $argv | splash
    else
        command tail $argv
    end
end
