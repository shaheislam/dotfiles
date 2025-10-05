#!/bin/bash

# Container Runtime Detection Helper
# This script detects which container runtime is available and sets appropriate environment variables
# Source this script from other scripts that need container runtime detection

# Colors for output (if not already defined)
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
fi

# Helper functions (if not already defined)
if ! type echo_info &> /dev/null; then
    echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
fi

if ! type echo_warn &> /dev/null; then
    echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fi

if ! type echo_error &> /dev/null; then
    echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fi

# Main detection function
detect_container_runtime() {
    # Variables to export
    CONTAINER_RUNTIME=""
    RUNTIME_NAME=""
    DOCKER_DRIVER=""

    # Priority 1: OrbStack (preferred for macOS)
    if command -v orbctl &> /dev/null && orbctl status &> /dev/null 2>&1; then
        echo_info "OrbStack detected and running"

        # Clear any Podman DOCKER_HOST settings
        if [[ "$DOCKER_HOST" == *"podman"* ]]; then
            echo_warn "Clearing Podman DOCKER_HOST to use OrbStack"
            unset DOCKER_HOST
        fi

        CONTAINER_RUNTIME="docker"
        RUNTIME_NAME="OrbStack"
        DOCKER_DRIVER="docker"
        export CONTAINER_RUNTIME RUNTIME_NAME DOCKER_DRIVER
        return 0
    fi

    # Priority 2: Docker Desktop
    if command -v docker &> /dev/null && docker ps &> /dev/null 2>&1; then
        # Check if it's not Podman masquerading as Docker
        if ! docker version 2>&1 | grep -q podman; then
            echo_info "Docker Desktop detected and running"

            # Clear any Podman DOCKER_HOST settings
            if [[ "$DOCKER_HOST" == *"podman"* ]]; then
                echo_warn "Clearing Podman DOCKER_HOST to use Docker"
                unset DOCKER_HOST
            fi

            CONTAINER_RUNTIME="docker"
            RUNTIME_NAME="Docker Desktop"
            DOCKER_DRIVER="docker"
            export CONTAINER_RUNTIME RUNTIME_NAME DOCKER_DRIVER
            return 0
        fi
    fi

    # Priority 3: Podman
    if command -v podman &> /dev/null; then
        if podman machine list 2>/dev/null | grep -qE "Currently running"; then
            echo_info "Podman detected and running"

            # Get and set Podman socket for Docker compatibility
            PODMAN_SOCKET=$(podman machine inspect podman-machine-default --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null)

            if [ -n "$PODMAN_SOCKET" ]; then
                export DOCKER_HOST="unix://${PODMAN_SOCKET}"
                echo_info "Setting DOCKER_HOST to Podman socket: $DOCKER_HOST"

                CONTAINER_RUNTIME="podman"
                RUNTIME_NAME="Podman"
                DOCKER_DRIVER="podman"
                export CONTAINER_RUNTIME RUNTIME_NAME DOCKER_DRIVER
                return 0
            else
                echo_warn "Podman is running but couldn't get socket path"
            fi
        fi
    fi

    # No runtime found
    echo_error "No container runtime detected or running"
    echo_info "Please start one of the following:"
    echo_info "  • OrbStack (recommended for macOS): open -a OrbStack"
    echo_info "  • Docker Desktop: open -a Docker"
    echo_info "  • Podman: podman machine start"

    return 1
}

# Function to display detected runtime info
show_runtime_info() {
    echo_info "Container Runtime Configuration:"
    echo_info "  Runtime: ${RUNTIME_NAME:-Not detected}"
    echo_info "  Type: ${CONTAINER_RUNTIME:-Not set}"
    echo_info "  Driver: ${DOCKER_DRIVER:-Not set}"
    if [ -n "$DOCKER_HOST" ]; then
        echo_info "  DOCKER_HOST: $DOCKER_HOST"
    else
        echo_info "  DOCKER_HOST: Using default socket"
    fi
}

# Function to check if runtime supports Kubernetes
check_kubernetes_support() {
    case "$CONTAINER_RUNTIME" in
        docker)
            # Docker/OrbStack supports all Kubernetes tools
            return 0
            ;;
        podman)
            # Podman has limitations with some Kubernetes tools on macOS
            echo_warn "Note: Podman on macOS has limited Kubernetes support"
            echo_warn "Some features may not work as expected"
            return 0
            ;;
        *)
            echo_error "Unknown runtime for Kubernetes support check"
            return 1
            ;;
    esac
}

# Auto-detect if sourced directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being run directly, not sourced
    detect_container_runtime
    show_runtime_info
    check_kubernetes_support
fi