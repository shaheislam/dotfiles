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
#   ./scripts/sonarqube/setup-sonarqube.sh doctor        # Preflight health check
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

# Check if port is available
check_port() {
    local port="$1"
    if lsof -i ":${port}" -sTCP:LISTEN &>/dev/null 2>&1; then
        local process
        process=$(lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print $1}')
        # If it's our own container, that's fine
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${SONARQUBE_CONTAINER}$"; then
            return 0
        fi
        log_error "Port ${port} is already in use by: ${process}"
        log_info "Set SONARQUBE_PORT to use a different port"
        return 1
    fi
    return 0
}

# Wait for SonarQube to be ready (can take 1-2 minutes on first start)
wait_for_ready() {
    local max_attempts="${1:-90}"
    local attempt=0
    log_info "Waiting for SonarQube to be ready..."
    log_info "(First start pulls Elasticsearch indexes - may take 2-3 minutes)"

    while [[ $attempt -lt $max_attempts ]]; do
        local status
        status=$(curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")

        if [[ "$status" == "UP" ]]; then
            echo ""
            log_success "SonarQube is ready"
            return 0
        fi

        if [[ -n "$status" ]]; then
            printf "\r  Status: %-20s" "$status"
        else
            printf "\r  Status: %-20s" "connecting..."
        fi

        sleep 2
        attempt=$((attempt + 1))
    done

    echo ""
    log_warning "SonarQube may still be starting. Check: ${SONARQUBE_URL}"
    return 1
}

# Read stored token (prefers SONAR_TOKEN env var)
get_token() {
    if [[ -n "${SONAR_TOKEN:-}" ]]; then
        echo "$SONAR_TOKEN"
    elif [[ -f "$TOKEN_FILE" ]]; then
        cat "$TOKEN_FILE"
    else
        echo ""
    fi
}

# Start SonarQube
start_sonarqube() {
    check_prerequisites

    # Check port before starting
    if ! check_port "$SONARQUBE_PORT"; then
        exit 1
    fi

    ensure_colima

    log_info "Starting SonarQube Community Edition..."

    # Check vm.max_map_count for Elasticsearch (inside Colima VM)
    local map_count
    map_count=$(colima ssh -- sysctl -n vm.max_map_count 2>/dev/null || echo "0")
    if [[ "$map_count" -lt 262144 ]]; then
        log_info "Setting vm.max_map_count in Colima VM (required by Elasticsearch)..."
        colima ssh -- sudo sysctl -w vm.max_map_count=262144 >/dev/null 2>&1
    fi

    docker compose -f "$COMPOSE_FILE" up -d

    wait_for_ready

    echo ""
    log_success "SonarQube is running"
    echo "  Web UI:    ${SONARQUBE_URL}"
    echo "  Default:   admin / admin (change on first login)"
    echo ""
    echo "  Next steps:"
    echo "    sonarqube token            # Generate scanner token"
    echo "    sonarqube scan ~/project   # Scan a project"
    echo "    sonarqube doctor           # Verify full setup"
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

# Preflight health check
run_doctor() {
    echo "=== SonarQube Doctor ==="
    echo ""
    local issues=0

    # 1. Colima
    if command -v colima &>/dev/null; then
        if colima status &>/dev/null; then
            log_success "Colima: running"
        else
            log_warning "Colima: installed but not running"
            echo "    Fix: colima start --cpu 2 --memory 4 --disk 20 --runtime docker"
            issues=$((issues + 1))
        fi
    else
        log_error "Colima: not installed"
        echo "    Fix: brew install colima"
        issues=$((issues + 1))
    fi

    # 2. Docker
    if command -v docker &>/dev/null; then
        if docker info &>/dev/null 2>&1; then
            log_success "Docker: available"
        else
            log_warning "Docker: installed but daemon not reachable"
            echo "    Fix: ensure Colima is running (colima start)"
            issues=$((issues + 1))
        fi
    else
        log_error "Docker: not installed"
        echo "    Fix: brew install docker docker-compose"
        issues=$((issues + 1))
    fi

    # 3. Port availability
    if check_port "$SONARQUBE_PORT" 2>/dev/null; then
        log_success "Port ${SONARQUBE_PORT}: available"
    else
        issues=$((issues + 1))
    fi

    # 4. sonar-scanner CLI
    if command -v sonar-scanner &>/dev/null; then
        local scanner_version
        scanner_version=$(sonar-scanner --version 2>&1 | head -1 || echo "unknown")
        log_success "sonar-scanner: $scanner_version"
    else
        log_error "sonar-scanner: not installed"
        echo "    Fix: brew install sonar-scanner"
        issues=$((issues + 1))
    fi

    # 5. Token
    local token
    token=$(get_token)
    if [[ -n "$token" ]]; then
        if [[ -n "${SONAR_TOKEN:-}" ]]; then
            log_success "Token: set via SONAR_TOKEN env var"
        else
            local perms
            perms=$(stat -f '%Lp' "$TOKEN_FILE" 2>/dev/null || stat -c '%a' "$TOKEN_FILE" 2>/dev/null || echo "???")
            if [[ "$perms" == "600" ]]; then
                log_success "Token: configured ($TOKEN_FILE, mode 600)"
            else
                log_warning "Token: configured but file permissions are $perms (should be 600)"
                echo "    Fix: chmod 600 $TOKEN_FILE"
                issues=$((issues + 1))
            fi
        fi
    else
        log_warning "Token: not configured"
        echo "    Fix: sonarqube token  (or set SONAR_TOKEN env var)"
        issues=$((issues + 1))
    fi

    # 6. SonarQube server
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${SONARQUBE_CONTAINER}$"; then
        local status
        status=$(curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unreachable")
        if [[ "$status" == "UP" ]]; then
            log_success "Server: UP at ${SONARQUBE_URL}"
        else
            log_warning "Server: container running but status is '$status'"
            echo "    May still be starting. Check: ${SONARQUBE_URL}"
            issues=$((issues + 1))
        fi
    else
        log_warning "Server: not running"
        echo "    Fix: sonarqube start"
        issues=$((issues + 1))
    fi

    # 7. vm.max_map_count (if Colima is running)
    if colima status &>/dev/null 2>&1; then
        local map_count
        map_count=$(colima ssh -- sysctl -n vm.max_map_count 2>/dev/null || echo "0")
        if [[ "$map_count" -ge 262144 ]]; then
            log_success "vm.max_map_count: $map_count (OK)"
        else
            log_warning "vm.max_map_count: $map_count (needs >=262144 for Elasticsearch)"
            echo "    Fix: colima ssh -- sudo sysctl -w vm.max_map_count=262144"
            issues=$((issues + 1))
        fi
    fi

    echo ""
    if [[ $issues -eq 0 ]]; then
        log_success "All checks passed - SonarQube is ready to use"
    else
        log_warning "$issues issue(s) found"
    fi
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
        if [[ -n "${SONAR_TOKEN:-}" ]]; then
            echo "  Token:     set via SONAR_TOKEN env var"
        elif [[ -f "$TOKEN_FILE" ]]; then
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

    # Try with default credentials first
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
        echo "  4. Save it securely (choose one):"
        echo ""
        echo "     # Option A: File (chmod 600 applied automatically)"
        echo "     mkdir -p ~/.config/sonarqube"
        echo "     echo 'YOUR_TOKEN' > ~/.config/sonarqube/token"
        echo "     chmod 600 ~/.config/sonarqube/token"
        echo ""
        echo "     # Option B: Environment variable (add to Fish config)"
        echo "     set -Ux SONAR_TOKEN 'YOUR_TOKEN'"
        return 1
    fi

    local token
    token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

    if [[ -n "$token" ]]; then
        mkdir -p "$(dirname "$TOKEN_FILE")"
        # Write token to file, not to shell history
        printf '%s' "$token" >"$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        log_success "Token generated and saved to $TOKEN_FILE (mode 600)"
        echo "  Token name: $token_name"
        echo ""
        echo "  Alternative: set SONAR_TOKEN env var instead of file:"
        echo "    set -Ux SONAR_TOKEN (cat $TOKEN_FILE)"
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

    # Verify SonarQube is running and UP
    local server_status
    server_status=$(curl -sf "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
    if [[ "$server_status" != "UP" ]]; then
        if [[ -z "$server_status" ]]; then
            log_error "SonarQube is not running. Start with: sonarqube start"
        else
            log_error "SonarQube is not ready (status: $server_status). Wait or restart."
        fi
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
        "-Dsonar.qualitygate.wait=true"
        "-Dsonar.qualitygate.timeout=120"
    )

    # Check for existing sonar-project.properties
    if [[ -f "$project_dir/sonar-project.properties" ]]; then
        log_info "Using existing sonar-project.properties"
    fi

    # Detect common exclusions (only if no properties file)
    if [[ ! -f "$project_dir/sonar-project.properties" ]]; then
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
    fi

    # Run the scanner
    sonar-scanner "${scanner_args[@]}"
    local scan_exit=$?

    echo ""
    if [[ $scan_exit -eq 0 ]]; then
        log_success "Scan complete - quality gate PASSED"
    else
        log_warning "Scan complete - quality gate may have FAILED (exit code: $scan_exit)"
    fi
    echo "  Results: ${SONARQUBE_URL}/dashboard?id=${project_key}"
    return $scan_exit
}

# Initialize a project with sonar-project.properties
init_project() {
    local project_dir="${1:-.}"
    project_dir="$(cd "$project_dir" && pwd)"

    local props_file="$project_dir/sonar-project.properties"
    local template="$SCRIPT_DIR/sonar-project.properties.template"

    if [[ -f "$props_file" ]]; then
        log_warning "sonar-project.properties already exists in $project_dir"
        return 1
    fi

    if [[ ! -f "$template" ]]; then
        log_error "Template not found at $template"
        return 1
    fi

    local project_key
    project_key=$(basename "$project_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    local project_name
    project_name=$(basename "$project_dir")

    sed -e "s/sonar.projectKey=my-project/sonar.projectKey=$project_key/" \
        -e "s/sonar.projectName=My Project/sonar.projectName=$project_name/" \
        "$template" >"$props_file"

    log_success "Created $props_file"
    echo "  Project key: $project_key"
    echo ""
    echo "  Edit to customize source paths and exclusions, then:"
    echo "    sonarqube scan $project_dir"
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
    log_info "Note: SONAR_TOKEN env var (if set) was not removed"
}

# Main
case "${1:-status}" in
start) start_sonarqube ;;
stop) stop_sonarqube ;;
restart) restart_sonarqube ;;
status) show_status ;;
scan) scan_project "${2:-}" ;;
init) init_project "${2:-}" ;;
doctor) run_doctor ;;
logs) tail_logs ;;
token) generate_token ;;
update) update_image ;;
uninstall) uninstall ;;
*)
    echo "SonarQube Manager - Local Code Quality Analysis (Community Edition)"
    echo ""
    echo "Usage: $(basename "$0") <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start       Start SonarQube server (Colima + Docker)"
    echo "  stop        Stop SonarQube server"
    echo "  restart     Restart SonarQube server"
    echo "  status      Show server and scanner status"
    echo "  doctor      Preflight check (Colima, Docker, port, scanner, token)"
    echo "  scan [dir]  Scan a project with quality gate enforcement"
    echo "  init [dir]  Create sonar-project.properties from template"
    echo "  logs        Tail SonarQube server logs"
    echo "  token       Generate API token for scanner"
    echo "  update      Pull latest Docker image"
    echo "  uninstall   Remove SonarQube and all data"
    echo ""
    echo "Token storage (choose one):"
    echo "  File:  ~/.config/sonarqube/token (chmod 600)"
    echo "  Env:   set -Ux SONAR_TOKEN 'your-token'"
    echo ""
    echo "Language support (CE, no plugins needed):"
    echo "  JavaScript, TypeScript, Python, Java, Go, PHP, Ruby, Scala,"
    echo "  Kotlin, HTML, CSS, XML. Others need marketplace plugins."
    ;;
esac
