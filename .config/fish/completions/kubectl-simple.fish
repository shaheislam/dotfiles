# Enhanced kubectl completions registration
# Uses native __fish_kubectl_* functions with FZF wrapper for optimal completion

# Load native FZF completions
if functions -q kubectl_fzf_native
    source ~/.config/fish/functions/kubectl_fzf_native.fish
end

# Function to determine which completion to use
function __kubectl_smart_complete
    # Use native FZF wrapper (preferred)
    if functions -q kubectl_fzf_native
        kubectl_fzf_native
    # Fall back to original enhanced completion if native not available
    else if test "$kubectl_use_fzf" = "true"; and functions -q kubectl_fzf_complete
        kubectl_fzf_complete
    else if functions -q kubectl_enhanced_complete
        kubectl_enhanced_complete
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
