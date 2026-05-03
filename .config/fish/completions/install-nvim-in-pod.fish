# Fish completion for install-nvim-in-pod.sh
# Provides intelligent autocomplete for namespace, pod, and container arguments

# Helper function to get namespaces
function __fish_install_nvim_get_namespaces
    command -q kubectl; or return
    kubectl get namespaces --no-headers 2>/dev/null | awk '{print $1}'
end

# Helper function to get pods in a namespace
function __fish_install_nvim_get_pods
    command -q kubectl; or return
    set -l cmd (commandline -opc)
    set -l namespace "default"

    # Check if namespace was provided as first argument
    if test (count $cmd) -ge 2
        set namespace $cmd[2]
    end

    kubectl get pods -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}'
end

# Helper function to get containers in a pod
function __fish_install_nvim_get_containers
    command -q kubectl; or return
    set -l cmd (commandline -opc)
    set -l namespace "default"
    set -l pod ""

    # Get namespace and pod from command line
    if test (count $cmd) -ge 2
        set namespace $cmd[2]
    end
    if test (count $cmd) -ge 3
        set pod $cmd[3]
    end

    # If we have a pod, get its containers
    if test -n "$pod"
        kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | string split ' '
    end
end

# Helper function to check if we need a specific argument
function __fish_install_nvim_needs_arg
    set -l cmd (commandline -opc)
    set -l num $argv[1]
    test (count $cmd) -eq $num
end

# Completion for install-nvim-in-pod.sh
complete -c install-nvim-in-pod.sh -f

# First argument: namespace
complete -c install-nvim-in-pod.sh \
    -n "__fish_install_nvim_needs_arg 1" \
    -a "(__fish_install_nvim_get_namespaces)" \
    -d "Kubernetes namespace"

# Second argument: pod
complete -c install-nvim-in-pod.sh \
    -n "__fish_install_nvim_needs_arg 2" \
    -a "(__fish_install_nvim_get_pods)" \
    -d "Pod name"

# Third argument: container (optional)
complete -c install-nvim-in-pod.sh \
    -n "__fish_install_nvim_needs_arg 3" \
    -a "(__fish_install_nvim_get_containers)" \
    -d "Container name (optional)"

# Also support the script if it's in PATH or called with full path
complete -c install-nvim-in-pod \
    -w install-nvim-in-pod.sh

# Support when called from scripts directory
for script_path in ~/dotfiles/scripts/install-nvim-in-pod.sh ./scripts/install-nvim-in-pod.sh ./install-nvim-in-pod.sh
    complete -c $script_path -f

    # First argument: namespace
    complete -c $script_path \
        -n "__fish_install_nvim_needs_arg 1" \
        -a "(__fish_install_nvim_get_namespaces)" \
        -d "Kubernetes namespace"

    # Second argument: pod
    complete -c $script_path \
        -n "__fish_install_nvim_needs_arg 2" \
        -a "(__fish_install_nvim_get_pods)" \
        -d "Pod name"

    # Third argument: container (optional)
    complete -c $script_path \
        -n "__fish_install_nvim_needs_arg 3" \
        -a "(__fish_install_nvim_get_containers)" \
        -d "Container name (optional)"
end
