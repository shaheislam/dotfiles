#!/bin/bash

# Minikube cluster setup script for local development with Podman

set -e

CLUSTER_NAME="minikube"
DRIVER="podman"

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

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo_error "minikube is not installed. Please run: brew install minikube"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo_error "kubectl is not installed. Please run: brew install kubectl"
    exit 1
fi

# Detect container runtime
detect_runtime() {
    # Check for OrbStack first (highest priority)
    if command -v orbctl &> /dev/null && orbctl status &> /dev/null 2>&1; then
        echo_info "OrbStack detected and running"
        DRIVER="docker"
        RUNTIME_NAME="OrbStack"
        # Clear any Podman DOCKER_HOST settings
        if [[ "$DOCKER_HOST" == *"podman"* ]]; then
            echo_warn "Clearing Podman DOCKER_HOST to use OrbStack"
            unset DOCKER_HOST
        fi
        return 0
    fi

    # Check for Docker Desktop
    if command -v docker &> /dev/null && docker ps &> /dev/null 2>&1; then
        echo_info "Docker Desktop is running"
        DRIVER="docker"
        RUNTIME_NAME="Docker"
        return 0
    fi

    # Check for Podman
    if command -v podman &> /dev/null && podman machine list 2>/dev/null | grep -qE "Currently running"; then
        echo_info "Podman is running"
        DRIVER="podman"
        RUNTIME_NAME="Podman"
        return 0
    fi

    # No runtime found
    echo_error "No container runtime detected. Please start one of:"
    echo_info "  - OrbStack: open -a OrbStack"
    echo_info "  - Docker Desktop: open -a Docker"
    echo_info "  - Podman: podman machine start"
    exit 1
}

# Detect and configure runtime
detect_runtime

# Function to create cluster
create_cluster() {
    echo_info "Creating minikube cluster with $RUNTIME_NAME driver..."

    # Set container runtime based on driver
    if [ "$DRIVER" = "docker" ]; then
        CONTAINER_RUNTIME="docker"
    else
        CONTAINER_RUNTIME="containerd"
    fi

    minikube start \
        --driver=$DRIVER \
        --container-runtime=$CONTAINER_RUNTIME \
        --cpus=2 \
        --memory=3072 \
        --disk-size=20g \
        --kubernetes-version=stable \
        --addons=metrics-server \
        --wait=all

    echo_info "Cluster created successfully!"
    echo_info "Kubeconfig has been updated"

    # Show cluster info
    echo ""
    echo_info "Cluster information:"
    kubectl cluster-info
    echo ""
    echo_info "Nodes:"
    kubectl get nodes
}

# Function to delete cluster
delete_cluster() {
    echo_info "Deleting minikube cluster..."
    minikube delete
    echo_info "Cluster deleted successfully!"
}

# Function to start cluster
start_cluster() {
    echo_info "Starting minikube cluster..."
    minikube start
    echo_info "Cluster started successfully!"
}

# Function to stop cluster
stop_cluster() {
    echo_info "Stopping minikube cluster..."
    minikube stop
    echo_info "Cluster stopped successfully!"
}

# Function to get cluster status
status_cluster() {
    echo_info "Minikube status:"
    minikube status
    echo ""
    echo_info "Kubernetes nodes:"
    kubectl get nodes || echo_warn "Cannot get nodes. Is the cluster running?"
    echo ""
    echo_info "Kubernetes pods (all namespaces):"
    kubectl get pods --all-namespaces || echo_warn "Cannot get pods. Is the cluster running?"
}

# Function to access dashboard
dashboard() {
    echo_info "Opening Kubernetes dashboard..."
    echo_info "Press Ctrl+C to stop the dashboard"
    minikube dashboard
}

# Function to enable addons
addons() {
    echo_info "Available addons:"
    minikube addons list
}

# Function to get cluster IP
ip() {
    echo_info "Minikube IP address:"
    minikube ip
}

# Function to SSH into node
ssh() {
    echo_info "SSH into minikube node..."
    minikube ssh
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
    dashboard)
        dashboard
        ;;
    addons)
        addons
        ;;
    ip)
        ip
        ;;
    ssh)
        ssh
        ;;
    *)
        echo "Usage: $0 {create|delete|start|stop|restart|status|dashboard|addons|ip|ssh}"
        echo ""
        echo "Commands:"
        echo "  create    - Create a new minikube cluster with Podman"
        echo "  delete    - Delete the minikube cluster"
        echo "  start     - Start an existing cluster"
        echo "  stop      - Stop a running cluster"
        echo "  restart   - Restart the cluster"
        echo "  status    - Show cluster status"
        echo "  dashboard - Open Kubernetes dashboard"
        echo "  addons    - List available addons"
        echo "  ip        - Get cluster IP address"
        echo "  ssh       - SSH into the cluster node"
        exit 1
        ;;
esac
