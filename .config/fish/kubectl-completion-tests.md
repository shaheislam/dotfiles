# Kubectl Enhanced Completions - Test Validation Checklist

## Setup
```bash
# Reload Fish configuration
source ~/.config/fish/config.fish

# Check functions are loaded
functions | grep kubectl
# Should show: kubectl_enhanced_complete, kubectl_fzf_complete, kubectl_simple_complete

# Enable FZF mode (optional)
set -g kubectl_use_fzf true
# Or use the alias: kfzf
```

## 1. Basic Completion Tests

### 1.1 Subcommand Completion
```bash
kubectl [TAB]
# Expected: List of subcommands (get, describe, create, apply, delete, logs, exec, etc.)

k [TAB]
# Expected: Same as above (alias should work)
```

### 1.2 Resource Type Completion
```bash
kubectl get [TAB]
# Expected: List of resource types (pods, services, deployments, etc.)

kubectl describe [TAB]
# Expected: Same resource type list

kubectl delete [TAB]
# Expected: Same resource type list
```

## 2. Namespace Tests

### 2.1 Namespace Completion
```bash
kubectl -n [TAB]
# Expected: List of available namespaces

kubectl --namespace [TAB]
# Expected: Same namespace list
```

### 2.2 Namespace-Aware Resource Completion
```bash
kubectl -n kube-system get pods [TAB]
# Expected: Pods from kube-system namespace only

kubectl get pods --namespace default [TAB]
# Expected: Pods from default namespace only

kubectl get pods -A [TAB]
# Expected: Pods from all namespaces
```

## 3. Resource-Specific Tests

### 3.1 Pod Operations
```bash
kubectl logs [TAB]
# Expected: List of all pods in current namespace

kubectl exec [TAB]
# Expected: List of running pods only

kubectl port-forward [TAB]
# Expected: List of running pods
```

### 3.2 Deployment Operations
```bash
kubectl get deployments [TAB]
# Expected: List of deployments

kubectl scale deployment [TAB]
# Expected: List of deployments

kubectl rollout restart deployment [TAB]
# Expected: List of deployments
```

### 3.3 Service Operations
```bash
kubectl get services [TAB]
# Expected: List of services

kubectl describe service [TAB]
# Expected: List of services

kubectl port-forward service/[TAB]
# Expected: List of services (for port-forward)
```

## 4. Advanced Context Tests

### 4.1 Rollout Commands
```bash
kubectl rollout [TAB]
# Expected: status, history, undo, restart, pause, resume

kubectl rollout restart [TAB]
# Expected: deployment, daemonset, statefulset

kubectl rollout restart deployment [TAB]
# Expected: List of deployments
```

### 4.2 Scale Commands
```bash
kubectl scale [TAB]
# Expected: deployment, statefulset, replicaset

kubectl scale deployment [TAB]
# Expected: List of deployments

kubectl scale deployment my-app --replicas [TAB]
# Expected: Nothing or flag suggestions
```

### 4.3 Top Commands
```bash
kubectl top [TAB]
# Expected: nodes, pods

kubectl top nodes [TAB]
# Expected: List of nodes

kubectl top pods [TAB]
# Expected: List of pods
```

## 5. File and Flag Completion

### 5.1 File Completion
```bash
kubectl apply -f [TAB]
# Expected: List of .yaml, .yml, .json files in current/subdirectories

kubectl create -f [TAB]
# Expected: Same file list
```

### 5.2 Output Format Completion
```bash
kubectl get pods -o [TAB]
# Expected: yaml, json, wide, name, custom-columns=, jsonpath=, go-template

kubectl get deployment --output [TAB]
# Expected: Same output format list
```

### 5.3 Context-Aware Flags
```bash
kubectl logs [select a pod] [TAB]
# Expected: Log-specific flags (--follow, -f, --tail, --since, --timestamps, --previous, -p)

kubectl exec [select a pod] [TAB]
# Expected: Exec flags (-it, -i, -t, --container, -c)

kubectl scale deployment [select deployment] [TAB]
# Expected: Scale flags (--replicas, --current-replicas, --timeout)
```

## 6. Alias Integration Tests

### 6.1 kubectl Aliases
```bash
kgpo [TAB]
# Expected: List of pods (kgpo = kubectl get pods)

klo [TAB]
# Expected: List of pods (klo = kubectl logs -f)

kdpo [TAB]
# Expected: List of pods (kdpo = kubectl describe pods)
```

### 6.2 FZF Helper Aliases
```bash
kgpf
# Expected: Opens FZF to select pod, then describes it

klf
# Expected: Opens FZF to select pod, then shows logs

kexf
# Expected: Opens FZF to select pod, then exec into it
```

## 7. FZF Mode Tests (if enabled)

### 7.1 Toggle FZF Mode
```bash
kubectl_toggle_fzf
# Or use: kfzf
# Expected: Message showing FZF mode enabled/disabled
```

### 7.2 FZF Selection with Preview
```bash
# With FZF enabled
kubectl get pods [TAB]
# Expected: FZF selector with preview showing pod details (describe output)

kubectl describe deployment [TAB]
# Expected: FZF selector with deployment preview
```

### 7.3 FZF without Preview (flags/subcommands)
```bash
kubectl [TAB]
# Expected: FZF selector without preview (selecting subcommands)

kubectl logs my-pod [TAB]
# Expected: FZF selector for flags without preview
```

## 8. Edge Cases and Error Handling

### 8.1 No Resources Available
```bash
kubectl get pods [TAB]  # In empty namespace
# Expected: No completions or empty list

kubectl -n non-existent-ns get pods [TAB]
# Expected: No completions (namespace doesn't exist)
```

### 8.2 Mixed Singular/Plural
```bash
kubectl get pod [TAB]
# Expected: List of pods (handles singular)

kubectl get deployment [TAB]
# Expected: List of deployments (handles singular)
```

### 8.3 Short Names
```bash
kubectl get svc [TAB]
# Expected: List of services

kubectl get deploy [TAB]
# Expected: List of deployments

kubectl get cm [TAB]
# Expected: List of configmaps
```

## 9. Performance Tests

### 9.1 Response Time
```bash
time fish -c "kubectl get pods [TAB]"
# Expected: < 500ms for reasonable number of resources

time fish -c "kubectl get pods -A [TAB]"
# Expected: < 1s even for all namespaces
```

### 9.2 Large Resource Lists
```bash
# In namespace with many pods
kubectl get pods [TAB]
# Expected: Handles 100+ pods smoothly
```

## 10. Integration Tests

### 10.1 Works with kubectl Wrapper
```bash
kubectl get pods
# Expected: Opens FZF for selection (from wrapper)

kubectl get pods specific-pod
# Expected: Shows specific pod directly (no FZF from wrapper)
```

### 10.2 Works with kubecolor
```bash
kubecolor get pods [TAB]
# Expected: Completions work the same as kubectl
```

### 10.3 fifc Integration
```bash
# Ensure TAB still works for other commands
git [TAB]
# Expected: Git completions still work

docker [TAB]
# Expected: Docker completions still work
```

## Troubleshooting

If completions aren't working:

1. **Check functions are loaded**:
   ```bash
   functions | grep kubectl_enhanced
   ```

2. **Test function directly**:
   ```bash
   kubectl_enhanced_complete
   ```

3. **Check completion registration**:
   ```bash
   complete -c kubectl | grep smart
   ```

4. **Enable debug output**:
   ```bash
   set -g fish_trace 1
   kubectl get pods [TAB]
   set -e fish_trace
   ```

5. **Check kubectl access**:
   ```bash
   kubectl get pods  # Should work
   kubectl get namespaces  # Should list namespaces
   ```

## Success Criteria

✅ All basic completions work (subcommands, resources, namespaces)
✅ Context-aware completions provide relevant options
✅ Namespace filtering works correctly
✅ File completions find YAML/JSON files
✅ Flag completions are context-specific
✅ FZF mode can be toggled on/off
✅ FZF preview shows relevant information
✅ Aliases work with completions
✅ Performance is acceptable (< 500ms typical)
✅ No conflicts with other completions (git, docker, etc.)
✅ Works with kubectl wrapper and kubecolor