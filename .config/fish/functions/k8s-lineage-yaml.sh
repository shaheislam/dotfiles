#!/usr/bin/env bash
# k8s-lineage-yaml.sh - Generate YAML dependency graph for Kubernetes resources
# Usage: k8s-lineage-yaml.sh <resource_type> <resource_name> [namespace]

set -euo pipefail

resource_type="$1"
resource_name="$2"
namespace="${3:-default}"

# Get resource JSON
resource_json=$(kubectl get "$resource_type" "$resource_name" -n "$namespace" -o json 2>/dev/null)
if [ -z "$resource_json" ]; then
    echo "Error: Could not find $resource_type/$resource_name in namespace $namespace"
    exit 1
fi

# Extract basic info
kind=$(echo "$resource_json" | jq -r '.kind')
name=$(echo "$resource_json" | jq -r '.metadata.name')
ns=$(echo "$resource_json" | jq -r '.metadata.namespace // "N/A"')
status=$(echo "$resource_json" | jq -r '.status.phase // .status.conditions[0].type // "N/A"')
creation=$(echo "$resource_json" | jq -r '.metadata.creationTimestamp // "N/A"')

# Get labels as YAML
labels_yaml=$(echo "$resource_json" | jq -r '
  .metadata.labels // {} | to_entries |
  if length > 0 then
    map("    \(.key): \(.value)") | join("\n")
  else
    "    none: true"
  end
')

# Start YAML output
cat <<EOF
# Dependency Graph for $kind/$resource_name
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

resource:
  kind: $kind
  name: $name
  namespace: $ns
  status: $status
  created: $creation
  labels:
$labels_yaml

EOF

# Walk ownership chain (parents)
echo "ownership_chain:"
current_json="$resource_json"
has_owners=false
while true; do
    owner=$(echo "$current_json" | jq -r '.metadata.ownerReferences[0] // empty')
    [ -z "$owner" ] && break
    has_owners=true

    owner_kind=$(echo "$owner" | jq -r '.kind')
    owner_name=$(echo "$owner" | jq -r '.name')
    owner_api=$(echo "$owner" | jq -r '.apiVersion')

    # Get owner status
    owner_json=$(kubectl get "$owner_kind" "$owner_name" -n "$ns" -o json 2>/dev/null || echo "{}")
    owner_status=$(echo "$owner_json" | jq -r '.status.conditions[0].type // .status.phase // "N/A"')

    cat <<EOF
  - kind: $owner_kind
    name: $owner_name
    apiVersion: $owner_api
    status: $owner_status
EOF

    current_json="$owner_json"
    [ -z "$current_json" ] || [ "$current_json" = "{}" ] && break
done

if [ "$has_owners" = false ]; then
    echo "  []  # No owner references"
fi

echo ""

# Find dependents based on resource type
echo "dependents:"

# For Pods - find services that select this pod
if [ "$kind" = "Pod" ]; then
    pod_labels=$(echo "$resource_json" | jq -r '.metadata.labels // {}')

    echo "  services:"
    services_found=false
    while IFS= read -r svc_line; do
        if [ -n "$svc_line" ]; then
            services_found=true
            echo "$svc_line"
        fi
    done < <(kubectl get svc -n "$ns" -o json 2>/dev/null | jq -r --argjson podlabels "$pod_labels" '
        .items[] |
        select(.spec.selector != null) |
        select(
            .spec.selector | to_entries |
            all(. as $sel | $podlabels[$sel.key] == $sel.value)
        ) |
        "    - name: \(.metadata.name)\n      type: \(.spec.type)\n      ports: \([.spec.ports[].port] | join(\", \"))"
    ' 2>/dev/null)

    if [ "$services_found" = false ]; then
        echo "    []  # No services selecting this pod"
    fi

    # Find EndpointSlices
    echo "  endpoint_slices:"
    eps_found=false
    while IFS= read -r eps_line; do
        if [ -n "$eps_line" ]; then
            eps_found=true
            echo "$eps_line"
        fi
    done < <(kubectl get endpointslices -n "$ns" -o json 2>/dev/null | jq -r --arg podname "$name" '
        .items[] |
        select(.endpoints[]?.targetRef.name == $podname) |
        "    - name: \(.metadata.name)\n      addressType: \(.addressType)"
    ' 2>/dev/null)

    if [ "$eps_found" = false ]; then
        echo "    []  # No endpoint slices"
    fi
fi

# For Services - find pods and ingresses
if [ "$kind" = "Service" ]; then
    selector=$(echo "$resource_json" | jq -r '.spec.selector // {} | to_entries | map("\(.key)=\(.value)") | join(",")')

    echo "  pods:"
    if [ -n "$selector" ]; then
        kubectl get pods -n "$ns" -l "$selector" -o json 2>/dev/null | jq -r '
            .items[] |
            "    - name: \(.metadata.name)\n      status: \(.status.phase)\n      ready: \([.status.containerStatuses[]? | select(.ready)] | length)/\([.status.containerStatuses[]?] | length)"
        ' 2>/dev/null || echo "    []"
    else
        echo "    []  # No selector defined"
    fi

    echo "  ingresses:"
    kubectl get ingress -n "$ns" -o json 2>/dev/null | jq -r --arg svcname "$name" '
        .items[] |
        select(.spec.rules[]?.http.paths[]?.backend.service.name == $svcname) |
        "    - name: \(.metadata.name)\n      hosts: \([.spec.rules[].host] | join(\", \"))"
    ' 2>/dev/null || echo "    []"
fi

# For Deployments/ReplicaSets - find pods
if [ "$kind" = "Deployment" ] || [ "$kind" = "ReplicaSet" ] || [ "$kind" = "StatefulSet" ] || [ "$kind" = "DaemonSet" ]; then
    selector=$(echo "$resource_json" | jq -r '.spec.selector.matchLabels // {} | to_entries | map("\(.key)=\(.value)") | join(",")')

    echo "  pods:"
    if [ -n "$selector" ]; then
        kubectl get pods -n "$ns" -l "$selector" -o json 2>/dev/null | jq -r '
            .items[] |
            "    - name: \(.metadata.name)\n      status: \(.status.phase)\n      node: \(.spec.nodeName // \"N/A\")"
        ' 2>/dev/null || echo "    []"
    else
        echo "    []"
    fi
fi

# Generic empty dependents for other types
if [ "$kind" != "Pod" ] && [ "$kind" != "Service" ] && [ "$kind" != "Deployment" ] && [ "$kind" != "ReplicaSet" ] && [ "$kind" != "StatefulSet" ] && [ "$kind" != "DaemonSet" ]; then
    echo "  []  # Dependent discovery not implemented for $kind"
fi
