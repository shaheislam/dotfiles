# k8s-sched - Simulate pod scheduling and predict which nodes can run a workload
# Shows detailed constraint checks with visual resource utilization bars

function k8s-sched --description "Simulate pod scheduling - predict which nodes can run a pod"
    set -l resource_type ""
    set -l resource_name ""
    set -l namespace (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
    if test -z "$namespace"
        set namespace "default"
    end

    # Parse arguments
    set -l show_help false
    set -l all_namespaces false

    for arg in $argv
        switch $arg
            case -h --help
                set show_help true
            case -A --all-namespaces
                set all_namespaces true
            case -n
                # Next arg is namespace (handled in next iteration)
                continue
            case '*'
                if test -z "$resource_name"
                    # Check if it's namespace value after -n
                    if test "$arg" != "-n"
                        set resource_name $arg
                    end
                end
        end
    end

    if test "$show_help" = true
        echo "Usage: k8s-sched [options] [pod/deployment name]"
        echo ""
        echo "Simulate pod scheduling to predict which nodes can run a workload."
        echo ""
        echo "Options:"
        echo "  -n <namespace>     Specify namespace"
        echo "  -A, --all-namespaces  Search all namespaces"
        echo "  -h, --help         Show this help"
        echo ""
        echo "Example:"
        echo "  k8s-sched                    # Interactive selection"
        echo "  k8s-sched nginx-pod          # Check specific pod"
        echo "  k8s-sched -n kube-system     # Select from kube-system namespace"
        return 0
    end

    # If no resource specified, select interactively
    if test -z "$resource_name"
        set -l ns_flag "-n $namespace"
        if test "$all_namespaces" = true
            set ns_flag "-A"
        end

        # Show combined list of pods and deployments
        set -l selection (begin
            kubectl get pods $ns_flag -o custom-columns=TYPE:kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace --no-headers 2>/dev/null | sed 's/^/pod\//'
            kubectl get deployments $ns_flag -o custom-columns=TYPE:kind,NAME:.metadata.name,NAMESPACE:.metadata.namespace --no-headers 2>/dev/null | sed 's/^/deploy\//'
        end | fzf --height=50% --prompt="Select workload: " \
            --header="Select a pod or deployment to analyze scheduling" \
            --preview="kubectl get {1} -n {3} -o yaml 2>/dev/null | bat --color=always -l yaml")

        if test -z "$selection"
            echo "No selection made."
            return 1
        end

        # Parse selection
        set -l parts (string split ' ' $selection)
        set resource_name (string split '/' $parts[1])[2]
        set resource_type (string split '/' $parts[1])[1]
        set namespace $parts[3]
    else
        # Determine resource type
        if kubectl get pod $resource_name -n $namespace &>/dev/null
            set resource_type "pod"
        else if kubectl get deployment $resource_name -n $namespace &>/dev/null
            set resource_type "deploy"
        else
            echo "Error: Resource '$resource_name' not found as pod or deployment in namespace '$namespace'"
            return 1
        end
    end

    echo ""
    set_color cyan
    echo "Analyzing scheduling constraints for $resource_type/$resource_name in namespace $namespace..."
    set_color normal
    echo ""

    # Get pod spec (from deployment template if needed)
    set -l pod_spec
    if test "$resource_type" = "deploy"
        set pod_spec (kubectl get deployment $resource_name -n $namespace -o json 2>/dev/null | jq '.spec.template.spec')
    else
        set pod_spec (kubectl get pod $resource_name -n $namespace -o json 2>/dev/null | jq '.spec')
    end

    if test -z "$pod_spec"
        echo "Error: Could not get spec for $resource_type/$resource_name"
        return 1
    end

    # Extract scheduling constraints
    set -l node_selector (echo $pod_spec | jq -r '.nodeSelector // {} | to_entries | map("\(.key)=\(.value)") | join(",")')
    set -l tolerations (echo $pod_spec | jq -c '.tolerations // []')
    set -l affinity (echo $pod_spec | jq -c '.affinity // {}')

    # Extract resource requests (sum of all containers)
    set -l cpu_request (echo $pod_spec | jq -r '[.containers[].resources.requests.cpu // "0"] | map(
        if test(\"m$\") then (rtrimstr(\"m\") | tonumber)
        elif test(\"[0-9]+$\") then (tonumber * 1000)
        else 0 end
    ) | add')
    set -l mem_request (echo $pod_spec | jq -r '[.containers[].resources.requests.memory // "0"] | map(
        if test(\"Gi$\") then (rtrimstr(\"Gi\") | tonumber * 1024)
        elif test(\"Mi$\") then (rtrimstr(\"Mi\") | tonumber)
        elif test(\"Ki$\") then (rtrimstr(\"Ki\") | tonumber / 1024)
        else 0 end
    ) | add')

    # Display extracted constraints
    set_color yellow
    echo "=== Scheduling Constraints ==="
    set_color normal
    echo "Node Selector: "(test -n "$node_selector" && echo "$node_selector" || echo "none")
    echo "CPU Request:   $cpu_request""m"
    echo "Memory Request: $mem_request""Mi"
    echo "Tolerations:   "(echo $tolerations | jq -r 'length')
    echo "Has Affinity:  "(test "$affinity" != "{}" && echo "yes" || echo "no")
    echo ""

    # Get all nodes with their details
    set_color yellow
    echo "=== Node Scheduling Analysis ==="
    set_color normal
    echo ""

    # Header
    printf "%-25s %-8s %-14s %-14s %s\n" "NODE" "STATUS" "CPU" "MEMORY" "CONSTRAINTS"
    echo "────────────────────────────────────────────────────────────────────────────────"

    # Process each node
    kubectl get nodes -o json 2>/dev/null | jq -c '.items[]' | while read -l node_json
        set -l node_name (echo $node_json | jq -r '.metadata.name')
        set -l node_labels (echo $node_json | jq -c '.metadata.labels // {}')
        set -l node_taints (echo $node_json | jq -c '.spec.taints // []')
        set -l node_unschedulable (echo $node_json | jq -r '.spec.unschedulable // false')

        # Get node capacity and allocatable
        set -l cpu_allocatable (echo $node_json | jq -r '.status.allocatable.cpu' | string replace -r 'm$' '' | string replace -r '^([0-9]+)$' '$1000')
        set -l mem_allocatable_raw (echo $node_json | jq -r '.status.allocatable.memory')
        set -l mem_allocatable (echo $mem_allocatable_raw | awk '{
            if (/Ki$/) { gsub(/Ki$/,""); printf "%.0f", $0/1024 }
            else if (/Mi$/) { gsub(/Mi$/,""); print }
            else if (/Gi$/) { gsub(/Gi$/,""); printf "%.0f", $0*1024 }
            else { printf "%.0f", $0/1024/1024 }
        }')

        # Get current resource usage on node (sum of all pod requests)
        set -l current_cpu (kubectl get pods --all-namespaces --field-selector=spec.nodeName=$node_name -o json 2>/dev/null | jq -r '[.items[].spec.containers[].resources.requests.cpu // "0"] | map(
            if test(\"m$\") then (rtrimstr(\"m\") | tonumber)
            elif test(\"[0-9]+$\") then (tonumber * 1000)
            else 0 end
        ) | add')
        set -l current_mem (kubectl get pods --all-namespaces --field-selector=spec.nodeName=$node_name -o json 2>/dev/null | jq -r '[.items[].spec.containers[].resources.requests.memory // "0"] | map(
            if test(\"Gi$\") then (rtrimstr(\"Gi\") | tonumber * 1024)
            elif test(\"Mi$\") then (rtrimstr(\"Mi\") | tonumber)
            elif test(\"Ki$\") then (rtrimstr(\"Ki\") | tonumber / 1024)
            else 0 end
        ) | add')

        # Calculate utilization percentages
        set -l cpu_util (math "round(($current_cpu / $cpu_allocatable) * 100)" 2>/dev/null || echo 0)
        set -l mem_util (math "round(($current_mem / $mem_allocatable) * 100)" 2>/dev/null || echo 0)

        # Calculate if there's room for the new pod
        set -l cpu_after (math "$current_cpu + $cpu_request" 2>/dev/null || echo 0)
        set -l mem_after (math "$current_mem + $mem_request" 2>/dev/null || echo 0)

        # Check constraints
        set -l constraints ""
        set -l can_schedule true
        set -l is_warning false

        # Check if node is unschedulable (cordoned)
        if test "$node_unschedulable" = "true"
            set constraints "$constraints ✗ Cordoned"
            set can_schedule false
        end

        # Check node selector
        if test -n "$node_selector"
            set -l selector_match true
            for selector in (string split ',' $node_selector)
                set -l key (string split '=' $selector)[1]
                set -l value (string split '=' $selector)[2]
                set -l node_value (echo $node_labels | jq -r --arg k "$key" '.[$k] // ""')
                if test "$node_value" != "$value"
                    set selector_match false
                    break
                end
            end
            if test "$selector_match" = "false"
                set constraints "$constraints ✗ Selector mismatch"
                set can_schedule false
            end
        end

        # Check taints/tolerations
        set -l taint_count (echo $node_taints | jq -r 'length')
        if test "$taint_count" -gt 0
            for taint in (echo $node_taints | jq -c '.[]')
                set -l taint_key (echo $taint | jq -r '.key')
                set -l taint_effect (echo $taint | jq -r '.effect')

                # Check if pod tolerates this taint
                set -l tolerated (echo $tolerations | jq -r --arg k "$taint_key" '[.[] | select(.key == $k or .operator == "Exists")] | length')
                if test "$tolerated" -eq 0
                    if test "$taint_effect" = "NoSchedule"
                        set constraints "$constraints ✗ Taint: $taint_key"
                        set can_schedule false
                    else if test "$taint_effect" = "PreferNoSchedule"
                        set constraints "$constraints ⚠ PreferNoSchedule: $taint_key"
                        set is_warning true
                    end
                end
            end
        end

        # Check CPU capacity
        if test "$cpu_after" -gt "$cpu_allocatable"
            set constraints "$constraints ✗ Insufficient CPU"
            set can_schedule false
        end

        # Check memory capacity
        if test "$mem_after" -gt "$mem_allocatable"
            set constraints "$constraints ✗ Insufficient memory"
            set can_schedule false
        end

        # Default constraint message
        if test -z "$constraints"
            set constraints "All checks passed"
        end

        # Build progress bars
        set -l cpu_bar (_k8s_sched_progress_bar $cpu_util)
        set -l mem_bar (_k8s_sched_progress_bar $mem_util)

        # Determine status and color
        set -l status_icon
        set -l status_color
        if test "$can_schedule" = true
            if test "$is_warning" = true
                set status_icon "⚠️ WARN"
                set status_color yellow
            else
                set status_icon "✅ OK"
                set status_color green
            end
        else
            set status_icon "❌ FAIL"
            set status_color red
        end

        # Print node row
        set_color $status_color
        printf "%-25s %-8s " (string sub -l 25 $node_name) $status_icon
        set_color blue
        printf "%s %3d%%  %s %3d%%  " $cpu_bar $cpu_util $mem_bar $mem_util
        set_color $status_color
        printf "%s\n" (string trim $constraints)
        set_color normal
    end

    echo ""
    echo "Legend: ✅ Can schedule | ⚠️ Can schedule with warnings | ❌ Cannot schedule"
    echo ""
end

# Helper function to generate progress bar
function _k8s_sched_progress_bar --description "Generate a visual progress bar"
    set -l percent $argv[1]
    set -l width 7
    set -l filled (math "round($percent / 100 * $width)")
    set -l empty (math "$width - $filled")

    set -l bar ""
    for i in (seq 1 $filled)
        set bar "$bar▓"
    end
    for i in (seq 1 $empty)
        set bar "$bar░"
    end
    echo $bar
end

# Fish completions for k8s-sched
complete -c k8s-sched -f
complete -c k8s-sched -s h -l help -d "Show help"
complete -c k8s-sched -s n -x -a "(kubectl get namespaces -o name 2>/dev/null | sed 's|namespace/||')" -d "Namespace"
complete -c k8s-sched -s A -l all-namespaces -d "Search all namespaces"
complete -c k8s-sched -a "(kubectl get pods -o name 2>/dev/null | sed 's|pod/||'; kubectl get deployments -o name 2>/dev/null | sed 's|deployment.apps/||')" -d "Pod or deployment name"
