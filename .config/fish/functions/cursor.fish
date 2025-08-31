function cursor --description "Open files in Cursor editor"
    if command -v cursor >/dev/null
        command cursor $argv
    else if test -d "/Applications/Cursor.app"
        open -a "Cursor" $argv
    else
        echo "Cursor is not installed or not found in the expected location."
    end
end