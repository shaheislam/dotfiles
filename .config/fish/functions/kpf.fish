function kpf --description "Port forward to a pod"
    if test (count $argv) -lt 2
        echo "Usage: kpf <pod-name> <local-port>:<pod-port>"
        return 1
    end
    kubectl port-forward $argv[1] $argv[2]
end
