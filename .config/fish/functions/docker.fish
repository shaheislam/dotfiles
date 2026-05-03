function docker --description "Docker with colored logs"
    if not command -q docker
        printf 'docker: command not found\n' >&2
        return 127
    end

    if test "$argv[1]" = logs
        command docker $argv | splash
    else if test "$argv[1]" = compose; and test "$argv[2]" = logs
        command docker $argv | splash
    else
        command docker $argv
    end
end
