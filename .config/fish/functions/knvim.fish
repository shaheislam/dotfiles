# Convenient function to install Neovim in Kubernetes pods
# Usage: knvim <namespace> <pod> [container]

function knvim --description "Install Neovim with LazyVim config in a Kubernetes pod"
    # Get the directory where dotfiles are located
    set -l dotfiles_dir (dirname (dirname (dirname (dirname (status --current-filename)))))
    set -l script_path "$dotfiles_dir/scripts/install-nvim-in-pod.sh"

    # Check if the script exists
    if not test -f "$script_path"
        echo "Error: install-nvim-in-pod.sh not found at $script_path" >&2
        return 1
    end

    # Check if we have the required arguments
    if test (count $argv) -lt 2
        echo "Usage: knvim <namespace> <pod> [container]" >&2
        echo "Example: knvim default my-pod my-container" >&2
        return 1
    end

    # Execute the script with all arguments
    bash "$script_path" $argv
end

# Helper functions for completions (same as install-nvim-in-pod.fish)
function __fish_knvim_get_namespaces
    kubectl get namespaces --no-headers 2>/dev/null | awk '{print $1}'
end

function __fish_knvim_get_pods
    set -l cmd (commandline -opc)
    set -l namespace "default"

    if test (count $cmd) -ge 2
        set namespace $cmd[2]
    end

    kubectl get pods -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}'
end

function __fish_knvim_get_containers
    set -l cmd (commandline -opc)
    set -l namespace "default"
    set -l pod ""

    if test (count $cmd) -ge 2
        set namespace $cmd[2]
    end
    if test (count $cmd) -ge 3
        set pod $cmd[3]
    end

    if test -n "$pod"
        kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | string split ' '
    end
end

function __fish_knvim_needs_arg
    set -l cmd (commandline -opc)
    set -l num $argv[1]
    test (count $cmd) -eq $num
end

# Completions for knvim
complete -c knvim -f

# First argument: namespace
complete -c knvim \
    -n "__fish_knvim_needs_arg 1" \
    -a "(__fish_knvim_get_namespaces)" \
    -d "Kubernetes namespace"

# Second argument: pod
complete -c knvim \
    -n "__fish_knvim_needs_arg 2" \
    -a "(__fish_knvim_get_pods)" \
    -d "Pod name"

# Third argument: container (optional)
complete -c knvim \
    -n "__fish_knvim_needs_arg 3" \
    -a "(__fish_knvim_get_containers)" \
    -d "Container name (optional)"