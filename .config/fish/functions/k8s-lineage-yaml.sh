#!/usr/bin/env bash
# k8s-lineage-yaml.sh - Generate YAML dependency graph for Kubernetes resources
# Usage: k8s-lineage-yaml.sh <resource_type> <resource_name> [namespace] [--detailed]

set -euo pipefail

resource_type="$1"
resource_name="$2"
namespace="${3:-default}"
detailed=false

# Check for --detailed flag
for arg in "$@"; do
    if [ "$arg" = "--detailed" ]; then
        detailed=true
        break
    fi
done

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

# Add detailed pod runtime info
if [ "$detailed" = true ] && [ "$kind" = "Pod" ]; then
    node_name=$(echo "$resource_json" | jq -r '.spec.nodeName // "N/A"')
    restart_count=$(echo "$resource_json" | jq -r '[.status.containerStatuses[]?.restartCount // 0] | add // 0')
    images_yaml=$(echo "$resource_json" | jq -r '
        [.spec.containers[].image] | unique |
        if length > 0 then
            map("    - \(.)") | join("\n")
        else
            "    []"
        end
    ')

    cat <<EOF
  node: $node_name
  restart_count: $restart_count
  images:
$images_yaml
EOF
fi

echo ""

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

# Find dependencies (what this resource depends on) - only for Pods
if [ "$kind" = "Pod" ]; then
    echo "dependencies:"

    # ServiceAccount
    sa_name=$(echo "$resource_json" | jq -r '.spec.serviceAccountName // "default"')
    echo "  service_account:"
    echo "    name: $sa_name"
    echo "    namespace: $ns"

    # Secrets - from volumes, env vars, and envFrom
    echo "  secrets:"
    secrets_found=false

    # Secrets from volumes
    while IFS= read -r secret_line; do
        if [ -n "$secret_line" ]; then
            secrets_found=true
            echo "$secret_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        .spec.volumes[]? | select(.secret != null) |
        "    - name: \(.secret.secretName)\n      namespace: \($ns)\n      usage: volume_mount"
    ' 2>/dev/null)

    # Secrets from env valueFrom
    while IFS= read -r secret_line; do
        if [ -n "$secret_line" ]; then
            secrets_found=true
            echo "$secret_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        [.spec.containers[]?.env[]? | select(.valueFrom.secretKeyRef != null) | .valueFrom.secretKeyRef.name] |
        unique | .[] |
        "    - name: \(.)\n      namespace: \($ns)\n      usage: env_var"
    ' 2>/dev/null)

    # Secrets from envFrom
    while IFS= read -r secret_line; do
        if [ -n "$secret_line" ]; then
            secrets_found=true
            echo "$secret_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        [.spec.containers[]?.envFrom[]? | select(.secretRef != null) | .secretRef.name] |
        unique | .[] |
        "    - name: \(.)\n      namespace: \($ns)\n      usage: env_from"
    ' 2>/dev/null)

    if [ "$secrets_found" = false ]; then
        echo "    []  # No secrets referenced"
    fi

    # ConfigMaps - from volumes, env vars, and envFrom
    echo "  config_maps:"
    cms_found=false

    # ConfigMaps from volumes
    while IFS= read -r cm_line; do
        if [ -n "$cm_line" ]; then
            cms_found=true
            echo "$cm_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        .spec.volumes[]? | select(.configMap != null) |
        "    - name: \(.configMap.name)\n      namespace: \($ns)\n      usage: volume_mount"
    ' 2>/dev/null)

    # ConfigMaps from env valueFrom
    while IFS= read -r cm_line; do
        if [ -n "$cm_line" ]; then
            cms_found=true
            echo "$cm_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        [.spec.containers[]?.env[]? | select(.valueFrom.configMapKeyRef != null) | .valueFrom.configMapKeyRef.name] |
        unique | .[] |
        "    - name: \(.)\n      namespace: \($ns)\n      usage: env_var"
    ' 2>/dev/null)

    # ConfigMaps from envFrom
    while IFS= read -r cm_line; do
        if [ -n "$cm_line" ]; then
            cms_found=true
            echo "$cm_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        [.spec.containers[]?.envFrom[]? | select(.configMapRef != null) | .configMapRef.name] |
        unique | .[] |
        "    - name: \(.)\n      namespace: \($ns)\n      usage: env_from"
    ' 2>/dev/null)

    if [ "$cms_found" = false ]; then
        echo "    []  # No configmaps referenced"
    fi

    # PersistentVolumeClaims
    echo "  persistent_volume_claims:"
    pvcs_found=false
    while IFS= read -r pvc_line; do
        if [ -n "$pvc_line" ]; then
            pvcs_found=true
            echo "$pvc_line"
        fi
    done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
        .spec.volumes[]? | select(.persistentVolumeClaim != null) |
        "    - name: \(.persistentVolumeClaim.claimName)\n      namespace: \($ns)"
    ' 2>/dev/null)

    if [ "$pvcs_found" = false ]; then
        echo "    []  # No PVCs referenced"
    fi

    # RBAC - find RoleBindings and ClusterRoleBindings referencing this ServiceAccount
    echo "  rbac:"
    rbac_found=false

    # RoleBindings in namespace
    while IFS= read -r rb_line; do
        if [ -n "$rb_line" ]; then
            rbac_found=true
            echo "$rb_line"
        fi
    done < <(kubectl get rolebindings -n "$ns" -o json 2>/dev/null | jq -r --arg sa "$sa_name" --arg ns "$ns" '
        .items[] |
        select(.subjects[]? | (.kind == "ServiceAccount" and .name == $sa and (.namespace == $ns or .namespace == null))) |
        "    - kind: RoleBinding\n      name: \(.metadata.name)\n      namespace: \(.metadata.namespace)\n      role: \(.roleRef.name)"
    ' 2>/dev/null)

    # ClusterRoleBindings
    while IFS= read -r crb_line; do
        if [ -n "$crb_line" ]; then
            rbac_found=true
            echo "$crb_line"
        fi
    done < <(kubectl get clusterrolebindings -o json 2>/dev/null | jq -r --arg sa "$sa_name" --arg ns "$ns" '
        .items[] |
        select(.subjects[]? | (.kind == "ServiceAccount" and .name == $sa and .namespace == $ns)) |
        "    - kind: ClusterRoleBinding\n      name: \(.metadata.name)\n      namespace: cluster-scoped\n      role: \(.roleRef.name)"
    ' 2>/dev/null)

    if [ "$rbac_found" = false ]; then
        echo "    []  # No RBAC bindings found"
    fi

    # ImagePullSecrets (detailed view only)
    if [ "$detailed" = true ]; then
        echo "  image_pull_secrets:"
        ips_found=false
        while IFS= read -r ips_line; do
            if [ -n "$ips_line" ]; then
                ips_found=true
                echo "$ips_line"
            fi
        done < <(echo "$resource_json" | jq -r --arg ns "$ns" '
            .spec.imagePullSecrets[]? |
            "    - name: \(.name)\n      namespace: \($ns)"
        ' 2>/dev/null)

        if [ "$ips_found" = false ]; then
            echo "    []  # No imagePullSecrets"
        fi
    fi

    echo ""
fi

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

    # NetworkPolicies and PDBs (detailed view only)
    if [ "$detailed" = true ]; then
        # NetworkPolicies that match this pod's labels
        echo "  network_policies:"
        np_found=false
        while IFS= read -r np_line; do
            if [ -n "$np_line" ]; then
                np_found=true
                echo "$np_line"
            fi
        done < <(kubectl get networkpolicies -n "$ns" -o json 2>/dev/null | jq -r --argjson podlabels "$pod_labels" '
            .items[] |
            select(
                .spec.podSelector.matchLabels // {} | to_entries |
                if length == 0 then true
                else all(. as $sel | $podlabels[$sel.key] == $sel.value)
                end
            ) |
            "    - name: \(.metadata.name)\n      namespace: \(.metadata.namespace)"
        ' 2>/dev/null)

        if [ "$np_found" = false ]; then
            echo "    []  # No network policies"
        fi

        # PodDisruptionBudgets that match this pod's labels
        echo "  pod_disruption_budgets:"
        pdb_found=false
        while IFS= read -r pdb_line; do
            if [ -n "$pdb_line" ]; then
                pdb_found=true
                echo "$pdb_line"
            fi
        done < <(kubectl get pdb -n "$ns" -o json 2>/dev/null | jq -r --argjson podlabels "$pod_labels" '
            .items[] |
            select(
                .spec.selector.matchLabels // {} | to_entries |
                all(. as $sel | $podlabels[$sel.key] == $sel.value)
            ) |
            "    - name: \(.metadata.name)\n      namespace: \(.metadata.namespace)\n      min_available: \(.spec.minAvailable // \"N/A\")\n      max_unavailable: \(.spec.maxUnavailable // \"N/A\")"
        ' 2>/dev/null)

        if [ "$pdb_found" = false ]; then
            echo "    []  # No PDBs"
        fi
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
