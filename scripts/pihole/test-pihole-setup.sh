#!/usr/bin/env bash
# Pi-hole Setup Smoke Tests
# Validates the Pi-hole configuration files and scripts are correct
# Does NOT require Docker/Colima to be running (file-level validation only)
#
# Usage: ./scripts/pihole/test-pihole-setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}  PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}  FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo ""
echo -e "${BLUE}Pi-hole Setup Smoke Tests${NC}"
echo "════════════════════════════════════"
echo ""

# File structure tests
echo -e "${BLUE}--- File Structure ---${NC}"
run_test "pihole directory exists" "[ -d '$SCRIPT_DIR' ]"
run_test "docker-compose.yml exists" "[ -f '$SCRIPT_DIR/docker-compose.yml' ]"
run_test "setup-pihole.sh exists" "[ -f '$SCRIPT_DIR/setup-pihole.sh' ]"
run_test "setup-pihole.sh is executable" "[ -x '$SCRIPT_DIR/setup-pihole.sh' ]"
run_test "README.md exists" "[ -f '$SCRIPT_DIR/README.md' ]"
run_test "custom-blocklist.txt exists" "[ -f '$SCRIPT_DIR/custom-blocklist.txt' ]"

echo ""

# Script syntax tests
echo -e "${BLUE}--- Script Syntax ---${NC}"
run_test "setup-pihole.sh syntax valid" "bash -n '$SCRIPT_DIR/setup-pihole.sh'"
run_test "test script syntax valid" "bash -n '$SCRIPT_DIR/test-pihole-setup.sh'"

echo ""

# Docker Compose validation
echo -e "${BLUE}--- Docker Compose ---${NC}"
run_test "docker-compose.yml is valid YAML" "python3 -c \"import yaml; yaml.safe_load(open('$SCRIPT_DIR/docker-compose.yml'))\""
run_test "Compose references pihole/pihole image" "grep -q 'pihole/pihole' '$SCRIPT_DIR/docker-compose.yml'"
run_test "Compose exposes port 53 TCP" "grep -q '53:53/tcp' '$SCRIPT_DIR/docker-compose.yml'"
run_test "Compose exposes port 53 UDP" "grep -q '53:53/udp' '$SCRIPT_DIR/docker-compose.yml'"
run_test "Compose exposes web admin port" "grep -q '8053:80' '$SCRIPT_DIR/docker-compose.yml'"
run_test "Compose uses named volumes" "grep -q 'pihole_config' '$SCRIPT_DIR/docker-compose.yml'"
run_test "Compose sets timezone" "grep -q 'TZ:' '$SCRIPT_DIR/docker-compose.yml'"
run_test "Compose sets upstream DNS" "grep -q 'PIHOLE_DNS_' '$SCRIPT_DIR/docker-compose.yml'"
run_test "DNSSEC enabled" "grep -q 'DNSSEC' '$SCRIPT_DIR/docker-compose.yml'"

echo ""

# Fish function tests
echo -e "${BLUE}--- Fish Shell Integration ---${NC}"
run_test "pihole.fish function exists" "[ -f '$DOTFILES_ROOT/.config/fish/functions/pihole.fish' ]"
run_test "Fish function references setup script" "grep -q 'setup-pihole.sh' '$DOTFILES_ROOT/.config/fish/functions/pihole.fish'"

echo ""

# Setup script feature tests
echo -e "${BLUE}--- Setup Script Features ---${NC}"
run_test "Script has start command" "grep -q 'start_pihole' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script has stop command" "grep -q 'stop_pihole' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script has dns-on command" "grep -q 'dns_on' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script has dns-off command" "grep -q 'dns_off' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script has status command" "grep -q 'status_pihole' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script has update command" "grep -q 'update_pihole' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script has uninstall command" "grep -q 'uninstall_pihole' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script checks for Colima" "grep -q 'colima' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script supports PIHOLE_PASSWORD env" "grep -q 'PIHOLE_PASSWORD' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script restores Cloudflare DNS on dns-off" "grep -q 'CLOUDFLARE_DNS' '$SCRIPT_DIR/setup-pihole.sh'"
run_test "Script skips Tailscale interface" "grep -q 'Tailscale' '$SCRIPT_DIR/setup-pihole.sh'"

echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════${NC}"
echo -e "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
