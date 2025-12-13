function jwt --description "Decode JWT tokens with fzf preview"
    # Usage:
    #   jwt              - decode from clipboard
    #   jwt <token>      - decode provided token
    #   echo $TOKEN | jwt - decode from stdin

    set -l token

    if test (count $argv) -gt 0
        # Token provided as argument
        set token $argv[1]
    else if not isatty stdin
        # Token from stdin (piped)
        set token (cat)
    else
        # Token from clipboard
        set token (pbpaste)
    end

    # Validate token format (3 parts separated by dots)
    if not string match -qr '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$' -- $token
        echo "Error: Invalid JWT format" >&2
        return 1
    end

    # Decode and display with colors
    command jwt decode $token
end
