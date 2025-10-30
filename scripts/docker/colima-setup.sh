#!/usr/bin/env bash
# Colima Setup Helper for Dotfiles Testing
# Ensures Colima is running and properly configured

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLIMA_PROFILE="default"
COLIMA_CPU="${COLIMA_CPU:-4}"
COLIMA_MEMORY="${COLIMA_MEMORY:-8}"
COLIMA_DISK="${COLIMA_DISK:-50}"
COLIMA_ARCH="${COLIMA_ARCH:-$(uname -m)}"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if Colima is installed
check_colima_installed() {
    if ! command -v colima &> /dev/null; then
        log_error "Colima is not installed"
        log_info "Install with: brew install colima"
        exit 1
    fi
    log_success "Colima is installed"
}

# Check if Docker CLI is installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker CLI is not installed"
        log_info "Install with: brew install docker"
        exit 1
    fi
    log_success "Docker CLI is installed"
}

# Check Colima status
check_colima_status() {
    if colima status &> /dev/null; then
        log_success "Colima is running"
        return 0
    else
        log_warning "Colima is not running"
        return 1
    fi
}

# Start Colima with optimal settings for testing
start_colima() {
    log_info "Starting Colima with profile: $COLIMA_PROFILE"
    log_info "Configuration: CPU=$COLIMA_CPU, Memory=${COLIMA_MEMORY}GB, Disk=${COLIMA_DISK}GB"

    colima start \
        --profile "$COLIMA_PROFILE" \
        --cpu "$COLIMA_CPU" \
        --memory "$COLIMA_MEMORY" \
        --disk "$COLIMA_DISK" \
        --arch "$COLIMA_ARCH" \
        --runtime docker

    log_success "Colima started successfully"
}

# Verify Docker connectivity
verify_docker() {
    log_info "Verifying Docker connectivity..."

    if ! docker ps &> /dev/null; then
        log_error "Docker is not accessible"
        log_info "DOCKER_HOST: ${DOCKER_HOST:-not set}"
        log_info "Try running: docker context use colima"
        exit 1
    fi

    log_success "Docker is accessible"

    # Show Docker info
    log_info "Docker info:"
    docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}' || true
}

# Display Colima info
show_colima_info() {
    log_info "Colima status:"
    colima list || true

    echo ""
    log_info "Docker context:"
    docker context ls | grep -E "NAME|colima" || true

    echo ""
    log_info "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" || echo "No containers running"
}

# Cleanup function
cleanup_colima() {
    log_warning "Stopping Colima..."
    colima stop
    log_success "Colima stopped"
}

# Main function
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Colima Setup for Dotfiles Testing"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Parse command line arguments
    case "${1:-start}" in
        start)
            check_colima_installed
            check_docker_installed

            if check_colima_status; then
                log_info "Colima is already running"
            else
                start_colima
            fi

            verify_docker
            show_colima_info

            echo ""
            log_success "Colima is ready for Docker testing!"
            log_info "You can now run: ./scripts/docker/test-runner.sh"
            ;;

        stop)
            cleanup_colima
            ;;

        restart)
            if check_colima_status; then
                cleanup_colima
                sleep 2
            fi
            start_colima
            verify_docker
            ;;

        status)
            check_colima_installed
            if check_colima_status; then
                show_colima_info
            fi
            ;;

        info)
            show_colima_info
            ;;

        help|--help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start     Start Colima (default)"
            echo "  stop      Stop Colima"
            echo "  restart   Restart Colima"
            echo "  status    Show Colima status"
            echo "  info      Show detailed Colima and Docker info"
            echo "  help      Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  COLIMA_CPU      Number of CPUs (default: 4)"
            echo "  COLIMA_MEMORY   Memory in GB (default: 8)"
            echo "  COLIMA_DISK     Disk size in GB (default: 50)"
            echo "  COLIMA_ARCH     Architecture (default: $(uname -m))"
            echo ""
            echo "Examples:"
            echo "  $0 start"
            echo "  COLIMA_CPU=8 COLIMA_MEMORY=16 $0 start"
            echo "  $0 stop"
            ;;

        *)
            log_error "Unknown command: $1"
            log_info "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
