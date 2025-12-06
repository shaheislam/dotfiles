# Helper: Select container if pod has multiple
function _kcp_select_container --argument-names namespace pod
    set -l containers (kubectl get pod $pod -n $namespace -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | tr ' ' '\n')

    if test (count $containers) -le 1
        # Single container, no need to select
        return
    end

    echo $containers | tr ' ' '\n' | \
        fzf --prompt="Select container: " \
            --height=30% \
            --reverse
end
