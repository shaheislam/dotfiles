# Kubernetes Manifests

This directory contains various Kubernetes manifest files for testing and development purposes.

## Available Manifests

### test-bash-deployment.yaml
**Purpose**: Multi-container test deployment with various shell environments
**Namespace**: `test`
**Containers**:
- `busybox` - Minimal Linux environment with basic shell (sh only)
- `alpine` - Alpine Linux with bash installed via apk
- `ubuntu` - Ubuntu 22.04 with bash pre-installed
- `nicolaka` - Netshoot container with extensive networking tools and bash

**Usage**:
```bash
kubectl apply -f test-bash-deployment.yaml
```

**Use Case**: Testing kubectl shell access and container debugging capabilities with different base images.

### test-simple-deployment.yaml
**Purpose**: Lightweight single-container deployment for basic testing
**Namespace**: `test`
**Container**: `busybox` running sleep command
**Resources**: Minimal (32Mi memory request, 64Mi limit)

**Usage**:
```bash
kubectl apply -f test-simple-deployment.yaml
```

**Use Case**: Quick testing of kubectl exec functionality, minimal resource usage for testing in constrained environments.

### test-logging-deployment.yaml
**Purpose**: Multi-replica deployment for testing logging and stern functionality
**Namespace**: `test`
**Replicas**: 2 pods
**Containers per pod**:
- `logger` - Outputs plain text logs with timestamps, different log levels (INFO, WARN, ERROR)
- `json-logger` - Outputs JSON-formatted logs for testing JSON log parsing

**Features**:
- Each pod logs unique messages with its hostname
- Logs every 5 seconds with incrementing counter
- Mixed log levels (INFO, WARN, ERROR) at different intervals
- One container outputs plain text, another outputs JSON
- Minimal resource usage

**Usage**:
```bash
kubectl apply -f test-logging-deployment.yaml
```

**Testing**:
- `stern <deployment>` - View aggregated logs from all pods
- `kubectl logs -f <pod> -c json-logger` - Parse JSON logs from json-logger container
- `kubectl logs -f <pod> -c logger` - See plain text logs from logger container

**Use Case**: Testing stern multi-pod log aggregation, JSON log parsing, log level highlighting, and container log differentiation.

## Custom Debug Images

### netshoot-nvim

A custom Docker image with Ubuntu 22.04, networking tools, and Neovim with full plugin support.

**Build**: See `scripts/docker/README.md` for build instructions
**Image**: `netshoot-nvim:latest`
**Base**: Ubuntu 22.04 (glibc - full plugin compatibility)

**Included Tools**:
- Networking: tcpdump, nmap, netcat, socat, iperf3, mtr, dig, traceroute
- Neovim (latest stable) with 68 pre-installed plugins
- LSPs via Mason: yaml-ls, json-ls, dockerfile-ls, bash-ls, lua-ls
- Utilities: ripgrep, fzf, fd, jq, yq, httpie

**Usage in Kubernetes**:
```bash
# Build the image first
./scripts/docker/build-netshoot-nvim.sh

# Use as ephemeral debug container
kubectl run debug --rm -it --image=netshoot-nvim:latest -- /bin/bash

# Or add to test-bash-deployment.yaml as an additional container
```

**Use Case**: Network debugging with Neovim for editing Kubernetes manifests, configs, and notes directly in the cluster with full LSP support.

## Cleanup

To remove all test resources:
```bash
kubectl delete namespace test
```

This will remove all deployments and pods created by these manifests.

## Adding New Manifests

When adding new manifest files to this directory:
1. Place the `.yaml` file in this directory
2. Update this README.md with:
   - Manifest filename
   - Purpose description
   - Namespace used
   - Container details
   - Resource requirements
   - Usage instructions
   - Primary use case