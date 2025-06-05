function code --description "Open VS Code, with zoxide integration for directory jumping"
    # If no arguments, open current directory
    if test (count $argv) -eq 0
        if command -v code >/dev/null
            command code .
        else if test -d "/Applications/Visual Studio Code.app"
            open -a "Visual Studio Code" .
        else
            echo "VSCode is not installed or not found in the expected location."
        end
        return
    end

    # Check if the first argument is an existing file or directory
    if test -e "$argv[1]"
        # It's an existing file/directory, use normal code command
        if command -v code >/dev/null
            command code $argv
        else if test -d "/Applications/Visual Studio Code.app"
            open -a "Visual Studio Code" $argv
        else
            echo "VSCode is not installed or not found in the expected location."
        end
        return
    end

    # Try to find directory with zoxide
    set -l target_dir (zoxide query $argv[1] 2>/dev/null)

    # If zoxide found a directory, jump to it and open VS Code
    if test $status -eq 0 -a -n "$target_dir"
        echo "Jumping to: $target_dir"
        cd "$target_dir"

        # Open VS Code in the target directory
        if command -v code >/dev/null
            command code .
        else if test -d "/Applications/Visual Studio Code.app"
            open -a "Visual Studio Code" .
        else
            echo "VSCode is not installed or not found in the expected location."
        end
    else
        # Fallback to normal code command (might be a file that doesn't exist yet)
        if command -v code >/dev/null
            command code $argv
        else if test -d "/Applications/Visual Studio Code.app"
            open -a "Visual Studio Code" $argv
        else
            echo "VSCode is not installed or not found in the expected location."
        end
    end
end
