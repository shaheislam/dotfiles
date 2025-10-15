function git_quote_wildcards --description "Auto-quote wildcards in git commands before execution"
    # This function is bound to the Enter key in config.fish
    # When you type a git command with wildcards like:
    #   git restore .github/workflows/postgres*
    #
    # The wildcards are automatically quoted before execution:
    #   git restore '.github/workflows/postgres*'
    #
    # This allows git to handle its own pattern matching against the git index/tree,
    # instead of Fish trying to expand the wildcards against the filesystem.
    #
    # Commands supported: restore, add, rm, checkout, diff, reset, log, ls-files, grep, show
    # Get the current command line
    set -l cmd (commandline -b)

    # Check if it's a git command that accepts file patterns
    set -l pattern_commands "restore" "add" "rm" "checkout" "diff" "reset" "log" "ls-files" "grep" "show"

    # Parse the command to check if it's a git command
    set -l cmd_parts (string split ' ' $cmd)

    # Check if this is a git command with at least 2 parts
    if test (count $cmd_parts) -ge 2; and test "$cmd_parts[1]" = "git"
        # Check if the git subcommand accepts patterns
        if contains $cmd_parts[2] $pattern_commands
            # Check if there are any unquoted wildcards
            set -l has_wildcards 0
            for part in $cmd_parts[3..-1]
                if string match -qr '[\*\?]' -- $part; and not string match -qr '^["\'].*["\']$' -- $part
                    set has_wildcards 1
                    break
                end
            end

            # If we found unquoted wildcards, quote them and replace the command
            if test $has_wildcards -eq 1
                set -l new_parts $cmd_parts[1] $cmd_parts[2]
                for part in $cmd_parts[3..-1]
                    # Check if part contains unquoted wildcards
                    if string match -qr '[\*\?]' -- $part; and not string match -qr '^["\'].*["\']$' -- $part
                        # Quote it
                        set -a new_parts "'$part'"
                    else
                        set -a new_parts $part
                    end
                end

                # Replace the command line
                set -l new_cmd (string join ' ' $new_parts)
                commandline -r $new_cmd
            end
        end
    end

    # Execute the command (whether modified or not)
    commandline -f execute
end
