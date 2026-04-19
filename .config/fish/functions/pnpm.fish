function pnpm --description "pnpm with colored logs"
    if test "$argv[1]" = run; or test "$argv[1]" = start; or test "$argv[1]" = test
        command pnpm $argv 2>&1 | splash
    else
        command pnpm $argv
    end
end
