function kpods-all --description "Get pods from all namespaces"
    kubectl get pods --all-namespaces
end
