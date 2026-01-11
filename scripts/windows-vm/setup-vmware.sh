#!/usr/bin/env bash
# setup-vmware.sh - Installs VMware Fusion and prepares VM infrastructure
#
# Usage: ./setup-vmware.sh
#
# This script:
# 1. Installs VMware Fusion via Homebrew (if not installed)
# 2. Creates the VM directory structure
# 3. Checks for Windows ARM ISO
# 4. Provides next steps

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VM_BASE_DIR="${VM_BASE_DIR:-$HOME/VMs}"
ISO_DIR="$VM_BASE_DIR/ISOs"
WINDOWS_VM_DIR="$VM_BASE_DIR/Windows11-Poker"

print_header() {
    echo -e "\n${BLUE}==>${NC} ${1}"
}

print_success() {
    echo -e "${GREEN}✓${NC} ${1}"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} ${1}"
}

print_error() {
    echo -e "${RED}✗${NC} ${1}"
}

# Check if running on macOS
check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_error "This script is only for macOS"
        exit 1
    fi
}

# Check if running on Apple Silicon
check_apple_silicon() {
    if [[ "$(uname -m)" != "arm64" ]]; then
        print_warning "This setup is optimized for Apple Silicon (ARM64)"
        print_warning "Intel Macs can use Boot Camp for native Windows installation"
    fi
}

# Install VMware Fusion
install_vmware_fusion() {
    print_header "Checking VMware Fusion installation"

    if command -v vmrun &>/dev/null; then
        print_success "VMware Fusion is already installed"
        vmrun --version 2>/dev/null || true
    else
        print_header "Installing VMware Fusion via Homebrew"
        brew install --cask vmware-fusion

        if command -v vmrun &>/dev/null; then
            print_success "VMware Fusion installed successfully"
        else
            print_error "VMware Fusion installation failed"
            exit 1
        fi
    fi
}

# Create directory structure
create_directories() {
    print_header "Creating VM directory structure"

    mkdir -p "$VM_BASE_DIR"
    mkdir -p "$ISO_DIR"
    mkdir -p "$WINDOWS_VM_DIR"

    print_success "Created: $VM_BASE_DIR"
    print_success "Created: $ISO_DIR"
    print_success "Created: $WINDOWS_VM_DIR"
}

# Check for Windows ARM ISO
check_windows_iso() {
    print_header "Checking for Windows 11 ARM ISO"

    local iso_found=false
    for iso in "$ISO_DIR"/*.iso; do
        if [[ -f "$iso" ]]; then
            print_success "Found ISO: $(basename "$iso")"
            iso_found=true
        fi
    done

    if [[ "$iso_found" == "false" ]]; then
        print_warning "No Windows ARM ISO found in $ISO_DIR"
        echo ""
        echo "To get Windows 11 ARM ISO, you have two options:"
        echo ""
        echo "  Option 1: Run the download script (recommended)"
        echo "    ./download-windows-iso.sh"
        echo ""
        echo "  Option 2: Download manually from Windows Insider"
        echo "    1. Join Windows Insider at https://insider.windows.com"
        echo "    2. Download Windows 11 ARM64 ISO"
        echo "    3. Save to: $ISO_DIR/"
        echo ""
    fi
}

# Check available disk space
check_disk_space() {
    print_header "Checking disk space"

    local available_gb
    available_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')

    if [[ "$available_gb" -lt 100 ]]; then
        print_warning "Only ${available_gb}GB available. Recommended: 100GB+"
    else
        print_success "${available_gb}GB available"
    fi
}

# Print next steps
print_next_steps() {
    print_header "Next Steps"
    echo ""
    echo "1. Ensure you have a Windows 11 ARM ISO in $ISO_DIR/"
    echo "   Run: ./download-windows-iso.sh"
    echo ""
    echo "2. Create the VM:"
    echo "   ./create-vm.sh"
    echo ""
    echo "3. Install Windows manually in VMware Fusion"
    echo "   - Start the VM"
    echo "   - Follow Windows OOBE setup"
    echo ""
    echo "4. After Windows installation, run in Windows PowerShell:"
    echo "   powershell -ExecutionPolicy Bypass -File dotfiles\\scripts\\windows\\setup.ps1"
    echo ""
}

# Main
main() {
    echo "=================================="
    echo "  VMware Fusion Setup for Windows"
    echo "=================================="

    check_macos
    check_apple_silicon
    install_vmware_fusion
    create_directories
    check_disk_space
    check_windows_iso
    print_next_steps

    print_success "VMware Fusion setup complete!"
}

main "$@"
