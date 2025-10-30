# Cross-platform clipboard copy function
# Abstracts pbcopy (macOS), xclip, and xsel (Linux)

function clipboard_copy -d "Copy to clipboard (cross-platform)"
    if test (uname -s) = "Darwin"
        # macOS
        pbcopy
    else if command -v xclip > /dev/null 2>&1
        # Linux with xclip
        xclip -selection clipboard
    else if command -v xsel > /dev/null 2>&1
        # Linux with xsel
        xsel --clipboard --input
    else if command -v wl-copy > /dev/null 2>&1
        # Wayland
        wl-copy
    else
        echo "Error: No clipboard tool available (install xclip, xsel, or wl-clipboard)" >&2
        return 1
    end
end
