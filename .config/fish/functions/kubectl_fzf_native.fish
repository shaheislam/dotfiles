# FZF-powered kubectl completions using native __fish_kubectl_* functions
# This replaces kubectl_enhanced_complete.fish and kubectl_fzf_complete.fish
# with a leaner implementation that leverages the comprehensive native completions

# Toggle for FZF mode
set -g kubectl_use_fzf true

function kubectl_fzf_native --description "FZF-powered kubectl completion using native functions"
    set -l cmd (commandline -opc)
    set -l current (commandline -ct)

    # Skip if not kubectl command
    if not contains -- $cmd[1] kubectl k kubecolor kctl
        return
    end

    # Parse command to understand context
    set -l subcommand ""
    set -l resource_type ""
    set -l resource_name ""
    set -l last_arg ""
    set -l position 0  # 0=need subcmd, 1=need resource_type, 2=need resource_name, 3+=flags

    for i in (seq 2 (count $cmd))
        set -l arg $cmd[$i]

        # Track last arg
        set last_arg $arg

        # Skip flags and their values
        if string match -q -- '-*' $arg
            continue
        end

        # Skip values after namespace flag
        if test $i -gt 2
            set -l prev $cmd[(math $i - 1)]
            if test "$prev" = "-n"; or test "$prev" = "--namespace"
                continue
            end
        end

        # Track position
        set position (math $position + 1)
        if test $position -eq 1
            set subcommand $arg
        else if test $position -eq 2
            set resource_type $arg
        else if test $position -eq 3
            set resource_name $arg
        end
    end

    # Determine what completions to show
    set -l completions
    set -l fzf_prompt "Select: "
    set -l preview_cmd ""
    set -l show_preview false

    # Handle flag value completions
    switch $last_arg
        case -n --namespace
            set completions (__fish_kubectl_print_resource namespace)
            set fzf_prompt "Namespace: "
        case -c --container
            # Use native function - it parses commandline to find pod name
            # Output directly without FZF since container lists are usually short
            __fish_kubectl_print_pod_containers
            return
        case -o --output
            printf '%s\n' yaml json wide name "custom-columns=" "jsonpath=" "go-template="
            return
        case -f --filename
            # File completion - let fish handle it
            return
    end

    # If we handled a flag above, show FZF and return
    if test (count $completions) -gt 0
        if test "$kubectl_use_fzf" = "true"
            printf '%s\n' $completions | fzf --height=40% --prompt="$fzf_prompt"
        else
            printf '%s\n' $completions
        end
        return
    end

    # Handle subcommand-specific completions
    if test -z "$subcommand"
        # Show subcommands
        set completions (__fish_kubectl_get_commands | string replace -r '\t.*' '')
        set fzf_prompt "Command: "
    else
        switch $subcommand
            # Commands that work on pods directly
            case logs
                if test -z "$resource_type"
                    set completions (__fish_kubectl_print_resource pods)
                    set fzf_prompt "Pod: "
                    set show_preview true
                    set preview_cmd "kubectl describe pod {} 2>/dev/null | head -30"
                end

            case exec attach
                if test -z "$resource_type"
                    set completions (__fish_kubectl_print_resource pods)
                    set fzf_prompt "Pod: "
                    set show_preview true
                    set preview_cmd "kubectl get pod {} -o wide 2>/dev/null"
                end

            case cp
                if test -z "$resource_type"
                    set completions (__fish_kubectl_print_resource pods)
                    set fzf_prompt "Pod: "
                end

            # Port-forward supports pods, services, deployments
            case port-forward
                if test -z "$resource_type"
                    # Show pods and services with prefixes
                    set completions (
                        __fish_kubectl_print_resource pods
                        __fish_kubectl_print_services_with_prefix
                        __fish_kubectl_print_deployments_with_prefix
                    )
                    set fzf_prompt "Resource: "
                    set show_preview true
                    set preview_cmd "kubectl describe {} 2>/dev/null | head -30"
                else if test -z "$resource_name"
                    # Show available ports
                    set completions (__fish_kubectl_print_resource_ports)
                    set fzf_prompt "Port: "
                end

            # Commands that need resource type first
            case get describe delete edit patch label annotate
                if test -z "$resource_type"
                    set completions (__fish_kubectl_print_resource_types)
                    set fzf_prompt "Resource type: "
                else if test -z "$resource_name"
                    set completions (__fish_kubectl_print_resource $resource_type)
                    set fzf_prompt "$resource_type: "
                    set show_preview true
                    set preview_cmd "kubectl describe $resource_type {} 2>/dev/null | head -30"
                end

            # Rollout commands
            case rollout
                if test -z "$resource_type"
                    set completions status history undo restart pause resume
                    set fzf_prompt "Rollout action: "
                else if contains -- $resource_type status history undo restart pause resume
                    if test -z "$resource_name"
                        set completions (__fish_kubectl_get_rollout_resources)
                        set fzf_prompt "Deployment: "
                    end
                end

            # Scale commands
            case scale
                if test -z "$resource_type"
                    set completions deployment statefulset replicaset
                    set fzf_prompt "Resource type: "
                else if test -z "$resource_name"
                    set completions (__fish_kubectl_print_resource $resource_type)
                    set fzf_prompt "$resource_type: "
                end

            # Top command
            case top
                if test -z "$resource_type"
                    set completions pods nodes
                    set fzf_prompt "Resource type: "
                else if test -z "$resource_name"
                    set completions (__fish_kubectl_print_resource $resource_type)
                    set fzf_prompt "$resource_type: "
                end

            # Create command
            case create
                if test -z "$resource_type"
                    set completions deployment service configmap secret namespace job cronjob serviceaccount role rolebinding clusterrole clusterrolebinding quota
                    set fzf_prompt "Resource type: "
                end

            # Expose command
            case expose
                if test -z "$resource_type"
                    set completions pod service deployment replicaset
                    set fzf_prompt "Resource type: "
                else if test -z "$resource_name"
                    set completions (__fish_kubectl_print_resource $resource_type)
                    set fzf_prompt "$resource_type: "
                end

            # Config commands
            case config
                if test -z "$resource_type"
                    set completions view use-context get-contexts get-clusters current-context set-context set-cluster
                    set fzf_prompt "Config action: "
                else if contains -- $resource_type use-context get-contexts set-context
                    set completions (__fish_kubectl_get_config contexts)
                    set fzf_prompt "Context: "
                else if contains -- $resource_type get-clusters set-cluster
                    set completions (__fish_kubectl_get_config clusters)
                    set fzf_prompt "Cluster: "
                end

            # Node operations
            case cordon uncordon drain taint
                if test -z "$resource_type"
                    set completions (__fish_kubectl_print_resource nodes)
                    set fzf_prompt "Node: "
                end

            # Default: show resource types
            case '*'
                if test -z "$resource_type"
                    set completions (__fish_kubectl_print_resource_types)
                    set fzf_prompt "Resource type: "
                end
        end
    end

    # Output completions
    if test (count $completions) -eq 0
        return
    end

    if test "$kubectl_use_fzf" != "true"
        printf '%s\n' $completions
        return
    end

    # FZF selection
    if test "$show_preview" = "true"; and test -n "$preview_cmd"
        printf '%s\n' $completions | fzf --height=50% --prompt="$fzf_prompt" \
            --preview="$preview_cmd" \
            --preview-window=right:50%:wrap \
            --bind=ctrl-/:toggle-preview
    else
        printf '%s\n' $completions | fzf --height=40% --prompt="$fzf_prompt"
    end
end

# Toggle function
function kubectl_toggle_fzf --description "Toggle FZF mode for kubectl completions"
    if test "$kubectl_use_fzf" = "true"
        set -g kubectl_use_fzf false
        echo "kubectl FZF completions disabled"
    else
        set -g kubectl_use_fzf true
        echo "kubectl FZF completions enabled"
    end
end
