# Kubernetes Scripts (Colima + k3d)

This directory contains scripts for local Kubernetes development using Colima as the container runtime and k3d for Kubernetes clusters.

## Current Setup

We've standardized on **Colima + k3d** for local Kubernetes development:

- **Container Runtime**: Colima (lightweight Docker Desktop alternative)
- **Kubernetes**: k3d (lightweight k3s clusters in Docker)

## Main Script

The primary script for setting up local Kubernetes is located at:
- `/scripts/k3d-colima-setup.sh`

## Usage

### Start Colima and Create k3d Cluster
```bash
# From dotfiles directory
./scripts/k3d-colima-setup.sh start
```

### Stop Cluster
```bash
./scripts/k3d-colima-setup.sh stop
```

### Delete Cluster
```bash
./scripts/k3d-colima-setup.sh delete
```

### Verify Setup
```bash
./scripts/k3d-colima-setup.sh verify
```

## Fish Shell Functions

The Fish shell configuration includes a `kcluster` function for easy management:

```fish
# Create a new cluster
kcluster start [name]

# List clusters
kcluster list

# Stop a cluster
kcluster stop <name>

# Delete a cluster
kcluster delete <name>
```

## Configuration

- **k3d Config**: `~/.config/k3d/config.yaml`
- **Docker Context**: Automatically set to use Colima socket
- **DOCKER_HOST**: Set to `unix://$HOME/.colima/default/docker.sock`

## Benefits of Colima

- Free and open source (no Docker Desktop license required)
- Lightweight resource usage
- Full Docker compatibility
- Works with all Docker tools and docker-compose

## Removed Components

The following have been removed as we've standardized on Colima:
- OrbStack scripts
- Minikube configurations
- Podman setups
- Docker Desktop dependencies
- Alternative k3s deployment scripts

## Troubleshooting

If you encounter issues:

1. Ensure Colima is running:
   ```bash
   colima status
   ```

2. Check Docker context:
   ```bash
   docker context ls
   docker context use colima
   ```

3. Verify DOCKER_HOST:
   ```bash
   echo $DOCKER_HOST
   # Should show: unix:///Users/<username>/.colima/default/docker.sock
   ```

4. Restart Colima if needed:
   ```bash
   colima stop
   colima start --runtime docker --cpu 4 --memory 8 --disk 60
   ```