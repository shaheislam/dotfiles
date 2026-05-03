# kubectl Container Name Completion for Fish Shell

## Overview

This feature adds dynamic container name completion for kubectl commands in Fish shell. When using commands like `kubectl logs`, `kubectl exec`, etc., pressing TAB after the `-c` or `--container` flag will show the actual container names from the specified pod.

## Features

- **Dynamic completion**: Queries the actual pod to get container names in real-time
- **Namespace aware**: Correctly handles `-n` or `--namespace` flags
- **Multiple commands supported**: Works with `logs`, `exec`, `attach`, `cp`, and `debug` commands
- **FZF integration**: Works seamlessly with existing FZF-powered kubectl completions

## Usage

### Basic Usage

```fish
kubectl logs <pod-name> -c <TAB>
# Shows list of containers in the pod

kubectl exec <pod-name> -c <TAB> -- /bin/bash
# Shows list of containers for exec
```

### With Namespace

```fish
kubectl logs <pod-name> -n <namespace> -c <TAB>
# Shows containers from pod in specified namespace
```

### Supported Commands

- `kubectl logs` - View logs from a specific container
- `kubectl exec` - Execute commands in a specific container
- `kubectl attach` - Attach to a specific container
- `kubectl cp` - Copy files to/from a specific container
- `kubectl debug` - Debug a specific container
- `kubectl alpha debug` - Alpha debug for a specific container

## Installation

The feature is included in the full kubectl Fish completions at:
```
~/.config/fish/completions/kubectl.fish.full
```

`~/.config/fish/completions/kubectl.fish` is a lazy stub that loads the full file on first kubectl completion.

To reload the completions in your current shell:
```fish
source ~/.config/fish/completions/kubectl.fish.full
```

## Technical Details

### Implementation

The feature is implemented via the `__fish_kubectl_print_pod_containers` function which:

1. Parses the current command line to extract:
   - The subcommand (logs, exec, etc.)
   - The pod name (first non-flag argument after subcommand)
   - The namespace (if specified with `-n` or `--namespace`)

2. Queries kubectl for container names:
   ```bash
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].name}'
   ```

3. Returns the container names for Fish completion

### Function Location

The function is defined at approximately line 404 in `~/.config/fish/completions/kubectl.fish.full`

### Completion Definitions

Container completion is enabled for the following commands (approximate line numbers):
- Line 1404: `kubectl logs`
- Line 1326: `kubectl exec`
- Line 665: `kubectl attach`
- Line 828: `kubectl cp`
- Line 560: `kubectl alpha debug`
- Line 1249: `kubectl debug`

## Troubleshooting

### Completions not showing

1. Ensure the completions are loaded:
   ```fish
   source ~/.config/fish/completions/kubectl.fish.full
   ```

2. Verify the pod exists and you have access:
   ```fish
   kubectl get pod <pod-name> -n <namespace>
   ```

3. Check that the pod has containers:
   ```fish
   kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].name}'
   ```

### Slow completions

The completion makes an API call to kubectl, which may be slow if:
- The cluster is remote
- Network latency is high
- The cluster is under heavy load

Consider using `FISH_KUBECTL_COMPLETION_TIMEOUT` to adjust the timeout if needed.

## Notes

- The function uses `"x$arg"` comparison pattern to avoid conflicts with Fish's `test` builtin flags
- Container names are queried in real-time, ensuring they're always up-to-date
- Works with both short (`-c`) and long (`--container`) flag formats
- Gracefully handles cases where no pod is specified or found
