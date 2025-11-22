# Simple kubectl completions for Fish - similar to ZSH version

function _extract_namespace_from_args
    set -l args $argv
    set -l namespace "default"

    for i in (seq 1 (count $args))
        if test "$args[$i]" = "-n"; or test "$args[$i]" = "--namespace"
            if test $i -lt (count $args)
                set namespace $args[(math $i + 1)]
                break
            end
        end
    end

    echo $namespace
end

function _kubectl_get_pods
    set -l namespace $argv[1]
    kubectl --namespace="$namespace" get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n'
end

function _kubectl_get_namespaces
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n'
end

function _kubectl_get_resources
    set -l namespace $argv[1]
    set -l resource $argv[2]
    kubectl --namespace="$namespace" get "$resource" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n'
end

function kubectl_simple_complete
    set -l cmd (commandline -opc)
    set -l current (commandline -ct)

    # Skip if not kubectl command
    if not contains -- $cmd[1] kubectl k kubecolor
        return
    end

    # Extract namespace from command
    set -l namespace (_extract_namespace_from_args $cmd)

    # Get last meaningful argument
    set -l last_arg ""
    if test (count $cmd) -ge 2
        set last_arg $cmd[-1]
    end

    # Determine what to complete
    if test "$last_arg" = "-n"; or test "$last_arg" = "--namespace"
        # Complete namespaces
        _kubectl_get_namespaces
    else if contains -- logs $cmd
        # Complete pods for logs
        _kubectl_get_pods $namespace
    else if contains -- exec $cmd
        # Complete pods for exec
        _kubectl_get_pods $namespace
    else if contains -- "port-forward" $cmd
        # Complete pods for port-forward
        _kubectl_get_pods $namespace
    else if contains -- describe $cmd
        # Check what resource to describe
        if contains -- pod $cmd; or contains -- pods $cmd
            _kubectl_get_pods $namespace
        else if contains -- deployment $cmd; or contains -- deployments $cmd
            _kubectl_get_resources $namespace deployments
        else if contains -- service $cmd; or contains -- services $cmd
            _kubectl_get_resources $namespace services
        else if contains -- configmap $cmd; or contains -- configmaps $cmd
            _kubectl_get_resources $namespace configmaps
        end
    else if contains -- get $cmd
        # Check what resource to get
        if contains -- pod $cmd; or contains -- pods $cmd
            _kubectl_get_pods $namespace
        else if contains -- deployment $cmd; or contains -- deployments $cmd
            _kubectl_get_resources $namespace deployments
        else if contains -- service $cmd; or contains -- services $cmd
            _kubectl_get_resources $namespace services
        else if contains -- configmap $cmd; or contains -- configmaps $cmd
            _kubectl_get_resources $namespace configmaps
        end
    else if contains -- delete $cmd
        # Check what resource to delete
        if contains -- pod $cmd; or contains -- pods $cmd
            _kubectl_get_pods $namespace
        else if contains -- deployment $cmd; or contains -- deployments $cmd
            _kubectl_get_resources $namespace deployments
        else if contains -- service $cmd; or contains -- services $cmd
            _kubectl_get_resources $namespace services
        else if contains -- configmap $cmd; or contains -- configmaps $cmd
            _kubectl_get_resources $namespace configmaps
        end
    end
end