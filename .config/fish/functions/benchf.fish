function benchf --description "Benchmark commands with hyperfine"
    if not test -x /opt/homebrew/bin/hyperfine
        echo "hyperfine not installed"
        return 1
    end

    echo "Enter first command to benchmark:"
    read cmd1
    echo "Enter second command to benchmark (or press Enter to skip):"
    read cmd2

    if test -z "$cmd1"
        echo "No command specified"
        return 1
    end

    if test -n "$cmd2"
        hyperfine --warmup 3 "$cmd1" "$cmd2"
    else
        hyperfine --warmup 3 "$cmd1"
    end
end
