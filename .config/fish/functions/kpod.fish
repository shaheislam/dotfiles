function kpod --description "Select Kubernetes pod with fzf"
    if not test -x /opt/homebrew/bin/kubectl
        echo "kubectl not installed"
        return 1
    end

    set -l pods (kubectl get pods --no-headers 2>/dev/null)
    if test -z "$pods"
        echo "No pods found in current namespace"
        return 1
    end

    set -l selected (printf '%s\n' $pods | fzf \
        --prompt="Pod: " \
        --height=80% \
        --border \
        --multi \
        --bind 'tab:toggle+down,shift-tab:toggle+up' \
        --header="TAB: select multiple | NAME READY STATUS RESTARTS AGE" \
        --bind='ctrl-l:execute(kubectl logs {1})' \
        --bind='ctrl-e:execute(kubectl exec -it {1} -- /bin/sh)' \
        --bind='ctrl-d:execute(kubectl delete pod {1})' \
        --preview='kubectl describe pod {1}')

    if test -n "$selected"
        for line in $selected
            set -l pod_name (echo $line | awk '{print $1}')
            echo "=== Pod: $pod_name ==="
            kubectl describe pod $pod_name
            echo ""
        end
    end
end
