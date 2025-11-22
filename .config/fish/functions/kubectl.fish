# Kubectl wrapper with automatic fzf integration for 'get' commands
function kubectl --wraps kubectl --description "Kubectl with fzf for get commands, kubecolor, and splash"
    # Intercept 'kubectl get <resource>' commands for interactive fzf selection
    if test "$argv[1]" = "get"; and test (count $argv) -ge 2
        set -l resource $argv[2]
        set -l extra_args $argv[3..-1]

        # Skip fzf if resource starts with dash (it's a flag)
        if not string match -q -- '-*' $resource
            # Skip fzf if a specific resource name is already provided (3rd arg that's not a flag)
            if test (count $argv) -ge 3; and not string match -q -- '-*' $argv[3]
                # User specified a specific resource, don't use FZF
            else if not string match -q -- '*-o*' "$argv"; and not string match -q -- '*--output*' "$argv"
                # Skip fzf if -o/--output flag is present (user wants direct output)
                # Use bash wrapper for fzf integration (configurable via KUBECTL_FZF_OPTS)
                # Wrapper location: ~/.config/fish/functions/kubectl-fzf-wrapper.sh
                env KUBECONFIG=$KUBECONFIG ~/.config/fish/functions/kubectl-fzf-wrapper.sh $resource $extra_args
                return
            end
        end
    end

    # Pass through to kubectl with optional splash/kubecolor
    if test "$argv[1]" = "logs"; and command -v splash >/dev/null
        # Use splash for log colorization
        command kubectl $argv | splash
    else if command -v kubecolor >/dev/null
        # Use kubecolor for other commands
        kubecolor $argv
    else
        # Fallback to regular kubectl
        command kubectl $argv
    end
end
