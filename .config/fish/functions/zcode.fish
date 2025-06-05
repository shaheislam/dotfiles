function zcode --description "Jump to directory with zoxide and open in VS Code"
    # If no arguments provided, just open current directory in VS Code
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

    # Get the directory path from zoxide
    set -l target_dir (zoxide query $argv[1])

    # Check if zoxide found a directory
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
        echo "Directory not found in zoxide database: $argv[1]"
        return 1
    end
end
