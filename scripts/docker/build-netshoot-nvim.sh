#!/usr/bin/env bash
# Build the netshoot-nvim Docker image
#
# This script handles copying the Neovim config from ~/neovim
# to a build context since it lives outside the dotfiles repo.
#
# Usage:
#   ./scripts/docker/build-netshoot-nvim.sh [tag]
#
# Examples:
#   ./scripts/docker/build-netshoot-nvim.sh              # builds netshoot-nvim:latest
#   ./scripts/docker/build-netshoot-nvim.sh v1.0.0       # builds netshoot-nvim:v1.0.0

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}/../.."
DOCKERFILE="${SCRIPT_DIR}/dockerfiles/netshoot-nvim.Dockerfile"
NEOVIM_CONFIG="${HOME}/neovim"
IMAGE_NAME="netshoot-nvim"
TAG="${1:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verify prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if [[ ! -d "${NEOVIM_CONFIG}" ]]; then
        log_error "Neovim config not found at ${NEOVIM_CONFIG}"
        log_error "Please clone your neovim repo: git clone <your-repo> ~/neovim"
        exit 1
    fi

    if [[ ! -f "${DOCKERFILE}" ]]; then
        log_error "Dockerfile not found at ${DOCKERFILE}"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Start it with:"
        log_error "  colima start  # or Docker Desktop"
        exit 1
    fi

    log_info "Prerequisites OK"
}

# Build the image
build_image() {
    log_info "Building ${IMAGE_NAME}:${TAG}..."
    log_info "Using Neovim config from: ${NEOVIM_CONFIG}"
    log_info "Using Dockerfile: ${DOCKERFILE}"

    # Build using the neovim config directory as context
    # The Dockerfile expects the config at the root of the context
    docker build \
        --file "${DOCKERFILE}" \
        --tag "${IMAGE_NAME}:${TAG}" \
        --progress=plain \
        "${NEOVIM_CONFIG}"

    if [[ $? -eq 0 ]]; then
        log_info "Build successful!"
        log_info "Image: ${IMAGE_NAME}:${TAG}"
        echo ""
        log_info "To run the container:"
        echo "  docker run -it --rm ${IMAGE_NAME}:${TAG}"
        echo ""
        log_info "To use in Kubernetes:"
        echo "  kubectl run debug --rm -it --image=${IMAGE_NAME}:${TAG} -- /bin/bash"
    else
        log_error "Build failed!"
        exit 1
    fi
}

# Show image size
show_image_info() {
    echo ""
    log_info "Image details:"
    docker images "${IMAGE_NAME}:${TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Main
main() {
    echo "========================================"
    echo "  Netshoot + Neovim Docker Build"
    echo "========================================"
    echo ""

    check_prerequisites
    build_image
    show_image_info
}

main "$@"
