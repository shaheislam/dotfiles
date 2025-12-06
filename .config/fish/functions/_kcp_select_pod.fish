# Helper: Select pod with fzf for kcp
function _kcp_select_pod --argument-names namespace
    kubectl get pods -n $namespace -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp --no-headers 2>/dev/null | \
        fzf --prompt="Select pod [$namespace]: " \
            --height=50% \
            --reverse \
            --preview="kubectl describe pod {1} -n $namespace 2>/dev/null | head -50" \
            --preview-window=right:50%:wrap | \
        awk '{print $1}'
end
