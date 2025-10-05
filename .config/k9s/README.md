# K9s Plugins Reference Guide

A comprehensive guide to all configured k9s plugins with their shortcuts and applicable resource scopes.

## Quick Reference by Scope

### 🟢 Universal Plugins (work on ALL resources)
| Shortcut | Description | Command |
|----------|-------------|---------|
| `Ctrl-O` | Edit in Neovim | Opens resource YAML in Neovim |
| `Ctrl-Y` | Copy YAML | Copies resource YAML to clipboard |
| `Shift-E` | Show events | Shows Kubernetes events for resource |
| `w` | Watch | Watch resource changes (2s refresh) |
| `Ctrl-F` | Remove finalizers | ⚠️ DANGEROUS - removes stuck finalizers |

### 📦 Pod-Specific Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `b` | Bash/sh shell | Smart shell - tries bash, falls back to sh |
| `Shift-W` | Show metrics | Shows pod resource usage |
| `Ctrl-L` | Stern logs | Multi-pod log tailing with colors |
| `Shift-D` | Debug container | ⚠️ Adds netshoot debug container |
| `Shift-K` | Port-forward | Interactive port forwarding |
| `Shift-Q` | Resource recommendations | Analyzes resource usage vs requests/limits |
| `Ctrl-N` | DNS trace | Tests DNS resolution from pod |
| `Ctrl-T` | tcpdump | Captures network traffic |
| `Ctrl-G` | Netshoot | Launches network debug container |
| `j` | JSON logs | Parses JSON logs with jq |
| `Ctrl-B` | Bunyan logs | Formats logs with Bunyan |
| `Ctrl-U` | Istio proxy config | Shows Istio sidecar configuration |

### 🐳 Container-Specific Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `b` | Bash/sh shell | Exec into container |
| `F5` | sh shell | Basic shell with TERM setup |
| `F6` | Shell + nvim | Tries to install Neovim in container |
| `d` | Dive image | Analyzes image layers (requires dive) |
| `Shift-V` | Security scan | Trivy vulnerability scan |
| `Shift-D` | Debug container | Adds netshoot debug container |
| `j` | JSON logs | Parse container JSON logs |
| `Ctrl-B` | Bunyan logs | Format container logs |

### 🚀 Deployment Plugins
| Shortcut | Description | Scopes |
|----------|-------------|--------|
| `Shift-T` | Restart | deployments, statefulsets, daemonsets |
| `Shift-S` | Scale deployment | deployments only |
| `Alt-S` | Scale statefulset | statefulsets only |
| `Ctrl-L` | Stern logs | deployments (multi-pod logs) |

### 🖥️ Node Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-U` | Node shell | ⚠️ SSH into node (requires permissions) |
| `Ctrl-Q` | Drain node | ⚠️ DANGEROUS - drains node |
| `Ctrl-G` | Netshoot | Network debug container |

### 🌐 Service Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-K` | Port-forward | Interactive port forwarding to service |

### 🏷️ Namespace Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-R` | Get all resources | Shows all resources in namespace |

### ⚙️ Helm Release Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `v` | Helm values | Shows Helm values in Neovim |
| `Shift-H` | Helm diff | Shows diff for upgrade |
| `Ctrl-P` | Purge release | ⚠️ DANGEROUS - completely removes release |
| `Ctrl-H` | Rollback | Rolls back to previous version |
| `Shift-G` | Flux toggle | Toggle suspend/resume (Flux HelmReleases) |
| `Shift-X` | Flux reconcile | Force reconciliation |

### 📅 CronJob Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Ctrl-J` | Toggle suspend | Suspend/resume CronJob |

### 💾 PVC Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-P` | Debug PVC | Mounts PVC in temporary container |

### 🔐 Certificate Plugins (cert-manager)
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-C` | Check readiness | Shows certificate ready status |
| `Ctrl-C` | Force renewal | ⚠️ Forces certificate renewal |

### 📦 Git Repository Plugins (Flux)
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-X` | Flux reconcile | Force git repository reconciliation |

### 🎯 Kustomization Plugins (Flux)
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-X` | Flux reconcile | Force kustomization reconciliation |

### 🚦 ScaledObject Plugins (KEDA)
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Ctrl-K` | Toggle KEDA | Pause/unpause KEDA ScaledObject |

### 🔑 ExternalSecret Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Ctrl-E` | Refresh secret | Forces ExternalSecret refresh |

### 🌍 Crossplane Plugins
| Shortcut | Description | Scopes |
|----------|-------------|--------|
| `Ctrl-X` | Status check | managed, composite resources |

### 🚢 ArgoCD Application Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Shift-Y` | Sync app | ⚠️ Force sync with prune |
| `Ctrl-D` | Show diff | Shows ArgoCD diff |

### 🎲 Argo Rollout Plugins
| Shortcut | Description | Notes |
|----------|-------------|-------|
| `Ctrl-R` | Promote | ⚠️ Promotes rollout |
| `Ctrl-A` | Abort | ⚠️ DANGEROUS - aborts rollout |

## Testing Guide

### Basic Testing Flow

1. **Start with safe operations:**
   ```bash
   # Launch k9s
   k9s

   # Navigate to pods (:pods)
   # Try these safe shortcuts:
   - Ctrl-O  # View YAML in Neovim
   - Ctrl-Y  # Copy YAML
   - Shift-E # View events
   - w       # Watch changes
   ```

2. **Test container operations:**
   ```bash
   # On a pod with containers:
   - b      # Shell into container
   - j      # View JSON logs
   - Ctrl-L # Stern logs with colors
   ```

3. **Test deployment operations:**
   ```bash
   # Navigate to deployments (:deploy)
   - Shift-S # Scale (interactive)
   - Ctrl-L  # Multi-pod logs
   ```

### Prerequisites for Advanced Features

- **Stern**: Install for enhanced log viewing
  ```bash
  brew install stern
  ```

- **Dive**: Install for image layer analysis
  ```bash
  brew install dive
  ```

- **Trivy**: Install for security scanning
  ```bash
  brew install trivy
  ```

- **Helm Diff Plugin**: Install for Helm diff functionality
  ```bash
  helm plugin install https://github.com/databus23/helm-diff
  ```

- **kubectl-node-shell**: Already in dotfiles at `scripts/bin/kubectl-node-shell`

### Safety Notes

⚠️ **Use with caution:**
- `Shift-D` - Adds debug containers to running pods
- `Shift-T` - Restarts deployments
- `Ctrl-F` - Removes finalizers (can bypass deletion protection)

⚠️ **Requires confirmation (dangerous):**
- `Ctrl-P` - Purges Helm releases
- `Ctrl-Q` - Drains nodes
- `Shift-U` - SSH into nodes
- `Shift-Y` - Force syncs ArgoCD apps
- `Ctrl-A` - Aborts Argo rollouts

### Custom Scripts

The configuration uses several custom scripts:
- `/Users/shaheislam/dotfiles/.config/k9s/scripts/stern-splash.sh` - Enhanced Stern with Splash colors
- `/Users/shaheislam/dotfiles/scripts/bin/kubectl-node-shell` - Node shell access

### Environment Variables Available

Each plugin has access to these K9s-provided variables:
- `$NAMESPACE` - Current namespace
- `$NAME` - Resource name
- `$POD` - Pod name (for pod/container contexts)
- `$CONTEXT` - Current kubectl context
- `$CLUSTER` - Current cluster
- `$USER` - Current user
- `$GROUPS` - User groups
- `$RESOURCE_NAME` - Full resource type/name
- `$CONTAINER` - Container name
- `$COL-*` - Column values from the current view

## Troubleshooting

### Plugin Not Working?

1. **Check scope**: Ensure you're on the right resource type
2. **Check prerequisites**: Some plugins need external tools (stern, dive, etc.)
3. **Check permissions**: Node operations need cluster admin rights
4. **Check dangerous flag**: Some operations require confirmation

### Testing in Different Contexts

Test plugins across different Kubernetes contexts:
```bash
# Local development
k9s --context docker-desktop
k9s --context minikube
k9s --context orbstack

# Cloud clusters (if available)
k9s --context eks-cluster
k9s --context gke-cluster
```

### Customization

All plugins are defined in: `~/.config/k9s/plugins.yaml`

To add your own plugins, follow the pattern:
```yaml
plugins:
  plugin-name:
    shortCut: <key-combo>
    description: <description>
    scopes:
      - <resource-type>
    command: <command>
    background: <true|false>
    confirm: <true|false>
    dangerous: <true|false>
    args:
      - <arguments>
```

## Quick Test Checklist

- [ ] Safe viewing operations (Ctrl-O, Ctrl-Y, Shift-E)
- [ ] Container shells (b, F5)
- [ ] Log viewing (Ctrl-L with Stern)
- [ ] Pod metrics (Shift-W)
- [ ] Deployment scaling (Shift-S)
- [ ] Port forwarding (Shift-K)
- [ ] Watch resources (w)
- [ ] Copy YAML to clipboard (Ctrl-Y)
- [ ] Resource events (Shift-E)
- [ ] JSON log parsing (j)