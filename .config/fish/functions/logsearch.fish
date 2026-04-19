function logsearch --description "View logs with highlighted search term"
    if test (count $argv) -lt 2
        echo "Usage: logsearch <file> <search-term>"
        return 1
    end
    cat $argv[1] | splash -s $argv[2]
end
