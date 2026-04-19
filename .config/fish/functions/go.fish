function go --description "Go with colored output for logs"
    # Check for SPLASH_ARGS environment variable for custom splash options
    if test "$argv[1]" = run; or test "$argv[1]" = test; or test "$argv[1]" = build
        if set -q SPLASH_ARGS
            # Use custom splash arguments if set
            command go $argv 2>&1 | splash $SPLASH_ARGS
        else
            # Default splash without arguments
            command go $argv 2>&1 | splash
        end
    else
        command go $argv
    end
end
