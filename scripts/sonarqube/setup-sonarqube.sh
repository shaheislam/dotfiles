#!/usr/bin/env bash
# SonarQube Setup & Management Script
# Runs SonarQube Community Edition via Colima + Docker for local code quality analysis
#
# Usage:
#   ./scripts/sonarqube/setup-sonarqube.sh start       # Start SonarQube
#   ./scripts/sonarqube/setup-sonarqube.sh stop         # Stop SonarQube
#   ./scripts/sonarqube/setup-sonarqube.sh restart      # Restart SonarQube
#   ./scripts/sonarqube/setup-sonarqube.sh status       # Show status
#   ./scripts/sonarqube/setup-sonarqube.sh scan [dir]   # Scan a project
#   ./scripts/sonarqube/setup-sonarqube.sh logs         # Tail SonarQube logs
#   ./scripts/sonarqube/setup-sonarqube.sh token        # Generate API token
#   ./scripts/sonarqube/setup-sonarqube.sh update       # Pull latest image
#   ./scripts/sonarqube/setup-sonarqube.sh uninstall    # Remove SonarQube completely

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
SONARQUBE_CONTAINER="sonarqube"
SONARQUBE_PORT="${SONARQUBE_PORT:-9000}"
SONARQUBE_URL="http://localhost:${SONARQUBE_PORT}"
TOKEN_FILE="$HOME/.config/sonarqube/token"

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

# Wait for SonarQube to be ready (can take 1-2 minutes on first start)
wait_for_ready() {
    local max_attempts="${1:-60}"
    local attempt=0
    log_info "Waiting for SonarQube to start (this can take 1-2 minutes)..."

    while [[ $attempt -lt $max_attempts ]]; do
        local status
        status=$(curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")

        if [[ "$status" == "UP" ]]; then
            log_success "SonarQube is ready"
            return 0
        fi

        if [[ -n "$status" ]]; then
            printf "\r  Status: %-20s" "$status"
        fi

        sleep 2
        attempt=$((attempt + 1))
    done

    echo ""
    log_warning "SonarQube may still be starting. Check: ${SONARQUBE_URL}"
    return 1
}

# Read stored token
get_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        cat "$TOKEN_FILE"
    else
        echo ""
    fi
}

# Start SonarQube
start_sonarqube() {
    check_prerequisites
    ensure_colima

    log_info "Starting SonarQube Community Edition..."

    # Check vm.max_map_count for Elasticsearch (inside Colima VM)
    local map_count
    map_count=$(colima ssh -- sysctl -n vm.max_map_count 2>/dev/null || echo "0")
    if [[ "$map_count" -lt 262144 ]]; then
        log_info "Setting vm.max_map_count in Colima VM..."
        colima ssh -- sudo sysctl -w vm.max_map_count=262144 >/dev/null 2>&1
    fi

    docker compose -f "$COMPOSE_FILE" up -d

    wait_for_ready

    echo ""
    log_success "SonarQube is running"
    echo "  Web UI:    ${SONARQUBE_URL}"
    echo "  Default:   admin / admin (change on first login)"
    echo ""
    echo "  Quick scan:"
    echo "    sonarqube scan             # Scan current directory"
    echo "    sonarqube scan ~/project   # Scan specific project"
}

# Stop SonarQube
stop_sonarqube() {
    check_prerequisites

    log_info "Stopping SonarQube..."
    docker compose -f "$COMPOSE_FILE" down
    log_success "SonarQube stopped"
}

# Restart SonarQube
restart_sonarqube() {
    stop_sonarqube
    start_sonarqube
}

# Show status
show_status() {
    echo "=== SonarQube Status ==="
    echo ""

    # Container status
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${SONARQUBE_CONTAINER}$"; then
        log_success "Container: running"

        # Server status
        local status
        status=$(curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unreachable")
        echo "  Server:    $status"
        echo "  Web UI:    ${SONARQUBE_URL}"

        # Version
        local version
        version=$(curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "  Version:   $version"

        # Project count
        local projects
        projects=$(curl -sf "${SONARQUBE_URL}/api/projects/search" 2>/dev/null | grep -o '"total":[0-9]*' | cut -d: -f2 || echo "?")
        echo "  Projects:  $projects"

        # Token status
        if [[ -f "$TOKEN_FILE" ]]; then
            echo "  Token:     configured ($TOKEN_FILE)"
        else
            echo "  Token:     not configured (run: sonarqube token)"
        fi
    else
        log_warning "Container: not running"
        echo "  Start with: sonarqube start"
    fi

    # sonar-scanner CLI
    echo ""
    if command -v sonar-scanner &>/dev/null; then
        local scanner_version
        scanner_version=$(sonar-scanner --version 2>&1 | head -1 || echo "unknown")
        echo "  Scanner:   $scanner_version"
    else
        log_warning "sonar-scanner not installed (brew install sonar-scanner)"
    fi

    # Disk usage
    echo ""
    local data_size
    data_size=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep sonarqube | while read -r vol; do
        docker system df -v 2>/dev/null | grep "$vol" | awk '{print $4}' || true
    done | head -1)
    if [[ -n "$data_size" ]]; then
        echo "  Storage:   ~${data_size}"
    fi
}

# Generate API token for sonar-scanner
generate_token() {
    check_prerequisites

    # Check if server is running
    if ! curl -sf "${SONARQUBE_URL}/api/system/status" >/dev/null 2>&1; then
        log_error "SonarQube is not running. Start with: sonarqube start"
        exit 1
    fi

    log_info "Generating SonarQube API token..."

    # Try with default credentials first, then stored token
    local token_name="dotfiles-scanner-$(date +%Y%m%d)"
    local response

    # Attempt token creation with admin credentials
    response=$(curl -sf -u admin:admin \
        -X POST "${SONARQUBE_URL}/api/user_tokens/generate" \
        -d "name=${token_name}" \
        -d "type=GLOBAL_ANALYSIS_TOKEN" 2>/dev/null || echo "")

    if [[ -z "$response" ]]; then
        # Default password may have been changed
        log_warning "Could not authenticate with default credentials."
        echo ""
        echo "Generate a token manually:"
        echo "  1. Open ${SONARQUBE_URL}"
        echo "  2. Go to My Account > Security > Generate Tokens"
        echo "  3. Create a 'Global Analysis Token'"
        echo "  4. Save it: mkdir -p ~/.config/sonarqube && echo 'YOUR_TOKEN' > ~/.config/sonarqube/token"
        return 1
    fi

    local token
    token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

    if [[ -n "$token" ]]; then
        mkdir -p "$(dirname "$TOKEN_FILE")"
        echo "$token" >"$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        log_success "Token generated and saved to $TOKEN_FILE"
        echo "  Token name: $token_name"
    else
        log_error "Token generation failed. Check SonarQube logs."
        return 1
    fi
}

# Scan a project
scan_project() {
    local project_dir="${1:-.}"
    project_dir="$(cd "$project_dir" && pwd)"

    # Verify sonar-scanner is installed
    if ! command -v sonar-scanner &>/dev/null; then
        log_error "sonar-scanner not installed. Run: brew install sonar-scanner"
        exit 1
    fi

    # Verify SonarQube is running
    if ! curl -sf "${SONARQUBE_URL}/api/system/status" >/dev/null 2>&1; then
        log_error "SonarQube is not running. Start with: sonarqube start"
        exit 1
    fi

    # Get or prompt for token
    local token
    token=$(get_token)
    if [[ -z "$token" ]]; then
        log_warning "No token found. Generating one..."
        generate_token
        token=$(get_token)
        if [[ -z "$token" ]]; then
            log_error "Cannot scan without a token"
            exit 1
        fi
    fi

    # Derive project key from directory name
    local project_key
    project_key=$(basename "$project_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    log_info "Scanning: $project_dir"
    log_info "Project:  $project_key"
    echo ""

    # Build scanner arguments
    local scanner_args=(
        "-Dsonar.projectKey=$project_key"
        "-Dsonar.projectName=$(basename "$project_dir")"
        "-Dsonar.sources=."
        "-Dsonar.host.url=${SONARQUBE_URL}"
        "-Dsonar.token=${token}"
        "-Dsonar.projectBaseDir=${project_dir}"
    )

    # Check for existing sonar-project.properties
    if [[ -f "$project_dir/sonar-project.properties" ]]; then
        log_info "Using existing sonar-project.properties"
    fi

    # Detect common exclusions
    local exclusions=""
    [[ -d "$project_dir/node_modules" ]] && exclusions="node_modules/**,"
    [[ -d "$project_dir/.git" ]] && exclusions="${exclusions}.git/**,"
    [[ -d "$project_dir/vendor" ]] && exclusions="${exclusions}vendor/**,"
    [[ -d "$project_dir/dist" ]] && exclusions="${exclusions}dist/**,"
    [[ -d "$project_dir/build" ]] && exclusions="${exclusions}build/**,"
    [[ -d "$project_dir/.next" ]] && exclusions="${exclusions}.next/**,"
    [[ -d "$project_dir/target" ]] && exclusions="${exclusions}target/**,"

    if [[ -n "$exclusions" ]]; then
        scanner_args+=("-Dsonar.exclusions=${exclusions%,}")
    fi

    # Run the scanner
    sonar-scanner "${scanner_args[@]}"

    echo ""
    log_success "Scan complete"
    echo "  Results: ${SONARQUBE_URL}/dashboard?id=${project_key}"
}

# Tail logs
tail_logs() {
    docker compose -f "$COMPOSE_FILE" logs -f --tail=50
}

# Pull latest image
update_image() {
    log_info "Pulling latest SonarQube Community Edition image..."
    docker compose -f "$COMPOSE_FILE" pull
    log_success "Image updated. Restart with: sonarqube restart"
}

# Uninstall
uninstall() {
    log_warning "This will remove SonarQube and all scan data."
    read -rp "Continue? [y/N] " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Cancelled."
        return 0
    fi

    log_info "Stopping and removing SonarQube..."
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true

    if [[ -f "$TOKEN_FILE" ]]; then
        rm -f "$TOKEN_FILE"
        log_info "Removed stored token"
    fi

    log_success "SonarQube removed"
}

# Main
case "${1:-status}" in
start) start_sonarqube ;;
stop) stop_sonarqube ;;
restart) restart_sonarqube ;;
status) show_status ;;
scan) scan_project "${2:-}" ;;
logs) tail_logs ;;
token) generate_token ;;
update) update_image ;;
uninstall) uninstall ;;
*)
    echo "SonarQube Manager - Local Code Quality Analysis"
    echo ""
    echo "Usage: $(basename "$0") <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start       Start SonarQube server"
    echo "  stop        Stop SonarQube server"
    echo "  restart     Restart SonarQube server"
    echo "  status      Show server and scanner status"
    echo "  scan [dir]  Scan a project (default: current directory)"
    echo "  logs        Tail SonarQube server logs"
    echo "  token       Generate API token for scanner"
    echo "  update      Pull latest Docker image"
    echo "  uninstall   Remove SonarQube and all data"
    ;;
esac
