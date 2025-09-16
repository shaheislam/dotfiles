# Kubernetes Configuration

This directory contains kubectl configuration templates and cluster configs.

## Structure

- `config.template` - Base kubectl config template with empty clusters/contexts
- Additional cluster configs can be added here and merged

## Usage

The setup script will:
1. Create `~/.kube` directory if it doesn't exist
2. Initialize a basic kubectl config if none exists
3. Set proper permissions (600) on the config file

## Local Kubernetes Options

### Minikube (Full Kubernetes)
- **Start**: `minikube start` or `mkstart`
- **Stop**: `minikube stop` or `mkstop`
- **Delete**: `minikube delete` or `mkdel`
- **Dashboard**: `minikube dashboard` or `mkdash`
- **Resource Requirements**: ~2GB RAM minimum

### k3d (k3s in Docker)
- **Create**: `k3d cluster create mycluster` or `k3dcreate mycluster`
- **List**: `k3d cluster list` or `k3dlist`
- **Delete**: `k3d cluster delete mycluster` or `k3ddel mycluster`
- **Resource Requirements**: ~512MB RAM

### kind (Kubernetes in Docker)
- **Create**: `kind create cluster` or `kindc`
- **List**: `kind get clusters` or `kindl`
- **Delete**: `kind delete cluster` or `kindd`
- **Resource Requirements**: ~1GB RAM

## Helper Functions

The Fish config includes these helper functions:

- `kcluster <type> <action> [name]` - Manage local clusters
- `kctx` - Switch context with fzf
- `kns` - Switch namespace with fzf
- `kpod` - Select and interact with pods via fzf
- `kexec <pod> [command]` - Exec into pod with shell detection
- `kpf <pod> <ports>` - Port forward to a pod
- `ktop` - Show resource usage

## Aliases

Common kubectl shortcuts are configured in Fish:
- `k` - kubectl
- `kc` - kubectx (context switching)
- `kn` - kubens (namespace switching)
- `kgp` - kubectl get pods
- `kaf` - kubectl apply -f
- `kl` - kubectl logs
- And many more...

See `.config/fish/config.fish` for the complete list.