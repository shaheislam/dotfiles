#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CLUSTER_NAME="dev"
COLIMA_CPU=2
COLIMA_MEMORY=4
COLIMA_DISK=20
K3D_SERVERS=1
K3D_AGENTS=2

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

setup_colima() {
    print_status "Setting up Colima..."

    # Check if colima is installed
    if ! command -v colima &> /dev/null; then
        print_error "Colima is not installed. Installing..."
        brew install colima
    fi

    # Check if colima is running
    if colima status &> /dev/null; then
        print_warning "Colima is already running"
    else
        print_status "Starting Colima with Docker runtime..."
        colima start \
            --cpu $COLIMA_CPU \
            --memory $COLIMA_MEMORY \
            --disk $COLIMA_DISK \
            --runtime docker \
            --kubernetes=false
    fi

    # Set Docker context and environment
    export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
    docker context use colima 2>/dev/null || true

    # Wait for Docker to be ready
    print_status "Waiting for Docker to be ready..."
    for i in {1..30}; do
        if docker info &> /dev/null; then
            print_status "Docker is ready!"
            break
        fi
        sleep 2
    done
}

setup_k3d() {
    print_status "Setting up k3d cluster..."

    # Check if k3d is installed
    if ! command -v k3d &> /dev/null; then
        print_error "k3d is not installed. Installing..."
        brew install k3d
    fi

    # Delete existing cluster if exists
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        print_warning "Cluster '$CLUSTER_NAME' exists. Deleting..."
        k3d cluster delete "$CLUSTER_NAME"
    fi

    # Create new k3d cluster
    print_status "Creating k3d cluster '$CLUSTER_NAME'..."
    k3d cluster create "$CLUSTER_NAME" \
        --servers $K3D_SERVERS \
        --agents $K3D_AGENTS \
        --port "8080:80@loadbalancer" \
        --port "8443:443@loadbalancer" \
        --volume "$(pwd):/workspace@all" \
        --k3s-arg "--disable=traefik@server:0" \
        --wait

    print_status "k3d cluster created successfully!"
}

verify_setup() {
    print_status "Verifying setup..."

    # Check Docker
    if docker info &> /dev/null; then
        print_status "✓ Docker is running"
    else
        print_error "✗ Docker is not running"
        return 1
    fi

    # Check k3d cluster
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        print_status "✓ k3d cluster '$CLUSTER_NAME' is running"
    else
        print_error "✗ k3d cluster is not running"
        return 1
    fi

    # Check kubectl context
    kubectl config use-context "k3d-$CLUSTER_NAME"

    # Check nodes
    print_status "Cluster nodes:"
    kubectl get nodes

    print_status ""
    print_status "Setup complete! You can now use:"
    print_status "  kubectl get pods --all-namespaces"
    print_status "  docker ps"
    print_status ""
    print_status "To stop:"
    print_status "  k3d cluster delete $CLUSTER_NAME"
    print_status "  colima stop"
}

cleanup() {
    print_status "Cleaning up..."
    k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true
    colima stop 2>/dev/null || true
}

# Main script
case "${1:-}" in
    start)
        setup_colima
        setup_k3d
        verify_setup
        ;;
    stop)
        print_status "Stopping k3d cluster and Colima..."
        k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true
        colima stop
        ;;
    restart)
        print_status "Restarting..."
        cleanup
        setup_colima
        setup_k3d
        verify_setup
        ;;
    status)
        print_status "Checking status..."
        colima status || print_error "Colima is not running"
        k3d cluster list
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|cleanup}"
        echo ""
        echo "Environment variables:"
        echo "  CLUSTER_NAME   - k3d cluster name (default: dev)"
        echo "  COLIMA_CPU     - CPUs for Colima VM (default: 2)"
        echo "  COLIMA_MEMORY  - Memory for Colima VM in GB (default: 4)"
        echo "  COLIMA_DISK    - Disk size for Colima VM in GB (default: 20)"
        echo "  K3D_SERVERS    - Number of k3d server nodes (default: 1)"
        echo "  K3D_AGENTS     - Number of k3d agent nodes (default: 2)"
        exit 1
        ;;
esac