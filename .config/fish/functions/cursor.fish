function cursor --description "Open Cursor, with zoxide integration for directory jumping"
    # If no arguments, open current directory
    if test (count $argv) -eq 0
        open -a Cursor .
        return
    end

    # Check if the first argument is an existing file or directory
    if test -e "$argv[1]"
        # It's an existing file/directory, open it directly
        open -a Cursor $argv
        return
    end

    # Try to find directory with zoxide
    set -l target_dir (zoxide query $argv[1] 2>/dev/null)

    # If zoxide found a directory, jump to it and open Cursor
    if test $status -eq 0 -a -n "$target_dir"
        echo "Jumping to: $target_dir"
        cd "$target_dir"
        open -a Cursor .
    else
        # Fallback to opening the argument (might be a file that doesn't exist yet)
        open -a Cursor $argv
    end
end
