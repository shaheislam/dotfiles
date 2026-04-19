#!/usr/bin/env bash

# Multi-Distribution Docker Test Runner
# Builds and tests dotfiles across all supported Linux distributions

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test results
declare -A BUILD_RESULTS
declare -A TEST_RESULTS
declare -A BUILD_TIMES
declare -A TEST_TIMES

# Supported distributions
DISTRIBUTIONS=("ubuntu" "debian" "fedora" "arch" "alpine")

# Default settings
PARALLEL=false
BUILD_ONLY=false
TEST_ONLY=false
SELECTED_DISTROS=()
VERBOSE=false

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
	echo ""
	echo -e "${BOLD}${BLUE}===================================================================${NC}"
	echo -e "${BOLD}${BLUE}  $1${NC}"
	echo -e "${BOLD}${BLUE}===================================================================${NC}"
	echo ""
}

print_step() {
	echo -e "${BLUE}▶${NC} $1"
}

print_success() {
	echo -e "${GREEN}✓${NC} $1"
}

print_error() {
	echo -e "${RED}✗${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
}

show_usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DISTROS...]

Multi-distribution Docker testing for dotfiles.

OPTIONS:
    -h, --help          Show this help message
    -p, --parallel      Run tests in parallel (default: sequential)
    -b, --build-only    Only build images, don't run tests
    -t, --test-only     Only run tests, don't build images
    -v, --verbose       Show detailed build and test output
    --clean             Clean up existing images before building

DISTROS:
    ubuntu              Ubuntu 22.04 LTS
    debian              Debian 12 Bookworm
    fedora              Fedora 40
    arch                Arch Linux
    alpine              Alpine Linux
    all                 All distributions (default if none specified)

EXAMPLES:
    # Test all distributions sequentially
    $(basename "$0")

    # Test specific distributions
    $(basename "$0") ubuntu debian

    # Build only, don't test
    $(basename "$0") --build-only

    # Test in parallel (faster)
    $(basename "$0") --parallel

    # Clean and rebuild everything
    $(basename "$0") --clean --build-only

EOF
}

# ============================================================================
# Build Functions
# ============================================================================

build_image() {
	local distro=$1
	local dockerfile="$DOTFILES_ROOT/scripts/docker/dockerfiles/${distro}.Dockerfile"
	local image_name="dotfiles-test:${distro}"

	if [ ! -f "$dockerfile" ]; then
		print_error "Dockerfile not found: $dockerfile"
		BUILD_RESULTS[$distro]="FAILED"
		return 1
	fi

	print_step "Building image for $distro..."

	local start_time
	start_time=$(date +%s)

	if [ "$VERBOSE" = true ]; then
		docker build -f "$dockerfile" -t "$image_name" "$DOTFILES_ROOT"
		local build_exit_code=$?
	else
		docker build -f "$dockerfile" -t "$image_name" "$DOTFILES_ROOT" >/dev/null 2>&1
		local build_exit_code=$?
	fi

	local end_time
	end_time=$(date +%s)
	local duration=$((end_time - start_time))

	BUILD_TIMES[$distro]=$duration

	if [ $build_exit_code -eq 0 ]; then
		BUILD_RESULTS[$distro]="SUCCESS"
		print_success "$distro image built successfully (${duration}s)"
		return 0
	else
		BUILD_RESULTS[$distro]="FAILED"
		print_error "$distro image build failed"
		return 1
	fi
}

build_all() {
	print_header "Building Docker Images"

	local failed=0

	for distro in "${SELECTED_DISTROS[@]}"; do
		if ! build_image "$distro"; then
			((failed++)) || true
		fi
	done

	if [ $failed -eq 0 ]; then
		print_success "All images built successfully"
		return 0
	else
		print_error "$failed image(s) failed to build"
		return 1
	fi
}

# ============================================================================
# Test Functions
# ============================================================================

test_image() {
	local distro=$1
	local image_name="dotfiles-test:${distro}"
	local test_script="/home/testuser/dotfiles/scripts/docker/scripts/run-all-tests.sh"

	# Skip if build failed
	if [ "${BUILD_RESULTS[$distro]:-}" = "FAILED" ]; then
		print_warning "Skipping tests for $distro (build failed)"
		TEST_RESULTS[$distro]="SKIPPED"
		return 1
	fi

	# Check if image exists
	if ! docker image inspect "$image_name" >/dev/null 2>&1; then
		print_error "Image not found: $image_name"
		TEST_RESULTS[$distro]="FAILED"
		return 1
	fi

	print_step "Testing $distro distribution..."

	local start_time
	start_time=$(date +%s)

	if [ "$VERBOSE" = true ]; then
		docker run --rm "$image_name" "$test_script"
		local test_exit_code=$?
	else
		docker run --rm "$image_name" "$test_script" >/dev/null 2>&1
		local test_exit_code=$?
	fi

	local end_time
	end_time=$(date +%s)
	local duration=$((end_time - start_time))

	TEST_TIMES[$distro]=$duration

	if [ $test_exit_code -eq 0 ]; then
		TEST_RESULTS[$distro]="SUCCESS"
		print_success "$distro tests passed (${duration}s)"
		return 0
	else
		TEST_RESULTS[$distro]="FAILED"
		print_error "$distro tests failed"
		return 1
	fi
}

test_all() {
	print_header "Running Tests"

	local failed=0

	for distro in "${SELECTED_DISTROS[@]}"; do
		if ! test_image "$distro"; then
			((failed++)) || true
		fi
	done

	if [ $failed -eq 0 ]; then
		print_success "All tests passed"
		return 0
	else
		print_error "$failed test suite(s) failed"
		return 1
	fi
}

# ============================================================================
# Cleanup Functions
# ============================================================================

clean_images() {
	print_header "Cleaning Up Docker Images"

	for distro in "${DISTRIBUTIONS[@]}"; do
		local image_name="dotfiles-test:${distro}"
		if docker image inspect "$image_name" >/dev/null 2>&1; then
			print_step "Removing image: $image_name"
			docker rmi "$image_name" >/dev/null 2>&1 || true
		fi
	done

	print_success "Cleanup complete"
}

# ============================================================================
# Results & Reporting
# ============================================================================

print_summary() {
	print_header "Test Summary"

	echo -e "${BOLD}Build Results:${NC}"
	for distro in "${SELECTED_DISTROS[@]}"; do
		local result="${BUILD_RESULTS[$distro]:-UNKNOWN}"
		local time="${BUILD_TIMES[$distro]:-0}"

		case "$result" in
		SUCCESS)
			echo -e "  ${GREEN}✓${NC} $distro: ${GREEN}SUCCESS${NC} (${time}s)"
			;;
		FAILED)
			echo -e "  ${RED}✗${NC} $distro: ${RED}FAILED${NC}"
			;;
		*)
			echo -e "  ${YELLOW}?${NC} $distro: ${YELLOW}UNKNOWN${NC}"
			;;
		esac
	done

	if [ "$TEST_ONLY" = false ]; then
		echo ""
		echo -e "${BOLD}Test Results:${NC}"
		for distro in "${SELECTED_DISTROS[@]}"; do
			local result="${TEST_RESULTS[$distro]:-UNKNOWN}"
			local time="${TEST_TIMES[$distro]:-0}"

			case "$result" in
			SUCCESS)
				echo -e "  ${GREEN}✓${NC} $distro: ${GREEN}SUCCESS${NC} (${time}s)"
				;;
			FAILED)
				echo -e "  ${RED}✗${NC} $distro: ${RED}FAILED${NC}"
				;;
			SKIPPED)
				echo -e "  ${YELLOW}−${NC} $distro: ${YELLOW}SKIPPED${NC}"
				;;
			*)
				echo -e "  ${YELLOW}?${NC} $distro: ${YELLOW}UNKNOWN${NC}"
				;;
			esac
		done
	fi

	echo ""

	# Calculate totals
	local total=${#SELECTED_DISTROS[@]}
	local build_success=0
	local test_success=0

	for distro in "${SELECTED_DISTROS[@]}"; do
		[ "${BUILD_RESULTS[$distro]:-}" = "SUCCESS" ] && ((build_success++)) || true
		[ "${TEST_RESULTS[$distro]:-}" = "SUCCESS" ] && ((test_success++)) || true
	done

	if [ "$BUILD_ONLY" = false ] && [ "$TEST_ONLY" = false ]; then
		if [ "$build_success" -eq "$total" ] && [ "$test_success" -eq "$total" ]; then
			echo -e "${BOLD}${GREEN}All tests passed! ✓${NC}"
			return 0
		else
			echo -e "${BOLD}${RED}Some tests failed ✗${NC}"
			return 1
		fi
	elif [ "$BUILD_ONLY" = true ]; then
		if [ "$build_success" -eq "$total" ]; then
			echo -e "${BOLD}${GREEN}All builds successful! ✓${NC}"
			return 0
		else
			echo -e "${BOLD}${RED}Some builds failed ✗${NC}"
			return 1
		fi
	fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
	# Parse arguments
	local clean=false

	while [[ $# -gt 0 ]]; do
		case $1 in
		-h | --help)
			show_usage
			exit 0
			;;
		-p | --parallel)
			PARALLEL=true
			shift
			;;
		-b | --build-only)
			BUILD_ONLY=true
			shift
			;;
		-t | --test-only)
			TEST_ONLY=true
			shift
			;;
		-v | --verbose)
			VERBOSE=true
			shift
			;;
		--clean)
			clean=true
			shift
			;;
		all)
			SELECTED_DISTROS=("${DISTRIBUTIONS[@]}")
			shift
			;;
		ubuntu | debian | fedora | arch | alpine)
			SELECTED_DISTROS+=("$1")
			shift
			;;
		*)
			print_error "Unknown option: $1"
			show_usage
			exit 1
			;;
		esac
	done

	# Default to all distributions if none specified
	if [ ${#SELECTED_DISTROS[@]} -eq 0 ]; then
		SELECTED_DISTROS=("${DISTRIBUTIONS[@]}")
	fi

	# Check for Docker
	if ! command -v docker &>/dev/null; then
		print_error "Docker is not installed or not in PATH"
		exit 1
	fi

	# Clean if requested
	if [ "$clean" = true ]; then
		clean_images
	fi

	print_header "Dotfiles Multi-Distribution Testing"
	echo "Distributions: ${SELECTED_DISTROS[*]}"
	echo "Mode: $([ "$BUILD_ONLY" = true ] && echo "Build only" || [ "$TEST_ONLY" = true ] && echo "Test only" || echo "Build and test")"
	echo "Execution: $([ "$PARALLEL" = true ] && echo "Parallel" || echo "Sequential")"

	# Run builds
	if [ "$TEST_ONLY" = false ]; then
		if ! build_all; then
			print_warning "Some builds failed, continuing with tests..."
		fi
	fi

	# Run tests
	if [ "$BUILD_ONLY" = false ]; then
		if ! test_all; then
			print_warning "Some tests failed"
		fi
	fi

	# Print summary
	print_summary
}

# Run main
main "$@"
