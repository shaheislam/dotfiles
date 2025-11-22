# Enhanced kubectl completions for Fish - intelligent and context-aware

# Helper: Extract namespace from command arguments
function _kubectl_extract_namespace
    set -l args $argv
    set -l namespace ""

    for i in (seq 1 (count $args))
        set -l arg "$args[$i]"
        if test "$arg" = "-n"; or test "$arg" = "--namespace"
            if test $i -lt (count $args)
                set namespace $args[(math $i + 1)]
                break
            end
        else if test "$arg" = "--all-namespaces"; or test "$arg" = "-A"
            set namespace "all"
            break
        end
    end

    # Return default namespace if none specified
    if test -z "$namespace"
        set namespace "default"
    end

    echo $namespace
end

# Helper: Get pods with optional field selector
function _kubectl_get_pods
    set -l namespace $argv[1]
    set -l selector $argv[2]

    set -l cmd "kubectl"
    if test "$namespace" != "all"
        set cmd "$cmd --namespace=$namespace"
    else
        set cmd "$cmd --all-namespaces"
    end

    if test -n "$selector"
        set cmd "$cmd --field-selector=$selector"
    end

    eval "$cmd get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null" | tr ' ' '\n'
end

# Helper: Get any resource type
function _kubectl_get_resources
    set -l namespace $argv[1]
    set -l resource $argv[2]

    set -l cmd "kubectl"
    if test "$namespace" != "all"
        set cmd "$cmd --namespace=$namespace"
    else
        set cmd "$cmd --all-namespaces"
    end

    eval "$cmd get $resource -o jsonpath='{.items[*].metadata.name}' 2>/dev/null" | tr ' ' '\n'
end

# Helper: Get namespaces
function _kubectl_get_namespaces
    kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n'
end

# Helper: Get available resource types
function _kubectl_get_api_resources
    kubectl api-resources --verbs=list --namespaced -o name 2>/dev/null | sort -u
end

# Helper: Get kubectl command flags for context
function _kubectl_get_flags
    set -l subcommand $argv[1]

    switch $subcommand
        case logs
            echo -e "--follow\n-f\n--tail\n--since\n--timestamps\n--previous\n-p\n--container\n-c"
        case get
            echo -e "-o\n--output\n--watch\n-w\n--selector\n-l\n--field-selector\n--all-namespaces\n-A"
        case describe delete edit
            echo -e "--all\n--selector\n-l\n--field-selector"
        case exec
            echo -e "-it\n-i\n-t\n--container\n-c\n--stdin\n--tty"
        case port-forward
            echo -e "--address"
        case apply create
            echo -e "-f\n--filename\n--recursive\n-R\n--dry-run\n--validate"
        case scale
            echo -e "--replicas\n--current-replicas\n--timeout"
        case rollout
            echo -e "--to-revision\n--revision"
        case '*'
            echo -e "--namespace\n-n\n--context\n--help"
    end
end

# Helper: Find YAML/JSON files
function _kubectl_find_manifest_files
    find . -maxdepth 3 \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null | sort
end

# Main enhanced completion function
function kubectl_enhanced_complete
    set -l cmd (commandline -opc)
    set -l current (commandline -ct)

    # Skip if not kubectl command
    if not contains -- $cmd[1] kubectl k kubecolor kctl
        return
    end

    # Extract namespace and context info
    set -l namespace (_kubectl_extract_namespace $cmd)

    # Track position in command
    set -l subcommand ""
    set -l resource_type ""
    set -l has_resource_name false
    set -l last_arg ""
    set -l second_last_arg ""

    # Parse command to understand context
    for i in (seq 2 (count $cmd))
        set -l arg $cmd[$i]

        # Skip namespace flags and their values
        if test "$arg" = "-n"; or test "$arg" = "--namespace"
            continue
        end

        # Skip if previous was namespace flag
        if test "$cmd[(math $i - 1)]" = "-n" 2>/dev/null; or test "$cmd[(math $i - 1)]" = "--namespace" 2>/dev/null
            continue
        end

        # Skip other flags
        if string match -q -- '-*' $arg
            continue
        end

        # First non-flag is subcommand
        if test -z "$subcommand"
            set subcommand $arg
        # Second non-flag is resource type
        else if test -z "$resource_type"
            set resource_type $arg
        # Third non-flag is resource name
        else
            set has_resource_name true
        end
    end

    # Get last arguments for context
    if test (count $cmd) -ge 2
        set last_arg $cmd[-1]
        if test (count $cmd) -ge 3
            set second_last_arg $cmd[-2]
        end
    end

    # Completion logic based on context

    # Complete namespace after -n or --namespace
    if test "$last_arg" = "-n"; or test "$last_arg" = "--namespace"
        _kubectl_get_namespaces
        return
    end

    # Complete files after -f or --filename
    if test "$last_arg" = "-f"; or test "$last_arg" = "--filename"
        _kubectl_find_manifest_files
        return
    end

    # Complete output formats after -o or --output
    if test "$last_arg" = "-o"; or test "$last_arg" = "--output"
        echo -e "yaml\njson\nwide\nname\ncustom-columns=\njsonpath=\ngo-template="
        return
    end

    # If no subcommand yet, provide subcommands
    if test -z "$subcommand"
        echo -e "get\ndescribe\ncreate\napply\ndelete\nedit\nlogs\nexec\nport-forward\ncp\nscale\nrollout\ntop\nexplain\napi-resources\napi-versions\npatch\nreplace\nlabel\nannotate\nrun\nexpose\nautoscale"
        return
    end

    # Handle subcommand-specific completions
    switch $subcommand
        case logs
            if not $has_resource_name
                _kubectl_get_pods $namespace
            else
                _kubectl_get_flags logs
            end

        case exec attach
            if not $has_resource_name
                _kubectl_get_pods $namespace "status.phase=Running"
            else
                _kubectl_get_flags exec
            end

        case port-forward
            if not $has_resource_name
                # Port-forward can work with pods or services
                if test "$resource_type" = "service"; or test "$resource_type" = "services"; or test "$resource_type" = "svc"
                    _kubectl_get_resources $namespace services
                else
                    _kubectl_get_pods $namespace "status.phase=Running"
                end
            else
                _kubectl_get_flags port-forward
            end

        case get describe delete edit patch label annotate
            if test -z "$resource_type"
                # Provide resource types
                echo -e "pods\nservices\ndeployments\nstatefulsets\ndaemonsets\nreplicasets\njobs\ncronjobs\nconfigmaps\nsecrets\ningresses\nnamespaces\nnodes\npersistentvolumeclaims\npersistentvolumes\nserviceaccounts\nroles\nrolebindings\nclusterroles\nclusterrolebindings\nnetworkpolicies\npoddisruptionbudgets\nhorizontalpodautoscalers\nresourcequotas\nlimitranges\nendpoints"
            else if not $has_resource_name
                # Normalize resource type (handle singular/plural)
                set -l normalized_type $resource_type
                switch $resource_type
                    case pod
                        set normalized_type pods
                    case service svc
                        set normalized_type services
                    case deployment deploy
                        set normalized_type deployments
                    case statefulset sts
                        set normalized_type statefulsets
                    case daemonset ds
                        set normalized_type daemonsets
                    case replicaset rs
                        set normalized_type replicasets
                    case configmap cm
                        set normalized_type configmaps
                    case secret
                        set normalized_type secrets
                    case ingress ing
                        set normalized_type ingresses
                    case namespace ns
                        set normalized_type namespaces
                    case node no
                        set normalized_type nodes
                    case persistentvolumeclaim pvc
                        set normalized_type persistentvolumeclaims
                    case persistentvolume pv
                        set normalized_type persistentvolumes
                    case serviceaccount sa
                        set normalized_type serviceaccounts
                end

                # Get resources of that type
                if test "$normalized_type" = "namespaces"; or test "$normalized_type" = "nodes"; or test "$normalized_type" = "persistentvolumes"
                    # Cluster-scoped resources
                    kubectl get $normalized_type -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n'
                else
                    _kubectl_get_resources $namespace $normalized_type
                end
            else
                _kubectl_get_flags $subcommand
            end

        case rollout
            if test -z "$resource_type"
                # Rollout subcommands
                echo -e "status\nhistory\nundo\nrestart\npause\nresume"
            else if test "$resource_type" = "status"; or test "$resource_type" = "history"; or test "$resource_type" = "undo"; or test "$resource_type" = "restart"; or test "$resource_type" = "pause"; or test "$resource_type" = "resume"
                # After rollout subcommand, provide rollout-able resources
                if not $has_resource_name
                    echo -e "deployment\ndaemonset\nstatefulset"
                end
            else if not $has_resource_name
                # Get the rollout-able resources
                switch $resource_type
                    case deployment deployments deploy
                        _kubectl_get_resources $namespace deployments
                    case daemonset daemonsets ds
                        _kubectl_get_resources $namespace daemonsets
                    case statefulset statefulsets sts
                        _kubectl_get_resources $namespace statefulsets
                end
            else
                _kubectl_get_flags rollout
            end

        case scale
            if test -z "$resource_type"
                # Scalable resource types
                echo -e "deployment\nstatefulset\nreplicaset"
            else if not $has_resource_name
                # Get scalable resources
                switch $resource_type
                    case deployment deployments deploy
                        _kubectl_get_resources $namespace deployments
                    case statefulset statefulsets sts
                        _kubectl_get_resources $namespace statefulsets
                    case replicaset replicasets rs
                        _kubectl_get_resources $namespace replicasets
                end
            else
                _kubectl_get_flags scale
            end

        case top
            if test -z "$resource_type"
                echo -e "nodes\npods"
            else if not $has_resource_name
                switch $resource_type
                    case node nodes no
                        kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n'
                    case pod pods po
                        _kubectl_get_pods $namespace
                end
            end

        case create
            if test -z "$resource_type"
                # Creatable resource types
                echo -e "deployment\nservice\nconfigmap\nsecret\ningress\nnamespace\njob\ncronjob\nserviceaccount\nrole\nrolebinding\nclusterrole\nclusterrolebinding\nquota\npodDisruptionBudget"
            else
                _kubectl_get_flags create
            end

        case apply
            _kubectl_get_flags apply

        case run
            if not $has_resource_name
                # For run, we just provide flags since it creates new resources
                echo -e "--image\n--port\n--replicas\n--dry-run\n--overrides\n--rm\n-it"
            end

        case expose
            if test -z "$resource_type"
                # Resources that can be exposed
                echo -e "pod\nservice\ndeployment\nreplicaset"
            else if not $has_resource_name
                switch $resource_type
                    case pod pods po
                        _kubectl_get_pods $namespace
                    case deployment deployments deploy
                        _kubectl_get_resources $namespace deployments
                    case service services svc
                        _kubectl_get_resources $namespace services
                    case replicaset replicasets rs
                        _kubectl_get_resources $namespace replicasets
                end
            else
                echo -e "--port\n--protocol\n--target-port\n--name\n--type"
            end

        case cp
            if not $has_resource_name
                _kubectl_get_pods $namespace "status.phase=Running"
            end

        case '*'
            # For other subcommands, try to be helpful
            if test -z "$resource_type"
                _kubectl_get_api_resources
            end
    end
end

# Wrapper function for backward compatibility
function kubectl_simple_complete
    kubectl_enhanced_complete
end