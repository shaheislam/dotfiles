# kubectl FZF Native Completions for Fish

## Overview

FZF-powered kubectl completions that leverage native `__fish_kubectl_*` functions from the official kubectl completions. This provides the best of both worlds: comprehensive native completion support with FZF's interactive selection.

## Architecture

```
conf.d/kubectl-fzf.fish (startup loader)
  ↓ Sources kubectl.fish lazy stub
  ↓ Sources kubectl_fzf_native.fish lazy FZF wrapper
  ↓ TAB router sends kubectl/k/kubecolor/kctl to _kubectl_fzf_tab_complete
  ↓
kubectl_fzf_native.fish (FZF wrapper)
  ↓ Sources _kubectl_fzf_native_full.fish on first use
  ↓ Loads native __fish_kubectl_* functions on demand
  ↓
kubectl.fish.full (native 226K comprehensive completions)
  ├── __fish_kubectl_print_resource
  ├── __fish_kubectl_print_pod_containers
  ├── __fish_kubectl_print_resource_ports
  ├── __fish_kubectl_print_resource_types
  ├── __fish_kubectl_get_config
  └── ... (many more native functions)
```

**Important**: The `plugins.fish` in `conf.d/` has `kubectl completion fish | source` **disabled**
to prevent kubectl's native Go-based completions from overriding the FZF completions.

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

- `~/.config/fish/conf.d/kubectl-fzf.fish` - Startup loader and completion registration
- `~/.config/fish/functions/kubectl_fzf_native.fish` - Lazy FZF wrapper
- `~/.config/fish/functions/_kubectl_fzf_native_full.fish` - Full FZF completion implementation
- `~/.config/fish/completions/kubectl.fish` - Lazy native completion stub
- `~/.config/fish/completions/kubectl.fish.full` - Native completions (226K) with __fish_kubectl_* functions

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
