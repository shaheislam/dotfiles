function kexec --description "Exec into a pod with shell detection"
    if test (count $argv) -eq 0
        echo "Usage: kexec <pod-name> [command]"
        return 1
    end

    set -l pod $argv[1]
    set -l cmd $argv[2..-1]

    if test -z "$cmd"
        # Try common shells in order
        for shell in bash sh ash
            if kubectl exec $pod -- which $shell >/dev/null 2>&1
                echo "Using shell: $shell"
                kubectl exec -it $pod -- $shell
                return 0
            end
        end
        echo "No suitable shell found"
        return 1
    else
        kubectl exec -it $pod -- $cmd
    end
end
