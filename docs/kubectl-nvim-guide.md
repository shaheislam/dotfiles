# kubectl.nvim Guide for K3d Pods

Complete guide for using kubectl.nvim and alternatives for managing Kubernetes pods in Neovim.

## Table of Contents
- [kubectl.nvim Installation](#kubectlnvim-installation)
- [Key Features](#key-features)
- [Essential Commands](#essential-commands)
- [Working with K3d Pods](#working-with-k3d-pods)
- [Alternative Tools](#alternative-tools)
- [Comparison](#comparison)

## kubectl.nvim Installation

### Prerequisites
```bash
# Install required tools via Homebrew
brew install kubectl kubediff helm

# Install the plugin in Neovim
:Lazy sync
```

### Plugin Configuration
The plugin is configured at: `~/.config/nvim/lua/plugins/kubectl.lua`

## Key Features

- **Full Kubernetes Management**: View and manage all resources within Neovim
- **No SSH Required**: Works directly with kubectl, no SSH needed in pods
- **Interactive Navigation**: Drill down from deployments → pods → containers
- **Real-time Updates**: Auto-refresh every 300ms
- **Integrated Terminal**: Exec into containers directly

## Essential Commands

### Global Keybindings
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>kk` | Toggle kubectl | Open/close kubectl view |
| `<leader>kp` | Pods view | Jump directly to pods |
| `<leader>kd` | Deployments | Jump directly to deployments |
| `g?` | Help | Show keybindings help |
| `gr` | Refresh | Refresh current view |
| `<CR>` | Select/Enter | Drill down into resource |
| `<BS>` | Back | Go back to previous view |

### Resource Views
| Key | View | Description |
|-----|------|-------------|
| `1` | Deployments | View all deployments |
| `2` | Pods | View all pods |
| `3` | Services | View all services |
| `4` | Ingresses | View ingresses |
| `5` | Jobs | View jobs |
| `6` | ConfigMaps | View configmaps |

### Resource Actions
| Key | Action | What it does |
|-----|--------|--------------|
| `gd` | Describe | Show resource details |
| `gD` | Delete | Delete resource |
| `ge` | Edit | Edit resource YAML |
| `gy` | View YAML | View resource as YAML |
| `gl` | Logs | View pod logs |
| `f` | Follow | Follow logs (when in logs view) |

### Context & Namespace
| Key | Action | Description |
|-----|--------|-------------|
| `<C-x>` | Context | Change cluster context |
| `<C-n>` | Namespace | Change namespace |
| `gs` | Sort | Sort by current column |

## Working with K3d Pods

### Quick Workflows

#### 1. Exec into a Pod
```vim
<leader>kk         " Open kubectl view
2                  " Go to pods view
<CR> on pod        " Select the pod
<CR> on container  " Exec into container
```

#### 2. Edit Files in Pod (via kubectl exec)
Since kubectl.nvim execs you into the container, you can:
```bash
# Once inside the container
vi /path/to/file   # Edit with vi
cat /path/to/file  # View file
echo "content" > /path/to/file  # Write file
```

#### 3. View Pod Logs
```vim
<leader>kk    " Open kubectl view
2             " Go to pods view
gl on pod     " View logs
f             " Follow logs
```

#### 4. Edit Pod Configuration
```vim
<leader>kk    " Open kubectl view
2             " Go to pods view
ge on pod     " Edit pod YAML
```

### Your K3d Pods
```bash
# Current pods in your cluster
dev-pod-alpine   # Alpine Linux pod
dev-pod-python   # Python environment
dev-pod-ssh      # SSH-enabled pod
dev-pod-secure   # Security-focused pod
```

## Alternative Tools

### 1. Netman.nvim (SSH-based)
```vim
# Requires SSH in pod and port forwarding
:Nmread ssh://root@localhost:2222/path/to/file
```

### 2. Direct kubectl Commands
```bash
# Quick file operations
kubectl exec dev-pod-alpine -- cat /etc/hosts
echo "content" | kubectl exec -i dev-pod-alpine -- sh -c "cat > /tmp/test"
```

## Comparison

| Feature | kubectl.nvim | netman.nvim | Direct kubectl |
|---------|-------------|-------------|----------------|
| **SSH Required** | No | Yes | No |
| **Directory Browse** | Yes | Yes | No |
| **Resource Management** | Yes | No | Limited |
| **Exec into Container** | Yes | No | Yes |
| **Log Viewing** | Yes | No | Yes |
| **YAML Editing** | Yes | No | Yes |
| **File Editing** | Via exec | Direct | Manual |
| **Setup Complexity** | Low | Medium | None |

## Tips & Tricks

### Quick Access Commands
```vim
" Neovim commands for quick access
:Kubectl           " Toggle kubectl view
:KubectlPods       " Jump directly to pods
:KubectlDeployments " Jump to deployments
```

### Workflow Optimization
1. Use number keys (1-6) for quick view switching
2. Use `<C-p>` for picker view when searching
3. Press `?` in any view to see available actions
4. Use `gs` to sort by any column

### Troubleshooting
- **Connection Issues**: Check kubectl context with `:!kubectl config current-context`
- **Refresh Issues**: Manually refresh with `gr`
- **Exec Failures**: Ensure container has shell (`sh` or `bash`)

## Summary

kubectl.nvim provides the most comprehensive Kubernetes management experience in Neovim:
- **Best for**: Full cluster management, log viewing, resource editing
- **Not ideal for**: Direct file editing (use exec into container instead)
- **Key advantage**: No SSH required, works with minimal containers

For your k3d workflow, kubectl.nvim excels at container management and debugging. Use exec to get into containers for file editing, or netman.nvim if SSH is available.