function kns --description "Switch Kubernetes namespace with fzf"
    if not command -q kubectl
        echo "kubectl not installed"
        return 1
    end

    if test (count $argv) -eq 0; and not command -q fzf
        echo "fzf not installed"
        return 1
    end

    # If argument provided, switch directly
    if test (count $argv) -gt 0
        kubectl config set-context --current --namespace=$argv[1]
        echo "Switched to namespace: $argv[1]"
        return 0
    end

    # No argument - use fzf picker
    set -l namespaces (kubectl get namespaces -o name 2>/dev/null | command cut -d/ -f2)
    if test -z "$namespaces"
        echo "No namespaces found"
        return 1
    end

    set -l selected (printf '%s\n' $namespaces | fzf \
        --prompt="Select namespace: " \
        --height=40% \
        --border \
        --preview='kubectl get pods -n {} 2>/dev/null | head -20')

    if test -n "$selected"
        kubectl config set-context --current --namespace=$selected
        echo "Switched to namespace: $selected"
    end
end
