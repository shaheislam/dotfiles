# k8s-multi - Search across multiple Kubernetes clusters with fzf selection
# Runs kubectl commands against multiple contexts in parallel

function k8s-multi --description "Search across multiple Kubernetes clusters"
    set -l show_help false
    set -l kubectl_args

    # Check for help flag first
    if contains -- -h $argv; or contains -- --help $argv
        set show_help true
    else
        set kubectl_args $argv
    end

    if test "$show_help" = true; or test (count $kubectl_args) -eq 0
        echo "Usage: k8s-multi <kubectl command>"
        echo ""
        echo "Search across multiple Kubernetes clusters in parallel."
        echo "First, select clusters with fzf, then run the command against all selected contexts."
        echo ""
        echo "Examples:"
        echo "  k8s-multi get pods                    # Get pods from multiple clusters"
        echo "  k8s-multi get deployments             # Get deployments from multiple clusters"
        echo "  k8s-multi get pods -l app=nginx       # Get pods with label selector"
        echo "  k8s-multi get nodes                   # Get nodes from multiple clusters"
        echo "  k8s-multi get pods -A                 # Get pods from all namespaces across clusters"
        echo ""
        echo "Interactive features:"
        echo "  - Multi-select clusters with TAB"
        echo "  - Preview shows current context info"
        echo "  - Results aggregated with cluster prefix"
        echo "  - Alt+4 to describe selected resource"
        echo "  - Alt+5 to view logs (for pods)"
        echo ""
        return 0
    end

    # Get all available contexts
    set -l contexts (kubectl config get-contexts -o name 2>/dev/null)
    if test (count $contexts) -eq 0
        echo "Error: No Kubernetes contexts found."
        return 1
    end

    # Select contexts with fzf
    set_color cyan
    echo "Select clusters to query (TAB to multi-select, ENTER to confirm):"
    set_color normal

    set -l selected_contexts (printf '%s\n' $contexts | fzf --height=50% --multi \
        --bind 'tab:toggle+down,shift-tab:toggle+up' \
        --header 'TAB: select multiple clusters, ENTER: confirm' \
        --prompt="Clusters: " \
        --preview="kubectl config get-contexts {} 2>/dev/null | bat --color=always --style=plain -l yaml")

    if test (count $selected_contexts) -eq 0
        echo "No clusters selected."
        return 1
    end

    echo ""
    set_color yellow
    echo "Querying "(count $selected_contexts)" cluster(s): "(string join ', ' $selected_contexts)
    set_color normal
    echo "Command: kubectl $kubectl_args"
    echo ""

    # Create temp directory for results
    set -l tmp_dir (mktemp -d)
    set -l pids

    # Run kubectl against each context in parallel
    for ctx in $selected_contexts
        begin
            # Run kubectl with context
            set -l output (kubectl --context=$ctx $kubectl_args 2>&1)
            set -l exit_code $status

            # Format output with cluster prefix
            if test $exit_code -eq 0
                # Add cluster column to output
                echo $output | while read -l line
                    # Skip header for non-first cluster (detect by first char not being NAME)
                    if test -n "$line"
                        printf "%-20s %s\n" (string sub -l 20 $ctx) "$line"
                    end
                end > "$tmp_dir/$ctx.out"
            else
                echo "[$ctx] Error: $output" > "$tmp_dir/$ctx.out"
            end
        end &
        set -a pids $last_pid
    end

    # Wait for all background jobs
    for pid in $pids
        wait $pid 2>/dev/null
    end

    # Aggregate and display results
    set -l header_printed false

    # Print header
    printf "%-20s " "CLUSTER"

    # Get header from first successful result
    for ctx in $selected_contexts
        if test -f "$tmp_dir/$ctx.out"
            set -l first_line (head -1 "$tmp_dir/$ctx.out")
            # Extract the original header (everything after cluster column)
            set -l original_header (echo "$first_line" | awk '{$1=""; print substr($0,2)}')
            echo "$original_header"
            break
        end
    end

    echo "────────────────────────────────────────────────────────────────────────────────"

    # Combine all results (skip headers after first)
    set -l all_results
    set -l skip_count 0
    for ctx in $selected_contexts
        if test -f "$tmp_dir/$ctx.out"
            set -l line_num 0
            cat "$tmp_dir/$ctx.out" | while read -l line
                set line_num (math $line_num + 1)
                # Skip header line (usually line 1) for non-first contexts
                if test $skip_count -gt 0; and test $line_num -eq 1
                    continue
                end
                echo "$line"
            end
            set skip_count (math $skip_count + 1)
        end
    end

    # Cleanup
    rm -rf "$tmp_dir"

    echo ""
    set_color cyan
    echo "Tip: Use k8s-multi with fzf actions on specific resources"
    set_color normal
end

# Alternative version that pipes to fzf for resource selection
function k8s-multi-fzf --description "Multi-cluster search with fzf resource selection"
    set -l kubectl_args $argv

    if test (count $kubectl_args) -eq 0
        echo "Usage: k8s-multi-fzf <kubectl get command>"
        echo "Example: k8s-multi-fzf get pods"
        return 1
    end

    # Get all available contexts
    set -l contexts (kubectl config get-contexts -o name 2>/dev/null)

    # Select contexts
    set -l selected_contexts (printf '%s\n' $contexts | fzf --height=40% --multi \
        --bind 'tab:toggle+down,shift-tab:toggle+up' \
        --header 'Select clusters' \
        --prompt="Clusters: ")

    if test (count $selected_contexts) -eq 0
        return 1
    end

    # Create temp file for results
    set -l tmp_file (mktemp)
    set -l pids

    # Run queries in parallel
    for ctx in $selected_contexts
        begin
            kubectl --context=$ctx $kubectl_args -o custom-columns=CLUSTER:metadata.name,NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase 2>/dev/null | \
                tail -n +2 | \
                sed "s/^/$ctx\t/" >> "$tmp_file"
        end &
        set -a pids $last_pid
    end

    # Wait for all jobs
    for pid in $pids
        wait $pid 2>/dev/null
    end

    # Display results in fzf with actions
    set -l selected (cat "$tmp_file" | fzf --height=60% \
        --header 'CLUSTER     NAMESPACE   NAME                  STATUS' \
        --prompt="Select resource: " \
        --preview="kubectl --context={1} get {4} -n {2} -o yaml 2>/dev/null | bat --color=always -l yaml" \
        --bind "alt-4:execute(kubectl --context={1} describe {4} -n {2} | less)" \
        --bind "alt-5:execute(kubectl --context={1} logs -f {4} -n {2})" \
        --bind "alt-2:execute(kubectl --context={1} exec -it {4} -n {2} -- sh < /dev/tty > /dev/tty)")

    rm -f "$tmp_file"

    if test -n "$selected"
        set -l parts (string split \t $selected)
        set -l ctx $parts[1]
        set -l ns $parts[2]
        set -l name $parts[3]
        echo "Selected: $name in namespace $ns on cluster $ctx"
    end
end

# Fish completions for k8s-multi
complete -c k8s-multi -f
complete -c k8s-multi -s h -l help -d "Show help"
complete -c k8s-multi -a "get describe logs exec delete" -d "kubectl command"

complete -c k8s-multi-fzf -f
complete -c k8s-multi-fzf -a "get" -d "kubectl get command"
