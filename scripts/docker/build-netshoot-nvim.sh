#!/usr/bin/env bash
# Build the netshoot-nvim Docker image locally
#
# NOTE: For multi-arch builds, use GitHub Actions workflow instead:
#   https://github.com/shaheislam/neovim/actions/workflows/docker-build.yml
#
# This script is for local development/testing only.
# The Dockerfile now lives in ~/neovim/Dockerfile
#
# Usage:
#   ./scripts/docker/build-netshoot-nvim.sh [OPTIONS] [tag]
#
# Options:
#   --local     Build for local architecture only (default, faster)
#   --push      Push to registry after build (single arch only)
#
# Examples:
#   ./scripts/docker/build-netshoot-nvim.sh              # local arch build
#   ./scripts/docker/build-netshoot-nvim.sh --push       # local arch + push
#   ./scripts/docker/build-netshoot-nvim.sh v1.0.0       # with custom tag

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEOVIM_CONFIG="${HOME}/neovim"
DOCKERFILE="${NEOVIM_CONFIG}/Dockerfile"
IMAGE_NAME="netshoot-nvim"
GHCR_IMAGE="ghcr.io/shaheislam/netshoot-nvim"

# Parse arguments
LOCAL_BUILD=true  # Default to local build
PUSH=false
TAG="latest"
for arg in "$@"; do
    case $arg in
        --local)
            LOCAL_BUILD=true
            PUSH=false
            ;;
        --push)
            PUSH=true
            ;;
        *)
            TAG="$arg"
            ;;
    esac
done

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
    log_info "Using Neovim config from: ${NEOVIM_CONFIG}"
    log_info "Using Dockerfile: ${DOCKERFILE}"

    # Local build - single architecture, loads to local Docker
    log_info "Building ${IMAGE_NAME}:${TAG} (local architecture only)..."

    docker build \
        --file "${DOCKERFILE}" \
        --tag "${IMAGE_NAME}:${TAG}" \
        --progress=plain \
        "${NEOVIM_CONFIG}"

    if [[ $? -eq 0 ]]; then
        log_info "Build successful!"
        log_info "Image: ${IMAGE_NAME}:${TAG}"

        if [[ "${PUSH}" == "true" ]]; then
            log_info "Tagging and pushing to ${GHCR_IMAGE}:${TAG}..."
            docker tag "${IMAGE_NAME}:${TAG}" "${GHCR_IMAGE}:${TAG}"
            docker push "${GHCR_IMAGE}:${TAG}"
            log_info "Push successful!"
            log_warn "Note: This is a single-arch image. For multi-arch, use GitHub Actions."
        fi

        echo ""
        log_info "To run the container:"
        echo "  docker run -it --rm ${IMAGE_NAME}:${TAG}"
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

    if [[ "${PUSH}" == "true" ]]; then
        echo ""
        log_info "Image pushed to: ${GHCR_IMAGE}:${TAG}"
        log_info "View at: https://github.com/users/shaheislam/packages/container/package/netshoot-nvim"
        echo ""
        log_info "For multi-arch builds, use GitHub Actions:"
        echo "  https://github.com/shaheislam/neovim/actions/workflows/docker-build.yml"
    fi
}

# Main
main() {
    echo "========================================"
    echo "  Netshoot + Neovim Docker Build (Local)"
    echo "========================================"
    echo ""

    check_prerequisites
    build_image
    show_image_info
}

main "$@"
