# Enhanced kubectl completions registration

# Load enhanced completions if available
if functions -q kubectl_enhanced_complete
    source ~/.config/fish/functions/kubectl_enhanced_complete.fish
end

# Load FZF completions if available
if functions -q kubectl_fzf_complete
    source ~/.config/fish/functions/kubectl_fzf_complete.fish
end

# Function to determine which completion to use
function __kubectl_smart_complete
    # Check if FZF mode is enabled and FZF function exists
    if test "$kubectl_use_fzf" = "true"; and functions -q kubectl_fzf_complete
        kubectl_fzf_complete
    else if functions -q kubectl_enhanced_complete
        kubectl_enhanced_complete
    else if functions -q kubectl_simple_complete
        kubectl_simple_complete
    end
end

# Register completions for kubectl and aliases
for cmd in kubectl k kubecolor kctl
    # Use smart completion that checks for FZF mode
    complete -c $cmd -f -a "(__kubectl_smart_complete)"
end

# Helper aliases for common kubectl + FZF operations
abbr --add kgpf "kubectl get pods | fzf | xargs kubectl describe pod"
abbr --add klf "kubectl get pods | fzf | xargs kubectl logs -f"
abbr --add kexf "kubectl get pods | fzf | xargs -I {} kubectl exec -it {} -- /bin/bash"
abbr --add kfzf "kubectl_toggle_fzf"  # Toggle FZF mode