function __kns_namespaces
    kubectl get namespaces -o name 2>/dev/null | cut -d/ -f2
end

complete -c kns -f -a "(__kns_namespaces)" -d "Kubernetes namespace"
