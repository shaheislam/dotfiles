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

**Use Case**: Testing k9s plugins, shell access, and container debugging capabilities with different base images.

### test-simple-deployment.yaml
**Purpose**: Lightweight single-container deployment for basic testing
**Namespace**: `test`
**Container**: `busybox` running sleep command
**Resources**: Minimal (32Mi memory request, 64Mi limit)

**Usage**:
```bash
kubectl apply -f test-simple-deployment.yaml
```

**Use Case**: Quick testing of k9s exec functionality, minimal resource usage for testing in constrained environments.

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

**Testing with k9s**:
- `Ctrl-L` on deployment - View aggregated logs from all pods with stern
- `j` on a pod - Parse JSON logs from json-logger container
- Standard logs view - See plain text logs from logger container

**Use Case**: Testing stern multi-pod log aggregation, JSON log parsing, log level highlighting, and container log differentiation.

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