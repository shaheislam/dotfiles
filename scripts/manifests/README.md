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