function npm --description "npm with colored logs"
    if test "$argv[1]" = run; or test "$argv[1]" = start; or test "$argv[1]" = test
        command npm $argv 2>&1 | splash
    else
        command npm $argv
    end
end
