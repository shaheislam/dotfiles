# Simple Kubectl Completions for Fish

## Overview

This provides simple, lightweight kubectl completions for Fish shell - similar to the ZSH FZF completions but without the complexity.

## Features

- **Namespace-aware**: Extracts namespace from `-n` or `--namespace` flags
- **Context-aware**: Provides appropriate completions based on kubectl command
- **Simple and fast**: No fancy previews or complex FZF features
- **Works with aliases**: Supports `kubectl`, `k`, and `kubecolor`

## What it completes

- **Namespaces**: After `-n` or `--namespace`
- **Pods**: For `logs`, `exec`, `port-forward`, and when after `get pods`, `describe pods`, `delete pods`
- **Deployments**: When after `get deployment`, `describe deployment`, `delete deployment`
- **Services**: When after `get service`, `describe service`, `delete service`
- **ConfigMaps**: When after `get configmap`, `describe configmap`, `delete configmap`

## Usage

Just use TAB as normal:

```bash
kubectl get pods [TAB]         # Lists pods
kubectl -n [TAB]               # Lists namespaces
kubectl logs [TAB]             # Lists pods
kubectl describe deployment [TAB]  # Lists deployments
k exec [TAB]                   # Lists pods (works with k alias)
```

## Files

- `~/.config/fish/functions/kubectl_simple_complete.fish` - Main completion logic
- `~/.config/fish/completions/kubectl-simple.fish` - Registers completions

## How it works

1. Parses the current command line to understand context
2. Extracts namespace if specified
3. Returns appropriate list of resources
4. Fish's completion system handles the rest

## Comparison with complex version

This is much simpler than the previous implementation:
- No FZF preview windows
- No complex keybindings
- No resource type detection
- Just returns lists for completion

This makes it more reliable and less likely to conflict with other tools like fifc.