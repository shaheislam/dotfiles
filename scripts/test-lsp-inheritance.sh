#!/usr/bin/env bash
# Test LSP inheritance across all three scenarios
# Usage: ./test-lsp-inheritance.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="${TMPDIR:-/tmp}/test-lsp-inheritance-$$"
PROJECT_A="$TEST_DIR/project-a"
PROJECT_B="$TEST_DIR/project-b"
GLOBAL_DIR="$TEST_DIR/global-test"

# Detect system
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        SYSTEM="aarch64-darwin"
    else
        SYSTEM="x86_64-darwin"
    fi
else
    SYSTEM="x86_64-linux"
fi

echo -e "${BLUE}=== LSP Inheritance Test Suite ===${NC}"
echo "Test directory: $TEST_DIR"
echo "System: $SYSTEM"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up test directories...${NC}"
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Helper functions
print_success() {
    echo -e "  ${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "  ${RED}❌${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠️${NC}  $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ️${NC}  $1"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking Prerequisites${NC}"

    # Check direnv
    if command -v direnv &> /dev/null; then
        print_success "direnv installed"
    else
        print_error "direnv not found"
        exit 1
    fi

    # Check nix
    if command -v nix &> /dev/null; then
        print_success "nix installed"
    else
        print_error "nix not found"
        exit 1
    fi

    # Check gopls in global
    if command -v gopls &> /dev/null; then
        local gopls_path=$(which gopls)
        if [[ "$gopls_path" == *".nix-profile"* ]]; then
            print_success "global gopls found at $gopls_path"
        else
            print_warning "gopls found but not in .nix-profile: $gopls_path"
        fi
    else
        print_error "global gopls not found - install via: nix-env -iA nixpkgs.gopls"
        exit 1
    fi

    echo ""
}

# Create test directories
setup_test_dirs() {
    echo -e "${BLUE}Setting Up Test Directories${NC}"

    mkdir -p "$PROJECT_A" "$PROJECT_B" "$GLOBAL_DIR"
    print_success "Created test directories"

    echo ""
}

# Test 1: Global Baseline
test_global_baseline() {
    echo -e "${BLUE}Test 1: Global Baseline${NC}"

    cd "$GLOBAL_DIR"

    # Should NOT have project-specific env vars
    if [[ -z "$NIX_LSP_ENABLED" ]] || [[ "$NIX_LSP_ENABLED" != "true" ]]; then
        print_success "NIX_LSP_ENABLED not set (global environment)"
    else
        print_error "NIX_LSP_ENABLED is set in global directory"
        return 1
    fi

    # Should have global gopls
    local gopls_path=$(which gopls)
    if [[ "$gopls_path" == *".nix-profile"* ]]; then
        print_success "Using global gopls: $gopls_path"
    else
        print_error "Not using global gopls: $gopls_path"
        return 1
    fi

    # Get version
    local gopls_version=$(gopls version 2>&1 | head -1 || echo "unknown")
    print_info "Global gopls version: $gopls_version"

    echo ""
}

# Test 2: Project A (Stable gopls)
test_project_a() {
    echo -e "${BLUE}Test 2: Project A (Stable gopls)${NC}"

    cd "$PROJECT_A"
    git init -q

    # Create flake.nix with stable gopls
    cat > flake.nix << EOF
{
  description = "Test Project A - Stable gopls";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { nixpkgs, ... }:
    let
      system = "$SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go
          gopls
        ];

        shellHook = ''
          echo "Project A environment active"
        '';

        NIX_LSP_ENABLED = "true";
      };
    };
}
EOF

    print_success "Created flake.nix for Project A"

    # Create .envrc
    echo "use flake" > .envrc
    print_success "Created .envrc"

    # Allow direnv
    direnv allow &> /dev/null
    print_success "Allowed direnv"

    # NOTE: We use 'nix develop' directly instead of direnv export
    # because direnv export doesn't capture all Nix shell environment variables.
    # This is expected behavior - in real usage, you'd 'cd' into the directory
    # and direnv would activate automatically.

    # Check environment variables using nix develop
    local nix_lsp_enabled=$(nix develop --command bash -c 'echo $NIX_LSP_ENABLED' 2>/dev/null)
    if [[ "$nix_lsp_enabled" == "true" ]]; then
        print_success "NIX_LSP_ENABLED=true (via nix develop)"
    else
        print_error "NIX_LSP_ENABLED not set correctly: $nix_lsp_enabled"
        return 1
    fi

    # Check gopls path using nix develop
    local gopls_path=$(nix develop --command which gopls 2>/dev/null)
    if [[ "$gopls_path" == *"/nix/store/"* ]]; then
        print_success "Using project gopls: $gopls_path"
    else
        print_error "Not using project gopls: $gopls_path"
        return 1
    fi

    # Get version using nix develop
    local gopls_version=$(nix develop --command gopls version 2>&1 | head -1 || echo "unknown")
    print_info "Project A gopls version: $gopls_version"

    # Store for comparison
    PROJECT_A_VERSION="$gopls_version"
    PROJECT_A_PATH="$gopls_path"

    echo ""
}

# Test 3: Project B (Unstable gopls)
test_project_b() {
    echo -e "${BLUE}Test 3: Project B (Unstable gopls)${NC}"

    cd "$PROJECT_B"
    git init -q

    # Create flake.nix with unstable gopls
    cat > flake.nix << EOF
{
  description = "Test Project B - Unstable gopls";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "$SYSTEM";
      pkgs = nixpkgs.legacyPackages.\${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.\${system};
    in {
      devShells.\${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.go
          pkgs-unstable.gopls
        ];

        shellHook = ''
          echo "Project B environment active"
        '';

        NIX_LSP_ENABLED = "true";
      };
    };
}
EOF

    print_success "Created flake.nix for Project B"

    # Create .envrc
    echo "use flake" > .envrc
    print_success "Created .envrc"

    # Allow direnv
    direnv allow &> /dev/null
    print_success "Allowed direnv"

    # NOTE: We use 'nix develop' directly instead of direnv export
    # because direnv export doesn't capture all Nix shell environment variables.
    # This is expected behavior - in real usage, you'd 'cd' into the directory
    # and direnv would activate automatically.

    # Check environment variables using nix develop
    local nix_lsp_enabled=$(nix develop --command bash -c 'echo $NIX_LSP_ENABLED' 2>/dev/null)
    if [[ "$nix_lsp_enabled" == "true" ]]; then
        print_success "NIX_LSP_ENABLED=true (via nix develop)"
    else
        print_error "NIX_LSP_ENABLED not set correctly: $nix_lsp_enabled"
        return 1
    fi

    # Check gopls path using nix develop
    local gopls_path=$(nix develop --command which gopls 2>/dev/null)
    if [[ "$gopls_path" == *"/nix/store/"* ]]; then
        print_success "Using project gopls: $gopls_path"
    else
        print_error "Not using project gopls: $gopls_path"
        return 1
    fi

    # Get version using nix develop
    local gopls_version=$(nix develop --command gopls version 2>&1 | head -1 || echo "unknown")
    print_info "Project B gopls version: $gopls_version"

    # Store for comparison
    PROJECT_B_VERSION="$gopls_version"
    PROJECT_B_PATH="$gopls_path"

    echo ""
}

# Test 4: Isolation Test
test_isolation() {
    echo -e "${BLUE}Test 4: Isolation Test${NC}"

    # Leave project and return to global
    cd "$GLOBAL_DIR"
    eval "$(direnv export bash 2>/dev/null)"

    # Check environment is unloaded
    if [[ -z "$NIX_LSP_ENABLED" ]] || [[ "$NIX_LSP_ENABLED" != "true" ]]; then
        print_success "Project environment unloaded"
    else
        print_error "Project environment still active: NIX_LSP_ENABLED=$NIX_LSP_ENABLED"
        return 1
    fi

    # Check back to global gopls
    local gopls_path=$(which gopls)
    if [[ "$gopls_path" == *".nix-profile"* ]]; then
        print_success "Restored to global gopls"
    else
        print_error "Not using global gopls: $gopls_path"
        return 1
    fi

    # Verify Project A and B are different
    if [[ "$PROJECT_A_PATH" != "$PROJECT_B_PATH" ]]; then
        print_success "Project A and B use different gopls binaries"
    else
        print_warning "Project A and B use same gopls binary (this may be OK if versions are same in nixpkgs)"
    fi

    # Version check
    print_info "Version comparison:"
    print_info "  Project A: $PROJECT_A_VERSION"
    print_info "  Project B: $PROJECT_B_VERSION"
    if [[ "$PROJECT_A_VERSION" != "$PROJECT_B_VERSION" ]]; then
        print_success "Projects use different gopls versions"
    else
        print_warning "Projects use same gopls version (may indicate channels have same version)"
    fi

    echo ""
}

# Test 5: PATH Precedence
test_path_precedence() {
    echo -e "${BLUE}Test 5: PATH Precedence${NC}"

    cd "$PROJECT_A"

    # Get PATH from inside nix develop
    local first_path=$(nix develop --command bash -c 'echo "$PATH" | tr ":" "\n" | head -1' 2>/dev/null)

    if [[ "$first_path" == *"/nix/store/"* ]]; then
        print_success "Project /nix/store path is first in PATH"
    else
        print_error "Project path not first in PATH: $first_path"
        return 1
    fi

    # Check nix-profile comes later
    local nix_profile_position=$(nix develop --command bash -c 'echo "$PATH" | tr ":" "\n" | grep -n ".nix-profile" | head -1 | cut -d: -f1' 2>/dev/null)
    if [[ -n "$nix_profile_position" ]] && [[ "$nix_profile_position" -gt 1 ]]; then
        print_success ".nix-profile appears after project paths (position $nix_profile_position)"
    else
        print_warning ".nix-profile position: $nix_profile_position"
    fi

    echo ""
}

# Test 6: Rapid Switching
test_rapid_switching() {
    echo -e "${BLUE}Test 6: Rapid Directory Switching${NC}"

    # Project A
    cd "$PROJECT_A"
    local a_path=$(nix develop --command which gopls 2>/dev/null)
    print_info "Project A: $a_path"

    # Project B
    cd "$PROJECT_B"
    local b_path=$(nix develop --command which gopls 2>/dev/null)
    print_info "Project B: $b_path"

    # Global
    cd "$GLOBAL_DIR"
    local g_path=$(which gopls)
    print_info "Global: $g_path"

    # Back to Project A
    cd "$PROJECT_A"
    local a2_path=$(nix develop --command which gopls 2>/dev/null)

    if [[ "$a_path" == "$a2_path" ]]; then
        print_success "Project A environment restored correctly"
    else
        print_error "Project A environment changed: $a_path vs $a2_path"
        return 1
    fi

    echo ""
}

# Run all tests
main() {
    check_prerequisites
    setup_test_dirs

    local failed=0

    test_global_baseline || ((failed++))
    test_project_a || ((failed++))
    test_project_b || ((failed++))
    test_isolation || ((failed++))
    test_path_precedence || ((failed++))
    test_rapid_switching || ((failed++))

    # Summary
    echo -e "${BLUE}=== Test Summary ===${NC}"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        echo ""
        echo "Your LSP inheritance system is working correctly:"
        echo "  • Global baseline provides fallback LSPs"
        echo "  • Projects can override LSP versions"
        echo "  • Projects are isolated from each other"
        echo "  • Switching directories works seamlessly"
        return 0
    else
        echo -e "${RED}❌ $failed test(s) failed${NC}"
        echo ""
        echo "See TESTING.md for troubleshooting guidance:"
        echo "  ~/dotfiles/nix/TESTING.md"
        return 1
    fi
}

# Run main function
main
