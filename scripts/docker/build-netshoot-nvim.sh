#!/usr/bin/env bash
# Build the netshoot-nvim Docker image (multi-arch: amd64 + arm64)
#
# This script handles copying the Neovim config from ~/neovim
# to a build context since it lives outside the dotfiles repo.
#
# Usage:
#   ./scripts/docker/build-netshoot-nvim.sh [OPTIONS] [tag]
#
# Options:
#   --local     Build for local architecture only (faster, no push)
#   --push      Push to registry after build (default for multi-arch)
#
# Examples:
#   ./scripts/docker/build-netshoot-nvim.sh              # multi-arch build + push to ghcr.io
#   ./scripts/docker/build-netshoot-nvim.sh --local      # local arch only, no push
#   ./scripts/docker/build-netshoot-nvim.sh v1.0.0       # multi-arch with custom tag

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}/../.."
DOCKERFILE="${SCRIPT_DIR}/dockerfiles/netshoot-nvim.Dockerfile"
NEOVIM_CONFIG="${HOME}/neovim"
IMAGE_NAME="netshoot-nvim"
GHCR_IMAGE="ghcr.io/shaheislam/netshoot-nvim"

# Parse arguments
LOCAL_BUILD=false
TAG="latest"
for arg in "$@"; do
    case $arg in
        --local)
            LOCAL_BUILD=true
            ;;
        --push)
            LOCAL_BUILD=false
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

    if [[ "${LOCAL_BUILD}" == "true" ]]; then
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
            echo ""
            log_info "To run the container:"
            echo "  docker run -it --rm ${IMAGE_NAME}:${TAG}"
        else
            log_error "Build failed!"
            exit 1
        fi
    else
        # Multi-arch build - requires push to registry (can't load multi-arch locally)
        log_info "Building ${GHCR_IMAGE}:${TAG} (multi-arch: amd64 + arm64)..."
        log_warn "Multi-arch build requires pushing to registry (can't load locally)"
        log_info "This will take longer due to cross-platform compilation..."
        echo ""

        # Ensure buildx builder exists
        if ! docker buildx inspect multiarch &> /dev/null; then
            log_info "Creating buildx builder 'multiarch'..."
            docker buildx create --name multiarch --use
        else
            docker buildx use multiarch
        fi

        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --file "${DOCKERFILE}" \
            --tag "${GHCR_IMAGE}:${TAG}" \
            --progress=plain \
            --push \
            "${NEOVIM_CONFIG}"

        if [[ $? -eq 0 ]]; then
            log_info "Build and push successful!"
            log_info "Image: ${GHCR_IMAGE}:${TAG}"
            echo ""
            log_info "To use in Kubernetes:"
            echo "  kubectl debug <pod> -it --image=${GHCR_IMAGE}:${TAG} --share-processes -- bash"
        else
            log_error "Build failed!"
            exit 1
        fi
    fi
}

# Show image size
show_image_info() {
    echo ""
    if [[ "${LOCAL_BUILD}" == "true" ]]; then
        log_info "Image details:"
        docker images "${IMAGE_NAME}:${TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    else
        log_info "Image pushed to: ${GHCR_IMAGE}:${TAG}"
        log_info "View at: https://github.com/users/shaheislam/packages/container/package/netshoot-nvim"
    fi
}

# Main
main() {
    echo "========================================"
    if [[ "${LOCAL_BUILD}" == "true" ]]; then
        echo "  Netshoot + Neovim Docker Build (Local)"
    else
        echo "  Netshoot + Neovim Docker Build (Multi-Arch)"
    fi
    echo "========================================"
    echo ""

    check_prerequisites
    build_image
    show_image_info
}

main "$@"
