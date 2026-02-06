#!/usr/bin/env bash
# Pi-hole Setup & Management Script
# Runs Pi-hole via Colima + Docker for local ad blocking on macOS
#
# Usage:
#   ./scripts/pihole/setup-pihole.sh start      # Start Pi-hole
#   ./scripts/pihole/setup-pihole.sh stop        # Stop Pi-hole
#   ./scripts/pihole/setup-pihole.sh restart     # Restart Pi-hole
#   ./scripts/pihole/setup-pihole.sh status      # Show status
#   ./scripts/pihole/setup-pihole.sh dns-on      # Point macOS DNS to Pi-hole
#   ./scripts/pihole/setup-pihole.sh dns-off     # Restore Cloudflare DNS
#   ./scripts/pihole/setup-pihole.sh logs        # Tail Pi-hole logs
#   ./scripts/pihole/setup-pihole.sh update      # Pull latest Pi-hole image
#   ./scripts/pihole/setup-pihole.sh uninstall   # Remove Pi-hole completely

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
PIHOLE_CONTAINER="pihole"
PIHOLE_WEB_PORT="8053"
CLOUDFLARE_DNS_1="1.1.1.1"
CLOUDFLARE_DNS_2="1.0.0.1"
PIHOLE_DNS="127.0.0.1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}  $1${NC}"; }
log_success() { echo -e "${GREEN}  $1${NC}"; }
log_warning() { echo -e "${YELLOW}  $1${NC}"; }
log_error()   { echo -e "${RED}  $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    local missing=0

    if ! command -v colima &>/dev/null; then
        log_error "Colima is not installed (brew install colima)"
        missing=1
    fi

    if ! command -v docker &>/dev/null; then
        log_error "Docker CLI is not installed (brew install docker)"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

# Ensure Colima is running
ensure_colima() {
    if ! colima status &>/dev/null; then
        log_info "Starting Colima..."
        colima start --cpu 2 --memory 2 --disk 10 --runtime docker
        log_success "Colima started"
    fi
}

# Check if port 53 is already in use
check_port_53() {
    if lsof -i :53 -sTCP:LISTEN &>/dev/null 2>&1; then
        local process
        process=$(lsof -i :53 -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print $1}')
        log_warning "Port 53 is in use by: $process"
        log_info "macOS may have mDNSResponder on port 53."
        log_info "Pi-hole will run inside Colima's VM, which has its own port space."
        log_info "DNS will be routed: macOS -> Colima VM (port-forward) -> Pi-hole container"
    fi
}

# Start Pi-hole
start_pihole() {
    log_info "Starting Pi-hole..."

    ensure_colima
    check_port_53

    # Start the container
    docker compose -f "$COMPOSE_FILE" up -d

    # Wait for Pi-hole to be ready
    log_info "Waiting for Pi-hole to initialize..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if docker exec "$PIHOLE_CONTAINER" pihole status &>/dev/null; then
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        log_warning "Pi-hole may still be initializing. Check logs with: $0 logs"
    else
        log_success "Pi-hole is running"
    fi

    echo ""
    log_info "Web Admin:  http://localhost:${PIHOLE_WEB_PORT}/admin"
    log_info "Password:   \${PIHOLE_PASSWORD:-changeme}"
    echo ""
    log_info "To use Pi-hole as your DNS resolver:"
    log_info "  $0 dns-on"
}

# Stop Pi-hole
stop_pihole() {
    log_info "Stopping Pi-hole..."
    docker compose -f "$COMPOSE_FILE" down
    log_success "Pi-hole stopped"
    log_info "Note: DNS settings are unchanged. Run '$0 dns-off' to restore Cloudflare DNS."
}

# Restart Pi-hole
restart_pihole() {
    log_info "Restarting Pi-hole..."
    docker compose -f "$COMPOSE_FILE" restart
    log_success "Pi-hole restarted"
}

# Show Pi-hole status
status_pihole() {
    echo ""
    log_info "Pi-hole Status"
    echo "────────────────────────────────────"

    # Container status
    if docker ps --filter "name=$PIHOLE_CONTAINER" --format '{{.Status}}' 2>/dev/null | grep -q "Up"; then
        log_success "Container: Running"
        docker ps --filter "name=$PIHOLE_CONTAINER" --format "  Image:     {{.Image}}\n  Status:    {{.Status}}\n  Ports:     {{.Ports}}" 2>/dev/null
    else
        log_error "Container: Not running"
    fi

    echo ""

    # DNS configuration
    log_info "DNS Configuration"
    echo "────────────────────────────────────"
    local wifi_dns
    wifi_dns=$(networksetup -getdnsservers "Wi-Fi" 2>/dev/null || echo "N/A")
    echo "  Wi-Fi DNS: $wifi_dns"

    # Test DNS resolution through Pi-hole
    if docker ps --filter "name=$PIHOLE_CONTAINER" --format '{{.Status}}' 2>/dev/null | grep -q "Up"; then
        echo ""
        log_info "Pi-hole Statistics"
        echo "────────────────────────────────────"
        docker exec "$PIHOLE_CONTAINER" pihole status 2>/dev/null || log_warning "Could not fetch Pi-hole status"
    fi

    echo ""
    log_info "Web Admin: http://localhost:${PIHOLE_WEB_PORT}/admin"
}

# Configure macOS to use Pi-hole as DNS
dns_on() {
    log_info "Configuring macOS to use Pi-hole DNS..."

    # Get all hardware network services (exclude virtual interfaces)
    while IFS= read -r service; do
        # Skip virtual interfaces
        if [[ "$service" == *"Tailscale"* ]] || [[ "$service" == *"Thunderbolt"* ]] || [[ "$service" == *"Bridge"* ]]; then
            continue
        fi

        if sudo networksetup -setdnsservers "$service" $PIHOLE_DNS 2>/dev/null; then
            log_success "Set DNS for $service -> $PIHOLE_DNS"
        fi
    done < <(networksetup -listallnetworkservices 2>/dev/null | tail -n +2)

    # Flush DNS cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true

    log_success "macOS DNS now points to Pi-hole (127.0.0.1)"
    log_info "Ad blocking is active. Test at: https://ads-blocker.com/testing/"
}

# Restore Cloudflare DNS
dns_off() {
    log_info "Restoring Cloudflare DNS..."

    while IFS= read -r service; do
        if [[ "$service" == *"Tailscale"* ]] || [[ "$service" == *"Thunderbolt"* ]] || [[ "$service" == *"Bridge"* ]]; then
            continue
        fi

        if sudo networksetup -setdnsservers "$service" "$CLOUDFLARE_DNS_1" "$CLOUDFLARE_DNS_2" 2>/dev/null; then
            log_success "Set DNS for $service -> $CLOUDFLARE_DNS_1, $CLOUDFLARE_DNS_2"
        fi
    done < <(networksetup -listallnetworkservices 2>/dev/null | tail -n +2)

    # Flush DNS cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true

    log_success "macOS DNS restored to Cloudflare ($CLOUDFLARE_DNS_1, $CLOUDFLARE_DNS_2)"
}

# Tail Pi-hole logs
logs_pihole() {
    docker compose -f "$COMPOSE_FILE" logs -f --tail=50
}

# Update Pi-hole image
update_pihole() {
    log_info "Pulling latest Pi-hole image..."
    docker compose -f "$COMPOSE_FILE" pull
    log_success "Image updated"
    log_info "Restart with: $0 restart"
}

# Uninstall Pi-hole completely
uninstall_pihole() {
    log_warning "This will remove Pi-hole container, volumes, and restore DNS settings."
    read -rp "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Cancelled"
        return
    fi

    # Restore DNS first
    dns_off

    # Stop and remove container + volumes
    docker compose -f "$COMPOSE_FILE" down -v
    log_success "Pi-hole removed"
    log_info "Colima is still running. Stop it with: colima stop"
}

# Main
main() {
    echo ""
    echo -e "${BLUE}Pi-hole DNS Ad Blocker (via Colima + Docker)${NC}"
    echo "════════════════════════════════════════════════"
    echo ""

    check_prerequisites

    case "${1:-help}" in
        start)       start_pihole ;;
        stop)        stop_pihole ;;
        restart)     restart_pihole ;;
        status)      status_pihole ;;
        dns-on)      dns_on ;;
        dns-off)     dns_off ;;
        logs)        logs_pihole ;;
        update)      update_pihole ;;
        uninstall)   uninstall_pihole ;;
        help|--help|-h)
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  start       Start Pi-hole container via Colima"
            echo "  stop        Stop Pi-hole container"
            echo "  restart     Restart Pi-hole container"
            echo "  status      Show Pi-hole and DNS status"
            echo "  dns-on      Point macOS DNS to Pi-hole (127.0.0.1)"
            echo "  dns-off     Restore Cloudflare DNS (1.1.1.1)"
            echo "  logs        Tail Pi-hole container logs"
            echo "  update      Pull latest Pi-hole Docker image"
            echo "  uninstall   Remove Pi-hole and restore DNS"
            echo ""
            echo "Environment Variables:"
            echo "  PIHOLE_PASSWORD   Web admin password (default: changeme)"
            echo ""
            echo "Quick Start:"
            echo "  $0 start      # Start Pi-hole"
            echo "  $0 dns-on     # Activate ad blocking"
            echo "  $0 status     # Check everything"
            echo ""
            echo "Web Admin: http://localhost:${PIHOLE_WEB_PORT}/admin"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
