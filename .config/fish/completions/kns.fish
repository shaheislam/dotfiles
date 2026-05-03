function __kns_namespaces
    command -q kubectl; or return
    kubectl get namespaces -o name 2>/dev/null | cut -d/ -f2
end

complete -c kns -f -a "(__kns_namespaces)" -d "Kubernetes namespace"
