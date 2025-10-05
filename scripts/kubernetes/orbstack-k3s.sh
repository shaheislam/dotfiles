#!/bin/bash

# OrbStack Kubernetes Setup Script
# Supports multiple Kubernetes deployment options on OrbStack

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-orbstack-cluster}"
K3D_CONFIG_FILE="$HOME/dotfiles/.config/k3d/config.yaml"
KUBERNETES_TYPE="${1:-menu}"  # k3d, minikube, kind, native, or menu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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

echo_blue() {
    echo -e "${BLUE}$1${NC}"
}

echo_header() {
    echo ""
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if OrbStack is installed and running
check_orbstack() {
    if ! command -v orbctl &> /dev/null; then
        echo_error "OrbStack is not installed!"
        echo_info "Please install OrbStack: brew install orbstack"
        echo_info "Or download from: https://orbstack.dev"
        exit 1
    fi

    if ! orbctl status &> /dev/null; then
        echo_error "OrbStack is not running!"
        echo_info "Please start OrbStack: open -a OrbStack"
        exit 1
    fi

    echo_info "OrbStack is running ✓"

    # Clear any Podman Docker host settings to use OrbStack's Docker
    if [ -n "$DOCKER_HOST" ]; then
        echo_warn "Detected DOCKER_HOST pointing to: $DOCKER_HOST"
        echo_info "Unsetting DOCKER_HOST to use OrbStack's Docker..."
        unset DOCKER_HOST
    fi
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if [ "$1" = "k3d" ] && ! command -v k3d &> /dev/null; then
        missing_tools+=("k3d")
    fi

    if [ "$1" = "minikube" ] && ! command -v minikube &> /dev/null; then
        missing_tools+=("minikube")
    fi

    if [ "$1" = "kind" ] && ! command -v kind &> /dev/null; then
        missing_tools+=("kind")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo_error "Missing required tools: ${missing_tools[*]}"
        echo_info "Install with: brew install ${missing_tools[*]}"
        exit 1
    fi
}

# Native OrbStack Kubernetes functions
native_create() {
    echo_header "Creating Native OrbStack Kubernetes Cluster"
    echo_info "Starting OrbStack Kubernetes..."
    orbctl kubernetes start
    echo_info "Waiting for cluster to be ready..."
    sleep 5
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    echo_info "Native OrbStack Kubernetes is ready!"
    native_status
}

native_delete() {
    echo_info "Stopping OrbStack Kubernetes..."
    orbctl kubernetes stop
    echo_info "OrbStack Kubernetes stopped"
}

native_status() {
    echo_header "OrbStack Kubernetes Status"
    if orbctl kubernetes status 2>/dev/null | grep -q "Running"; then
        echo_info "OrbStack Kubernetes: Running ✓"
        kubectl get nodes
        echo ""
        echo_info "Cluster Info:"
        kubectl cluster-info
    else
        echo_warn "OrbStack Kubernetes: Not running"
    fi
}

# k3d functions
k3d_create() {
    echo_header "Creating k3d Cluster on OrbStack"
    check_orbstack
    check_prerequisites "k3d"

    echo_info "Creating k3d cluster '$CLUSTER_NAME'..."

    if [ -f "$K3D_CONFIG_FILE" ]; then
        echo_info "Using config file: $K3D_CONFIG_FILE"
        k3d cluster create --config "$K3D_CONFIG_FILE"
    else
        echo_info "Creating with optimized settings for OrbStack..."
        k3d cluster create $CLUSTER_NAME \
            --servers 1 \
            --agents 2 \
            --port "8080:80@loadbalancer" \
            --port "8443:443@loadbalancer" \
            --registry-create k3d-${CLUSTER_NAME}-registry:0.0.0.0:5000 \
            --k3s-arg "--disable=traefik@server:0" \
            --k3s-arg "--disable=servicelb@server:0" \
            --wait

        echo_info "Installing nginx ingress controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    fi

    echo_info "k3d cluster created successfully!"
    k3d_status
}

k3d_delete() {
    echo_info "Deleting k3d cluster '$CLUSTER_NAME'..."
    k3d cluster delete $CLUSTER_NAME
    echo_info "Cluster deleted"
}

k3d_start() {
    echo_info "Starting k3d cluster '$CLUSTER_NAME'..."
    k3d cluster start $CLUSTER_NAME
    echo_info "Cluster started"
}

k3d_stop() {
    echo_info "Stopping k3d cluster '$CLUSTER_NAME'..."
    k3d cluster stop $CLUSTER_NAME
    echo_info "Cluster stopped"
}

k3d_status() {
    echo_header "k3d Cluster Status"
    k3d cluster list
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        echo ""
        kubectl get nodes
        echo ""
        echo_info "Services:"
        kubectl get svc -A | grep -E "(LoadBalancer|NodePort)" || echo "No exposed services"
    fi
}

# Minikube functions
minikube_create() {
    echo_header "Creating Minikube Cluster on OrbStack"
    check_orbstack
    check_prerequisites "minikube"

    echo_info "Creating minikube cluster..."
    minikube start \
        --driver=docker \
        --cpus=2 \
        --memory=3072 \
        --kubernetes-version=stable \
        --addons=ingress \
        --addons=metrics-server \
        --addons=dashboard

    echo_info "Minikube cluster created successfully!"
    minikube_status
}

minikube_delete() {
    echo_info "Deleting minikube cluster..."
    minikube delete
    echo_info "Cluster deleted"
}

minikube_start() {
    echo_info "Starting minikube cluster..."
    minikube start
    echo_info "Cluster started"
}

minikube_stop() {
    echo_info "Stopping minikube cluster..."
    minikube stop
    echo_info "Cluster stopped"
}

minikube_status() {
    echo_header "Minikube Cluster Status"
    minikube status
    echo ""
    kubectl get nodes
}

minikube_dashboard() {
    echo_info "Opening Minikube dashboard..."
    echo_info "Press Ctrl+C to stop the dashboard"
    minikube dashboard
}

# Kind functions
kind_create() {
    echo_header "Creating Kind Cluster on OrbStack"
    check_orbstack
    check_prerequisites "kind"

    echo_info "Creating kind cluster '$CLUSTER_NAME'..."

    # Create a kind config for better functionality
    cat <<EOF | kind create cluster --name $CLUSTER_NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
- role: worker
- role: worker
EOF

    echo_info "Installing ingress-nginx..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    echo_info "Kind cluster created successfully!"
    kind_status
}

kind_delete() {
    echo_info "Deleting kind cluster '$CLUSTER_NAME'..."
    kind delete cluster --name $CLUSTER_NAME
    echo_info "Cluster deleted"
}

kind_status() {
    echo_header "Kind Cluster Status"
    kind get clusters
    if kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        echo ""
        kubectl get nodes
    else
        echo_warn "Cluster '$CLUSTER_NAME' not found"
    fi
}

# Dashboard function (works for all cluster types)
open_dashboard() {
    echo_header "Opening Kubernetes Dashboard"

    # Check if dashboard is installed
    if ! kubectl get ns kubernetes-dashboard &>/dev/null; then
        echo_info "Installing Kubernetes Dashboard..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
        echo_info "Waiting for dashboard to be ready..."
        kubectl -n kubernetes-dashboard wait --for=condition=Available deployment/kubernetes-dashboard --timeout=300s
    fi

    echo_info "Creating dashboard access token..."

    # Create service account if it doesn't exist
    kubectl create serviceaccount dashboard-admin -n kube-system 2>/dev/null || true
    kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin 2>/dev/null || true

    # Get token
    TOKEN=$(kubectl -n kube-system create token dashboard-admin --duration=8h)

    echo ""
    echo_blue "Dashboard Access Token (valid for 8 hours):"
    echo_blue "════════════════════════════════════════════════════════════════"
    echo "$TOKEN"
    echo_blue "════════════════════════════════════════════════════════════════"
    echo ""
    echo_info "Starting kubectl proxy..."
    echo_info "Access dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    echo_info "Press Ctrl+C to stop the proxy"
    kubectl proxy
}

# Show cluster information
show_info() {
    echo_header "Cluster Information"

    echo_info "Cluster Nodes:"
    kubectl get nodes
    echo ""

    echo_info "Namespaces:"
    kubectl get namespaces
    echo ""

    echo_info "Running Pods:"
    kubectl get pods --all-namespaces
    echo ""

    echo_info "Services:"
    kubectl get svc --all-namespaces
    echo ""

    echo_info "Cluster Info:"
    kubectl cluster-info
}

# Interactive menu
show_menu() {
    echo_header "OrbStack Kubernetes Manager"
    echo "Select Kubernetes distribution:"
    echo ""
    echo "  1) k3d        - Lightweight Kubernetes (k3s in Docker)"
    echo "  2) Minikube   - Full-featured local Kubernetes"
    echo "  3) Kind       - Kubernetes in Docker"
    echo "  4) Native     - OrbStack's built-in Kubernetes"
    echo ""
    echo "  q) Quit"
    echo ""
    read -p "Enter choice [1-4]: " choice

    case $choice in
        1)
            KUBERNETES_TYPE="k3d"
            show_k3d_menu
            ;;
        2)
            KUBERNETES_TYPE="minikube"
            show_minikube_menu
            ;;
        3)
            KUBERNETES_TYPE="kind"
            show_kind_menu
            ;;
        4)
            KUBERNETES_TYPE="native"
            show_native_menu
            ;;
        q|Q)
            exit 0
            ;;
        *)
            echo_error "Invalid choice"
            show_menu
            ;;
    esac
}

show_k3d_menu() {
    echo_header "k3d Cluster Management"
    echo "  1) Create cluster"
    echo "  2) Delete cluster"
    echo "  3) Start cluster"
    echo "  4) Stop cluster"
    echo "  5) Status"
    echo "  6) Cluster info"
    echo "  7) Dashboard"
    echo "  8) Back to main menu"
    echo ""
    read -p "Enter choice [1-8]: " choice

    case $choice in
        1) k3d_create ;;
        2) k3d_delete ;;
        3) k3d_start ;;
        4) k3d_stop ;;
        5) k3d_status ;;
        6) show_info ;;
        7) open_dashboard ;;
        8) show_menu ;;
        *) echo_error "Invalid choice"; show_k3d_menu ;;
    esac
}

show_minikube_menu() {
    echo_header "Minikube Cluster Management"
    echo "  1) Create cluster"
    echo "  2) Delete cluster"
    echo "  3) Start cluster"
    echo "  4) Stop cluster"
    echo "  5) Status"
    echo "  6) Cluster info"
    echo "  7) Dashboard (native)"
    echo "  8) Back to main menu"
    echo ""
    read -p "Enter choice [1-8]: " choice

    case $choice in
        1) minikube_create ;;
        2) minikube_delete ;;
        3) minikube_start ;;
        4) minikube_stop ;;
        5) minikube_status ;;
        6) show_info ;;
        7) minikube_dashboard ;;
        8) show_menu ;;
        *) echo_error "Invalid choice"; show_minikube_menu ;;
    esac
}

show_kind_menu() {
    echo_header "Kind Cluster Management"
    echo "  1) Create cluster"
    echo "  2) Delete cluster"
    echo "  3) Status"
    echo "  4) Cluster info"
    echo "  5) Dashboard"
    echo "  6) Back to main menu"
    echo ""
    read -p "Enter choice [1-6]: " choice

    case $choice in
        1) kind_create ;;
        2) kind_delete ;;
        3) kind_status ;;
        4) show_info ;;
        5) open_dashboard ;;
        6) show_menu ;;
        *) echo_error "Invalid choice"; show_kind_menu ;;
    esac
}

show_native_menu() {
    echo_header "OrbStack Native Kubernetes"
    echo "  1) Start Kubernetes"
    echo "  2) Stop Kubernetes"
    echo "  3) Status"
    echo "  4) Cluster info"
    echo "  5) Dashboard"
    echo "  6) Back to main menu"
    echo ""
    read -p "Enter choice [1-6]: " choice

    case $choice in
        1) native_create ;;
        2) native_delete ;;
        3) native_status ;;
        4) show_info ;;
        5) open_dashboard ;;
        6) show_menu ;;
        *) echo_error "Invalid choice"; show_native_menu ;;
    esac
}

# Command line interface
case "${1:-}" in
    k3d)
        shift
        case "${1:-create}" in
            create) k3d_create ;;
            delete) k3d_delete ;;
            start) k3d_start ;;
            stop) k3d_stop ;;
            status) k3d_status ;;
            info) show_info ;;
            dashboard) open_dashboard ;;
            *) echo "Usage: $0 k3d {create|delete|start|stop|status|info|dashboard}" ;;
        esac
        ;;
    minikube)
        shift
        case "${1:-create}" in
            create) minikube_create ;;
            delete) minikube_delete ;;
            start) minikube_start ;;
            stop) minikube_stop ;;
            status) minikube_status ;;
            info) show_info ;;
            dashboard) minikube_dashboard ;;
            *) echo "Usage: $0 minikube {create|delete|start|stop|status|info|dashboard}" ;;
        esac
        ;;
    kind)
        shift
        case "${1:-create}" in
            create) kind_create ;;
            delete) kind_delete ;;
            status) kind_status ;;
            info) show_info ;;
            dashboard) open_dashboard ;;
            *) echo "Usage: $0 kind {create|delete|status|info|dashboard}" ;;
        esac
        ;;
    native)
        shift
        case "${1:-create}" in
            start|create) native_create ;;
            stop|delete) native_delete ;;
            status) native_status ;;
            info) show_info ;;
            dashboard) open_dashboard ;;
            *) echo "Usage: $0 native {start|stop|status|info|dashboard}" ;;
        esac
        ;;
    menu|"")
        check_orbstack
        show_menu
        ;;
    *)
        echo "OrbStack Kubernetes Setup Script"
        echo ""
        echo "Usage: $0 [type] [command]"
        echo ""
        echo "Types:"
        echo "  k3d       - Use k3d (lightweight k3s in Docker)"
        echo "  minikube  - Use Minikube"
        echo "  kind      - Use Kind (Kubernetes in Docker)"
        echo "  native    - Use OrbStack's native Kubernetes"
        echo "  menu      - Interactive menu (default)"
        echo ""
        echo "Commands:"
        echo "  create    - Create a new cluster"
        echo "  delete    - Delete the cluster"
        echo "  start     - Start an existing cluster"
        echo "  stop      - Stop a running cluster"
        echo "  status    - Show cluster status"
        echo "  info      - Show detailed cluster information"
        echo "  dashboard - Open Kubernetes dashboard"
        echo ""
        echo "Examples:"
        echo "  $0                    # Show interactive menu"
        echo "  $0 k3d create         # Create k3d cluster"
        echo "  $0 minikube dashboard # Open Minikube dashboard"
        echo "  $0 native start       # Start OrbStack Kubernetes"
        exit 1
        ;;
esac