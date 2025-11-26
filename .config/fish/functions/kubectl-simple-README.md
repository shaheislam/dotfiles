# kubectl FZF Native Completions for Fish

## Overview

FZF-powered kubectl completions that leverage native `__fish_kubectl_*` functions from the official kubectl completions. This provides the best of both worlds: comprehensive native completion support with FZF's interactive selection.

## Architecture

```
kubectl-simple.fish (entry point)
  ↓ __kubectl_smart_complete()
  ↓
kubectl_fzf_native.fish (FZF wrapper)
  ↓
kubectl.fish (native 226K comprehensive completions)
  ├── __fish_kubectl_print_resource
  ├── __fish_kubectl_print_pod_containers
  ├── __fish_kubectl_print_resource_ports
  ├── __fish_kubectl_print_resource_types
  ├── __fish_kubectl_get_config
  └── ... (many more native functions)
```

## Features

- **FZF interactive selection**: Fuzzy search for pods, resources, namespaces
- **Preview windows**: See resource details while selecting
- **Container completion**: `-c` flag completes actual container names
- **Port completion**: port-forward shows actual port numbers
- **CRD support**: Custom Resource Definitions with 30s caching
- **All resource types**: Native completions cover all kubectl resources
- **Toggle support**: `kubectl_toggle_fzf` to switch FZF on/off

## What it completes

| Context | Completions | Preview |
|---------|-------------|---------|
| `kubectl logs [TAB]` | Pods | Pod description |
| `kubectl logs pod -c [TAB]` | Container names | - |
| `kubectl exec [TAB]` | Pods | Pod details |
| `kubectl port-forward [TAB]` | Pods, svc/, deploy/ | Resource details |
| `kubectl port-forward pod [TAB]` | Port numbers | - |
| `kubectl get [TAB]` | Resource types | - |
| `kubectl get pods [TAB]` | Pod names | Pod description |
| `kubectl -n [TAB]` | Namespaces | - |
| `kubectl config use-context [TAB]` | Contexts | - |

## Files

- `~/.config/fish/completions/kubectl-simple.fish` - Entry point
- `~/.config/fish/functions/kubectl_fzf_native.fish` - FZF wrapper
- `~/.config/fish/completions/kubectl.fish` - Native completions (226K)

## Usage

```bash
# Normal tab completion with FZF
kubectl get pods [TAB]         # FZF picker with preview

# Toggle FZF mode
kubectl_toggle_fzf             # Disable FZF for plain completions

# Works with aliases
k logs [TAB]                   # Uses same completions
kubecolor get pods [TAB]       # Also supported
```

## Key Bindings in FZF

- `Enter` - Select item
- `Ctrl-/` - Toggle preview window
- Type to filter - Fuzzy search

## Benefits over previous implementation

1. **~14K less code** - Uses native functions instead of reimplementing
2. **Container completion** - Native function parses pod spec for containers
3. **Port completion** - Shows actual port numbers from resources
4. **CRD support** - Native completions include custom resources
5. **More flags** - Native has comprehensive flag support
6. **Better maintained** - kubectl.fish is updated with kubectl releases
