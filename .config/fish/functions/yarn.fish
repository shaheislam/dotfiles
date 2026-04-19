function yarn --description "yarn with colored logs"
    if test "$argv[1]" = run; or test "$argv[1]" = start; or test "$argv[1]" = test
        command yarn $argv 2>&1 | splash
    else
        command yarn $argv
    end
end
