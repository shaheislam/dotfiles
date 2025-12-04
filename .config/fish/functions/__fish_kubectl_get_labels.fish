# Helper function to get available labels for kubectl -l completion
# Returns label keys or label key=value pairs for fzf selection

function __fish_kubectl_get_labels --description "Get available labels for kubectl selector completion"
    set -l resource_type $argv[1]
    set -l current_value $argv[2]

    # Default to pods if no resource type specified
    if test -z "$resource_type"
        set resource_type pods
    end

    # Check if we're completing a value (has = in current)
    if string match -q '*=*' "$current_value"
        # Extract the key part before =
        set -l label_key (string split '=' "$current_value")[1]

        # Get unique values for this specific label key
        # Use jsonpath to get all values for the label
        kubectl get $resource_type -A -o jsonpath="{.items[*].metadata.labels.$label_key}" 2>/dev/null \
            | tr ' ' '\n' \
            | sort -u \
            | while read -l val
                if test -n "$val"
                    echo "$label_key=$val"
                end
            end
    else
        # Get unique label keys across all resources
        kubectl get $resource_type -A -o json 2>/dev/null \
            | jq -r '.items[].metadata.labels // {} | keys[]' 2>/dev/null \
            | sort -u \
            | while read -l key
                if test -n "$key"
                    # Output key= to prompt for value completion
                    echo "$key="
                end
            end
    end
end

function __fish_kubectl_get_common_labels --description "Get common/well-known Kubernetes labels"
    # Well-known Kubernetes labels that are commonly used
    echo "app="
    echo "app.kubernetes.io/name="
    echo "app.kubernetes.io/instance="
    echo "app.kubernetes.io/version="
    echo "app.kubernetes.io/component="
    echo "app.kubernetes.io/part-of="
    echo "app.kubernetes.io/managed-by="
    echo "helm.sh/chart="
    echo "helm.sh/release-name="
    echo "kubernetes.io/name="
    echo "k8s-app="
    echo "tier="
    echo "environment="
    echo "env="
    echo "release="
    echo "version="
end
