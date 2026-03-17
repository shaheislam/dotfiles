#!/usr/bin/env bash
# OpenTelemetry LGTM Stack Setup & Management
# Runs grafana/otel-lgtm via Colima + Docker for local observability
#
# Usage:
#   ./scripts/otel/setup-otel.sh start    # Start OTEL LGTM stack
#   ./scripts/otel/setup-otel.sh stop     # Stop stack
#   ./scripts/otel/setup-otel.sh status   # Show status
#   ./scripts/otel/setup-otel.sh open     # Open Grafana in browser
#   ./scripts/otel/setup-otel.sh doctor   # Verify OTEL env + container health
#   ./scripts/otel/setup-otel.sh logs     # Tail container logs
#   ./scripts/otel/setup-otel.sh restart  # Restart container
#   ./scripts/otel/setup-otel.sh update   # Pull latest image
#   ./scripts/otel/setup-otel.sh uninstall # Remove everything

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
CONTAINER_NAME="otel-lgtm"
GRAFANA_PORT="3000"
OTEL_GRPC_PORT="4317"
OTEL_HTTP_PORT="4318"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}  $1${NC}"; }
log_success() { echo -e "${GREEN}  $1${NC}"; }
log_warning() { echo -e "${YELLOW}  $1${NC}"; }
log_error() { echo -e "${RED}  $1${NC}"; }

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
        colima start --cpu 2 --memory 4 --disk 20 --runtime docker
        log_success "Colima started"
    fi
}

# Check if container is running
is_running() {
    docker ps --filter "name=$CONTAINER_NAME" --format '{{.Status}}' 2>/dev/null | grep -q "Up"
}

# Start the LGTM stack
start_otel() {
    log_info "Starting OpenTelemetry LGTM stack..."

    ensure_colima

    docker compose -f "$COMPOSE_FILE" up -d

    # Wait for Grafana to be ready
    log_info "Waiting for Grafana to initialize..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if curl -sf "http://localhost:${GRAFANA_PORT}/api/health" &>/dev/null; then
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        log_warning "Grafana may still be initializing. Check: $0 status"
    else
        log_success "OTEL LGTM stack is running"
    fi

    echo ""
    log_info "Grafana:     http://localhost:${GRAFANA_PORT}"
    log_info "OTEL gRPC:   localhost:${OTEL_GRPC_PORT}"
    log_info "OTEL HTTP:   localhost:${OTEL_HTTP_PORT}"
    echo ""
    log_info "Claude Code will automatically send telemetry when:"
    log_info "  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:${OTEL_HTTP_PORT}"
}

# Stop the LGTM stack
stop_otel() {
    log_info "Stopping OTEL LGTM stack..."
    docker compose -f "$COMPOSE_FILE" down
    log_success "OTEL LGTM stack stopped"
}

# Restart the LGTM stack
restart_otel() {
    log_info "Restarting OTEL LGTM stack..."
    docker compose -f "$COMPOSE_FILE" restart
    log_success "OTEL LGTM stack restarted"
}

# Show status
status_otel() {
    echo ""
    log_info "OpenTelemetry LGTM Stack Status"
    echo "────────────────────────────────────"

    # Container status
    if is_running; then
        log_success "Container: Running"
        docker ps --filter "name=$CONTAINER_NAME" --format "  Image:     {{.Image}}\n  Status:    {{.Status}}\n  Ports:     {{.Ports}}" 2>/dev/null
    else
        log_error "Container: Not running"
        echo ""
        log_info "Start with: $0 start"
        return
    fi

    echo ""

    # Port reachability
    log_info "Port Reachability"
    echo "────────────────────────────────────"
    for port in $GRAFANA_PORT $OTEL_GRPC_PORT $OTEL_HTTP_PORT; do
        if curl -sf --connect-timeout 2 "http://localhost:${port}" &>/dev/null ||
            nc -z localhost "$port" 2>/dev/null; then
            log_success "  Port $port: reachable"
        else
            log_warning "  Port $port: not reachable"
        fi
    done

    echo ""

    # Grafana health
    log_info "Grafana Health"
    echo "────────────────────────────────────"
    local health
    health=$(curl -sf "http://localhost:${GRAFANA_PORT}/api/health" 2>/dev/null || echo '{"database":"error"}')
    echo "  $health"

    echo ""
    log_info "Grafana: http://localhost:${GRAFANA_PORT}"
}

# Open Grafana in browser
open_otel() {
    if is_running; then
        open "http://localhost:${GRAFANA_PORT}"
    else
        log_error "OTEL LGTM stack is not running. Start with: $0 start"
        exit 1
    fi
}

# Doctor check — verify OTEL env vars + container health
doctor_otel() {
    echo ""
    log_info "OTEL Doctor Check"
    echo "════════════════════════════════════"
    local issues=0

    # Check OTEL env vars
    echo ""
    log_info "Environment Variables"
    echo "────────────────────────────────────"

    if [[ "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" == "1" ]]; then
        log_success "CLAUDE_CODE_ENABLE_TELEMETRY=1"
    else
        log_warning "CLAUDE_CODE_ENABLE_TELEMETRY not set (telemetry disabled)"
        issues=$((issues + 1))
    fi

    if [[ "${OTEL_METRICS_EXPORTER:-}" == "otlp" ]]; then
        log_success "OTEL_METRICS_EXPORTER=otlp"
    else
        log_warning "OTEL_METRICS_EXPORTER not set to 'otlp'"
        issues=$((issues + 1))
    fi

    if [[ "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" == *"4318"* ]]; then
        log_success "OTEL_EXPORTER_OTLP_ENDPOINT=$OTEL_EXPORTER_OTLP_ENDPOINT"
    else
        log_warning "OTEL_EXPORTER_OTLP_ENDPOINT not pointing to localhost:4318"
        issues=$((issues + 1))
    fi

    # Check container
    echo ""
    log_info "Container Health"
    echo "────────────────────────────────────"

    if is_running; then
        log_success "Container: Running"
    else
        log_error "Container: Not running"
        issues=$((issues + 1))
    fi

    # Check Grafana reachability
    if curl -sf --connect-timeout 2 "http://localhost:${GRAFANA_PORT}/api/health" &>/dev/null; then
        log_success "Grafana: Reachable at :${GRAFANA_PORT}"
    else
        log_warning "Grafana: Not reachable at :${GRAFANA_PORT}"
        issues=$((issues + 1))
    fi

    # Check OTEL HTTP endpoint
    if curl -sf --connect-timeout 2 "http://localhost:${OTEL_HTTP_PORT}" &>/dev/null ||
        nc -z localhost "$OTEL_HTTP_PORT" 2>/dev/null; then
        log_success "OTEL HTTP: Reachable at :${OTEL_HTTP_PORT}"
    else
        log_warning "OTEL HTTP: Not reachable at :${OTEL_HTTP_PORT}"
        issues=$((issues + 1))
    fi

    # Check settings.json for OTEL config
    echo ""
    log_info "Settings Configuration"
    echo "────────────────────────────────────"
    local settings_file
    for candidate in "$SCRIPT_DIR/../../.claude/settings.json" "$HOME/.claude/settings.json"; do
        if [[ -f "$candidate" ]]; then
            settings_file="$candidate"
            break
        fi
    done

    if [[ -n "${settings_file:-}" ]]; then
        if grep -q "OTEL_METRICS_EXPORTER" "$settings_file" 2>/dev/null; then
            log_success "settings.json has OTEL env vars"
        else
            log_warning "settings.json missing OTEL env vars"
            issues=$((issues + 1))
        fi
    else
        log_warning "No settings.json found"
        issues=$((issues + 1))
    fi

    # Summary
    echo ""
    echo "────────────────────────────────────"
    if [[ $issues -eq 0 ]]; then
        log_success "All checks passed"
    else
        log_warning "$issues issue(s) found"
    fi
}

# Tail logs
logs_otel() {
    docker compose -f "$COMPOSE_FILE" logs -f --tail=50
}

# Update image
update_otel() {
    log_info "Pulling latest OTEL LGTM image..."
    docker compose -f "$COMPOSE_FILE" pull
    log_success "Image updated"
    log_info "Restart with: $0 restart"
}

# Uninstall
uninstall_otel() {
    log_warning "This will remove the OTEL LGTM container and volumes."
    read -rp "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "Cancelled"
        return
    fi

    docker compose -f "$COMPOSE_FILE" down -v
    log_success "OTEL LGTM stack removed"
    log_info "Colima is still running. Stop it with: colima stop"
}

# Main
main() {
    echo ""
    echo -e "${BLUE}OpenTelemetry LGTM Stack (Grafana all-in-one)${NC}"
    echo "════════════════════════════════════════════════"
    echo ""

    check_prerequisites

    case "${1:-help}" in
    start) start_otel ;;
    stop) stop_otel ;;
    restart) restart_otel ;;
    status) status_otel ;;
    open) open_otel ;;
    doctor) doctor_otel ;;
    logs) logs_otel ;;
    update) update_otel ;;
    uninstall) uninstall_otel ;;
    help | --help | -h)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start       Start OTEL LGTM stack via Colima"
        echo "  stop        Stop OTEL LGTM stack"
        echo "  restart     Restart OTEL LGTM stack"
        echo "  status      Show stack and port status"
        echo "  open        Open Grafana in browser"
        echo "  doctor      Verify OTEL env vars + container health"
        echo "  logs        Tail container logs"
        echo "  update      Pull latest Docker image"
        echo "  uninstall   Remove stack and volumes"
        echo ""
        echo "Ports:"
        echo "  3000   Grafana UI"
        echo "  4317   OTEL gRPC receiver"
        echo "  4318   OTEL HTTP receiver"
        echo ""
        echo "Quick Start:"
        echo "  $0 start      # Start stack"
        echo "  $0 open       # Open Grafana"
        echo "  $0 doctor     # Verify everything"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
    esac
}

main "$@"
