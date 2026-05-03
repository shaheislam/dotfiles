# Custom stern completion - delegates to FZF handler
# Clear any existing completions to prevent conflicts with our FZF integration
complete -c stern -e

function __stern_complete_namespaces
    command -q kubectl; or return
    kubectl get namespaces -o name 2>/dev/null | string replace 'namespace/' ''
end

# Keep file completion disabled even if the TAB router is unavailable.
complete -c stern -f
complete -c stern -s n -l namespace -x -a '(__stern_complete_namespaces)' -d 'Kubernetes namespace'
complete -c stern -l context -x -d 'Kube context'
complete -c stern -s c -l container -x -d 'Container name'
complete -c stern -s l -l selector -x -d 'Label selector'
complete -c stern -l since -x -d 'Show logs since duration'
complete -c stern -l tail -x -d 'Number of lines to show'
complete -c stern -l all-namespaces -d 'Tail logs across all namespaces'
