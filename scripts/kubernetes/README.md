# Local Kubernetes Development Setup

This directory contains scripts and configurations for local Kubernetes development using OrbStack and various Kubernetes distributions.

## Current Setup

### Primary: OrbStack with k3d
- **Container Runtime**: OrbStack (Docker-compatible, native Apple Virtualization.framework)
- **Kubernetes Distribution**: k3d (k3s in Docker)
- **Why OrbStack?**:
  - Native macOS performance
  - Lower resource usage than Docker Desktop
  - Built-in Kubernetes support
  - Seamless Docker compatibility

### Available Scripts

#### `container-runtime-detect.sh`
Helper script that detects which container runtime is available (OrbStack, Docker Desktop, or Podman).
- Automatically sets appropriate environment variables
- Can be sourced by other scripts for runtime detection
- Priority: OrbStack > Docker Desktop > Podman

```bash
# Run directly to check runtime
./container-runtime-detect.sh

# Source in other scripts
source ./container-runtime-detect.sh
detect_container_runtime
```

#### `k3s-setup.sh`
Main script for managing k3d clusters with automatic runtime detection.

```bash
# Create a new k3d cluster
./k3s-setup.sh create

# Delete the cluster
./k3s-setup.sh delete

# Start/stop existing cluster
./k3s-setup.sh start
./k3s-setup.sh stop

# Check status
./k3s-setup.sh status

# Restart cluster
./k3s-setup.sh restart
```

**Configuration**: Uses `~/.config/k3d/config.yaml` for cluster configuration
- 1 server node
- 2 agent nodes
- Port mappings: 8080:80, 8443:443
- Local registry at port 5000

#### `orbstack-k3s.sh`
Comprehensive Kubernetes management script specifically for OrbStack, supporting multiple Kubernetes options.

```bash
# Interactive menu
./orbstack-k3s.sh

# Direct commands for k3d
./orbstack-k3s.sh k3d create
./orbstack-k3s.sh k3d status
./orbstack-k3s.sh k3d dashboard

# Minikube support
./orbstack-k3s.sh minikube create
./orbstack-k3s.sh minikube dashboard

# KIND support
./orbstack-k3s.sh kind create

# Native OrbStack Kubernetes
./orbstack-k3s.sh native start
./orbstack-k3s.sh native status
```

#### `minikube-setup.sh`
Minikube cluster management with automatic runtime detection.

```bash
# Create Minikube cluster
./minikube-setup.sh create

# Manage cluster
./minikube-setup.sh start
./minikube-setup.sh stop
./minikube-setup.sh delete

# Access dashboard
./minikube-setup.sh dashboard

# SSH into node
./minikube-setup.sh ssh
```

## Quick Start

### 1. Install OrbStack
```bash
brew install orbstack
open -a OrbStack
```

### 2. Install Kubernetes Tools
```bash
brew install kubectl k3d helm k9s
```

### 3. Create Your First Cluster
```bash
# Using k3d (recommended)
./scripts/k3s-setup.sh create

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

### 4. Access Your Cluster
```bash
# Use k9s for a terminal UI
k9s

# Or use kubectl directly
kubectl get pods --all-namespaces
```

## Runtime Detection

All scripts automatically detect and configure the appropriate container runtime:

1. **OrbStack** (Preferred)
   - Automatically clears any Podman DOCKER_HOST settings
   - Uses native Docker API
   - Best performance on macOS

2. **Docker Desktop** (Fallback)
   - Works if OrbStack is not available
   - Higher resource usage

3. **Podman** (Limited Support)
   - Requires Podman machine to be running
   - Sets DOCKER_HOST to Podman socket
   - Note: Limited Kubernetes support on macOS

## Troubleshooting

### DOCKER_HOST Issues
If k3d can't connect to Docker daemon:
```bash
# Clear Podman DOCKER_HOST
unset DOCKER_HOST

# Verify OrbStack is running
orbctl status
```

### Context Issues
If kubectl is using wrong context:
```bash
# List contexts
kubectl config get-contexts

# Switch to k3d cluster
kubectl config use-context k3d-local-cluster

# Or merge k3d kubeconfig
k3d kubeconfig merge local-cluster --kubeconfig-switch-context
```

### Port Conflicts
If ports 8080 or 8443 are in use:
- Edit `~/.config/k3d/config.yaml` to use different ports
- Or stop conflicting services

## Configuration Files

- `~/.config/k3d/config.yaml` - k3d cluster configuration
- `~/.kube/config` - Kubernetes contexts and credentials

## Best Practices

1. **Use k3d for lightweight development** - Fast startup, low resource usage
2. **Use Minikube for addon testing** - Rich addon ecosystem
3. **Use KIND for CI/CD testing** - Matches CI environments
4. **Keep clusters ephemeral** - Delete and recreate rather than long-running
5. **Use namespaces** - Organize workloads by namespace

## TODO

- [ ] Add Lima VM setup script for running a Linux VM
- [ ] Integrate KIND (Kubernetes in Docker) with Lima for true Linux-based Kubernetes
- [ ] Add Helm chart deployment examples
- [ ] Create development environment setup (ingress, monitoring, etc.)
- [ ] Add multi-cluster management support
- [ ] Document service mesh integration (Istio/Linkerd)
- [ ] Add automated testing for all scripts
- [ ] Create cluster backup/restore functionality

## Resources

- [OrbStack Documentation](https://orbstack.dev/docs)
- [k3d Documentation](https://k3d.io)
- [k3s Documentation](https://k3s.io)
- [Minikube Documentation](https://minikube.sigs.k8s.io)
- [KIND Documentation](https://kind.sigs.k8s.io)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## License

These scripts are part of personal dotfiles and are provided as-is for reference.