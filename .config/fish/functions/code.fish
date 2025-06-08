function code --description "Open Cursor, with zoxide integration for directory jumping"
    # If no arguments, open current directory
    if test (count $argv) -eq 0
        if command -v cursor >/dev/null
            command cursor .
        else if test -d "/Applications/Cursor.app"
            open -a "Cursor" .
        else
            echo "Cursor is not installed or not found in the expected location."
        end
        return
    end

    # Check if the first argument is an existing file or directory
    if test -e "$argv[1]"
        # It's an existing file/directory, use normal cursor command
        if command -v cursor >/dev/null
            command cursor $argv
        else if test -d "/Applications/Cursor.app"
            open -a "Cursor" $argv
        else
            echo "Cursor is not installed or not found in the expected location."
        end
        return
    end

    # Try to find directory with zoxide
    set -l target_dir (zoxide query $argv[1] 2>/dev/null)

    # If zoxide found a directory, jump to it and open Cursor
    if test $status -eq 0 -a -n "$target_dir"
        echo "Jumping to: $target_dir"
        z $argv[1]

        # Open Cursor in the target directory
        if command -v cursor >/dev/null
            command cursor .
        else if test -d "/Applications/Cursor.app"
            open -a "Cursor" .
        else
            echo "Cursor is not installed or not found in the expected location."
        end
    else
        # Fallback to normal cursor command (might be a file that doesn't exist yet)
        if command -v cursor >/dev/null
            command cursor $argv
        else if test -d "/Applications/Cursor.app"
            open -a "Cursor" $argv
        else
            echo "Cursor is not installed or not found in the expected location."
        end
    end
end
