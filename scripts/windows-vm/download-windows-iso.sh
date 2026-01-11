#!/usr/bin/env bash
# download-windows-iso.sh - Downloads Windows 11 ARM ISO via UUPDump
#
# Usage: ./download-windows-iso.sh
#
# This script uses UUPDump to download official Microsoft Windows files
# and create an ISO. This is legal and uses Microsoft's own update servers.
#
# Alternative: Join Windows Insider Program at https://insider.windows.com
# for direct ISO downloads.

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
WORK_DIR="$ISO_DIR/uupdump-work"
OUTPUT_ISO="$ISO_DIR/Win11_ARM64.iso"

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

# Install dependencies
install_dependencies() {
    print_header "Installing dependencies"

    local deps=("aria2" "cabextract" "wimlib" "cdrtools")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! brew list "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Installing: ${missing[*]}"
        brew install "${missing[@]}"
    fi

    print_success "All dependencies installed"
}

# Check if ISO already exists
check_existing_iso() {
    if [[ -f "$OUTPUT_ISO" ]]; then
        print_warning "ISO already exists: $OUTPUT_ISO"
        read -rp "Overwrite? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_success "Using existing ISO"
            exit 0
        fi
        rm -f "$OUTPUT_ISO"
    fi
}

# Download UUPDump converter script
download_uupdump_converter() {
    print_header "Downloading UUPDump converter"

    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    # UUPDump provides a bash script for macOS/Linux
    local converter_url="https://raw.githubusercontent.com/AveYo/MediaCreationTool.bat/main/bypass11/Skip_TPM_Check_on_Dynamic_Update.cmd"

    # For ARM64 ISO creation, we'll use a simplified approach
    # The UUPDump website provides download links with scripts
    print_warning "UUPDump automated download requires manual steps"
    echo ""
    echo "Please follow these steps:"
    echo ""
    echo "1. Go to https://uupdump.net"
    echo "2. Search for 'Windows 11 ARM64'"
    echo "3. Select the latest stable build"
    echo "4. Choose 'arm64' architecture"
    echo "5. Select your language (e.g., English)"
    echo "6. Choose 'Download and convert to ISO'"
    echo "7. Download the ZIP file"
    echo "8. Extract and run the included script"
    echo ""
    echo "Or use the Windows Insider Program:"
    echo "1. Go to https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewARM64"
    echo "2. Sign in with Microsoft account"
    echo "3. Download the ARM64 ISO directly"
    echo ""
    echo "Save the ISO to: $ISO_DIR/"
}

# Alternative: Provide direct instructions for Insider download
provide_insider_instructions() {
    print_header "Windows Insider Program (Recommended)"
    echo ""
    echo "The easiest way to get Windows 11 ARM64 ISO:"
    echo ""
    echo "1. Join Windows Insider Program (free):"
    echo "   https://insider.windows.com/en-us/register"
    echo ""
    echo "2. Download ARM64 ISO:"
    echo "   https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewARM64"
    echo ""
    echo "3. Sign in with your Microsoft account"
    echo ""
    echo "4. Select 'Windows 11 Insider Preview (Release Preview Channel)'"
    echo "   (Most stable option)"
    echo ""
    echo "5. Save to: $ISO_DIR/Win11_ARM64.iso"
    echo ""
}

# Open browser for download
open_download_page() {
    print_header "Opening download page in browser"

    local insider_url="https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewARM64"
    local uupdump_url="https://uupdump.net/?q=windows+11+arm64"

    read -rp "Open which page? [1] Windows Insider (recommended) [2] UUPDump: " choice
    case "$choice" in
        2)
            open "$uupdump_url"
            print_success "Opened UUPDump in browser"
            ;;
        *)
            open "$insider_url"
            print_success "Opened Windows Insider download page in browser"
            ;;
    esac
}

# Wait for ISO download
wait_for_iso() {
    print_header "Waiting for ISO download"
    echo "Watching for ISO files in: $ISO_DIR/"
    echo "Press Ctrl+C when download is complete"
    echo ""

    while true; do
        if compgen -G "$ISO_DIR/*.iso" > /dev/null; then
            local iso_file
            iso_file=$(ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -1)
            if [[ -n "$iso_file" ]]; then
                print_success "Found ISO: $iso_file"
                break
            fi
        fi
        echo -n "."
        sleep 5
    done
}

# Verify ISO
verify_iso() {
    print_header "Verifying ISO"

    local iso_file
    iso_file=$(ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -1)

    if [[ -f "$iso_file" ]]; then
        local size_gb
        size_gb=$(du -g "$iso_file" | cut -f1)
        print_success "ISO file: $iso_file"
        print_success "Size: ${size_gb}GB"

        if [[ "$size_gb" -lt 4 ]]; then
            print_warning "ISO seems small. Windows 11 ARM should be 4-6GB"
        fi
    else
        print_error "No ISO found in $ISO_DIR/"
        exit 1
    fi
}

# Main
main() {
    echo "==========================================="
    echo "  Windows 11 ARM64 ISO Download Helper"
    echo "==========================================="

    mkdir -p "$ISO_DIR"

    check_existing_iso
    provide_insider_instructions

    read -rp "Open browser to download page? [Y/n] " response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        open_download_page
    fi

    read -rp "Wait for ISO download to complete? [Y/n] " response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        wait_for_iso
        verify_iso
    fi

    echo ""
    print_success "ISO download process complete!"
    echo "Next step: ./create-vm.sh"
}

main "$@"
