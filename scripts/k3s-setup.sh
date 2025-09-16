#!/bin/bash

# K3s cluster setup script for local development

set -e

CLUSTER_NAME="local-cluster"
CONFIG_FILE="$HOME/dotfiles/.config/k3d/config.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if k3d is installed
if ! command -v k3d &> /dev/null; then
    echo_error "k3d is not installed. Please run: brew install k3d"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo_error "kubectl is not installed. Please run: brew install kubectl"
    exit 1
fi

# Check if Docker/Podman is running
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    echo_info "Docker is running"
    RUNTIME="docker"
elif command -v podman &> /dev/null && podman machine list | grep -qE "Running|running"; then
    echo_info "Podman is running"
    RUNTIME="podman"
    # Set Docker host to use Podman socket
    export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
else
    echo_error "Neither Docker nor Podman is running. Please start one of them first."
    echo_info "For Podman: podman machine start"
    echo_info "For Docker: open Docker Desktop"
    exit 1
fi

# Function to create cluster
create_cluster() {
    echo_info "Creating k3d cluster '$CLUSTER_NAME'..."

    if [ -f "$CONFIG_FILE" ]; then
        echo_info "Using config file: $CONFIG_FILE"
        k3d cluster create --config "$CONFIG_FILE"
    else
        echo_warn "Config file not found, creating with defaults..."
        k3d cluster create $CLUSTER_NAME \
            --servers 1 \
            --agents 2 \
            --port "8080:80@loadbalancer" \
            --port "8443:443@loadbalancer" \
            --registry-create k3d-local-registry:0.0.0.0:5000 \
            --wait
    fi

    echo_info "Cluster created successfully!"
    echo_info "Kubeconfig has been updated"
}

# Function to delete cluster
delete_cluster() {
    echo_info "Deleting k3d cluster '$CLUSTER_NAME'..."
    k3d cluster delete $CLUSTER_NAME
    echo_info "Cluster deleted successfully!"
}

# Function to start cluster
start_cluster() {
    echo_info "Starting k3d cluster '$CLUSTER_NAME'..."
    k3d cluster start $CLUSTER_NAME
    echo_info "Cluster started successfully!"
}

# Function to stop cluster
stop_cluster() {
    echo_info "Stopping k3d cluster '$CLUSTER_NAME'..."
    k3d cluster stop $CLUSTER_NAME
    echo_info "Cluster stopped successfully!"
}

# Function to get cluster status
status_cluster() {
    echo_info "K3d clusters:"
    k3d cluster list
    echo ""
    echo_info "Kubernetes nodes:"
    kubectl get nodes || echo_warn "Cannot get nodes. Is the cluster running?"
    echo ""
    echo_info "Kubernetes pods (all namespaces):"
    kubectl get pods --all-namespaces || echo_warn "Cannot get pods. Is the cluster running?"
}

# Main menu
case "${1:-}" in
    create)
        create_cluster
        ;;
    delete)
        delete_cluster
        ;;
    start)
        start_cluster
        ;;
    stop)
        stop_cluster
        ;;
    restart)
        stop_cluster
        start_cluster
        ;;
    status)
        status_cluster
        ;;
    *)
        echo "Usage: $0 {create|delete|start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  create  - Create a new k3d cluster"
        echo "  delete  - Delete the k3d cluster"
        echo "  start   - Start an existing cluster"
        echo "  stop    - Stop a running cluster"
        echo "  restart - Restart the cluster"
        echo "  status  - Show cluster status"
        exit 1
        ;;
esac