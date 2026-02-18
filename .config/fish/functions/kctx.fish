function kctx --description "Switch Kubernetes context with fzf"
    if not test -x /opt/homebrew/bin/kubectl
        echo "kubectl not installed"
        return 1
    end

    set -l contexts (kubectl config get-contexts -o name 2>/dev/null)
    if test -z "$contexts"
        echo "No Kubernetes contexts found"
        return 1
    end

    set -l selected (printf '%s\n' $contexts | fzf \
        --prompt="Select Kubernetes context: " \
        --height=40% \
        --border \
        --preview='kubectl config view --minify --context={} | head -20')

    if test -n "$selected"
        kubectl config use-context $selected
        echo "Switched to context: $selected"
    end
end
