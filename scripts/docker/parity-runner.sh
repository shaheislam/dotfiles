#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE_PREFIX="${IMAGE_PREFIX:-dotfiles-parity}"
DISTROS=(ubuntu debian fedora arch)
BUILD_ONLY=false
TEST_ONLY=false
VERBOSE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [DISTROS...]

Build and run the Linux/WSL parity validation slice in containers.

OPTIONS:
  --build-only   Build images without running tests
  --test-only    Run tests against existing images
  --verbose      Show Docker output
  -h, --help     Show this help

DISTROS:
  ubuntu debian fedora arch all
EOF
}

selected=()
while [[ $# -gt 0 ]]; do
    case "$1" in
    --build-only) BUILD_ONLY=true ;;
    --test-only) TEST_ONLY=true ;;
    --verbose) VERBOSE=true ;;
    -h | --help)
        usage
        exit 0
        ;;
    all) selected=("${DISTROS[@]}") ;;
    ubuntu | debian | fedora | arch) selected+=("$1") ;;
    *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
done

if [[ ${#selected[@]} -eq 0 ]]; then
    selected=(ubuntu)
fi

run_docker() {
    if [[ "$VERBOSE" == "true" ]]; then
        docker "$@"
    else
        docker "$@" >/dev/null
    fi
}

build_image() {
    local distro="$1"
    local dockerfile="$DOTFILES_ROOT/scripts/docker/parity/${distro}.Dockerfile"
    local image="$IMAGE_PREFIX:$distro"

    echo "Building $image"
    run_docker build -f "$dockerfile" -t "$image" "$DOTFILES_ROOT"
}

test_image() {
    local distro="$1"
    local image="$IMAGE_PREFIX:$distro"

    echo "Testing $image"
    if [[ "$VERBOSE" == "true" ]]; then
        docker run --rm "$image"
    else
        docker run --rm "$image"
    fi
}

for distro in "${selected[@]}"; do
    if [[ "$TEST_ONLY" != "true" ]]; then
        build_image "$distro"
    fi
    if [[ "$BUILD_ONLY" != "true" ]]; then
        test_image "$distro"
    fi
done

echo "Parity validation completed for: ${selected[*]}"
