function cursor --description "Open Cursor, with zoxide integration for directory jumping"
    # If no arguments provided, open current directory
    if test (count $argv) -eq 0
        open -a Cursor .
        return
    end

    # Try to find directory with zoxide
    set -l target_dir (zoxide query $argv[1] 2>/dev/null)

    # If zoxide found a directory, jump to it and open Cursor
    if test -n "$target_dir"
        cd "$target_dir"
        open -a Cursor .
    else
        # If no directory found, try to open the argument as a file
        if test -e "$argv[1]"
            open -a Cursor "$argv[1]"
        else
            echo "Directory or file not found: $argv[1]"
            return 1
        end
    end
end
