#!/usr/bin/env bash
# create-vm.sh - Creates Windows 11 ARM VM using VMware Fusion
#
# Usage: ./create-vm.sh [--iso PATH] [--name NAME] [--cpus N] [--memory MB]
#
# Options:
#   --iso PATH     Path to Windows ARM ISO (default: ~/VMs/ISOs/*.iso)
#   --name NAME    VM name (default: Windows11-Poker)
#   --cpus N       Number of CPU cores (default: 6)
#   --memory MB    Memory in MB (default: 8192)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
VM_BASE_DIR="${VM_BASE_DIR:-$HOME/VMs}"
ISO_DIR="$VM_BASE_DIR/ISOs"
VM_NAME="Windows11-Poker"
VM_CPUS=6
VM_MEMORY=8192  # 8GB
VM_DISK_SIZE=81920  # 80GB

# Script directory for template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --iso)
                ISO_PATH="$2"
                shift 2
                ;;
            --name)
                VM_NAME="$2"
                shift 2
                ;;
            --cpus)
                VM_CPUS="$2"
                shift 2
                ;;
            --memory)
                VM_MEMORY="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [--iso PATH] [--name NAME] [--cpus N] [--memory MB]"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Find Windows ISO
find_iso() {
    print_header "Looking for Windows ARM ISO"

    if [[ -n "${ISO_PATH:-}" ]] && [[ -f "$ISO_PATH" ]]; then
        print_success "Using specified ISO: $ISO_PATH"
        return
    fi

    # Find latest ISO in ISO directory
    ISO_PATH=$(ls -t "$ISO_DIR"/*.iso 2>/dev/null | head -1 || true)

    if [[ -z "$ISO_PATH" ]] || [[ ! -f "$ISO_PATH" ]]; then
        print_error "No Windows ISO found in $ISO_DIR/"
        echo "Run ./download-windows-iso.sh first"
        exit 1
    fi

    print_success "Found ISO: $ISO_PATH"
}

# Check if VM already exists
check_existing_vm() {
    local vm_dir="$VM_BASE_DIR/$VM_NAME.vmwarevm"

    if [[ -d "$vm_dir" ]]; then
        print_warning "VM already exists: $vm_dir"
        read -rp "Delete and recreate? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            # Stop VM if running
            vmrun stop "$vm_dir/$VM_NAME.vmx" soft 2>/dev/null || true
            rm -rf "$vm_dir"
            print_success "Deleted existing VM"
        else
            print_error "VM exists. Use --name to specify a different name"
            exit 1
        fi
    fi
}

# Create VM directory and disk
create_vm_structure() {
    print_header "Creating VM structure"

    local vm_dir="$VM_BASE_DIR/$VM_NAME.vmwarevm"
    mkdir -p "$vm_dir"

    print_success "Created VM directory: $vm_dir"
}

# Create virtual disk
create_virtual_disk() {
    print_header "Creating virtual disk (${VM_DISK_SIZE}MB)"

    local vm_dir="$VM_BASE_DIR/$VM_NAME.vmwarevm"
    local disk_path="$vm_dir/$VM_NAME.vmdk"

    # Use vmware-vdiskmanager to create disk
    if command -v vmware-vdiskmanager &>/dev/null; then
        vmware-vdiskmanager -c -s "${VM_DISK_SIZE}MB" -a lsilogic -t 0 "$disk_path"
        print_success "Created disk: $disk_path"
    else
        # Fallback: Create disk on first boot
        print_warning "vmware-vdiskmanager not found, disk will be created on first boot"
    fi
}

# Generate VMX configuration
generate_vmx() {
    print_header "Generating VM configuration"

    local vm_dir="$VM_BASE_DIR/$VM_NAME.vmwarevm"
    local vmx_path="$vm_dir/$VM_NAME.vmx"
    local disk_name="$VM_NAME.vmdk"

    cat > "$vmx_path" << EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "20"

# VM Identity
displayName = "$VM_NAME"
guestOS = "arm-windows11-64"
uuid.bios = "$(uuidgen)"

# CPU Configuration
numvcpus = "$VM_CPUS"
cpuid.coresPerSocket = "$VM_CPUS"

# Memory Configuration
memsize = "$VM_MEMORY"
mem.hotadd = "FALSE"

# Firmware
firmware = "efi"
uefi.secureBoot.enabled = "TRUE"

# Hardware Compatibility
virtualHW.productCompatibility = "hosted"
tools.upgrade.policy = "upgradeAtPowerCycle"

# Display
mks.enable3d = "TRUE"
svga.graphicsMemoryKB = "2097152"

# Sound
sound.present = "TRUE"
sound.virtualDev = "hdaudio"
sound.autodetect = "TRUE"

# Networking
ethernet0.present = "TRUE"
ethernet0.virtualDev = "e1000e"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.wakeOnPcktRcv = "FALSE"

# USB
usb.present = "TRUE"
usb_xhci.present = "TRUE"

# CD/DVD Drive (for Windows ISO)
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.deviceType = "cdrom-image"
sata0:0.fileName = "$ISO_PATH"
sata0:0.startConnected = "TRUE"
sata0:0.autodetect = "TRUE"

# Virtual Disk
nvme0.present = "TRUE"
nvme0:0.present = "TRUE"
nvme0:0.fileName = "$disk_name"
nvme0:0.deviceType = "disk"

# Shared Folders
sharedFolder0.present = "TRUE"
sharedFolder0.enabled = "TRUE"
sharedFolder0.readAccess = "TRUE"
sharedFolder0.writeAccess = "TRUE"
sharedFolder0.hostPath = "$HOME/Documents/PokerData"
sharedFolder0.guestName = "PokerData"
sharedFolder0.expiration = "never"

sharedFolder1.present = "TRUE"
sharedFolder1.enabled = "TRUE"
sharedFolder1.readAccess = "TRUE"
sharedFolder1.writeAccess = "TRUE"
sharedFolder1.hostPath = "$HOME/Documents/Obsidian"
sharedFolder1.guestName = "Obsidian"
sharedFolder1.expiration = "never"

sharedFolder.maxNum = "2"
isolation.tools.hgfs.disable = "FALSE"

# TPM (required for Windows 11)
vtpm.present = "TRUE"

# Power Management
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"

# Misc
cleanShutdown = "TRUE"
softPowerOff = "TRUE"
extendedConfigFile = "$VM_NAME.vmxf"
floppy0.present = "FALSE"
tools.syncTime = "TRUE"
EOF

    print_success "Created VMX: $vmx_path"
}

# Create shared folder directories
create_shared_folders() {
    print_header "Creating shared folder directories"

    mkdir -p "$HOME/Documents/PokerData"
    mkdir -p "$HOME/Documents/Obsidian"

    print_success "Created: ~/Documents/PokerData"
    print_success "Created: ~/Documents/Obsidian"
}

# Register VM with VMware
register_vm() {
    print_header "Registering VM with VMware Fusion"

    local vm_dir="$VM_BASE_DIR/$VM_NAME.vmwarevm"
    local vmx_path="$vm_dir/$VM_NAME.vmx"

    # VMware Fusion will auto-register when opened
    print_success "VM ready at: $vmx_path"
}

# Print next steps
print_next_steps() {
    local vm_dir="$VM_BASE_DIR/$VM_NAME.vmwarevm"
    local vmx_path="$vm_dir/$VM_NAME.vmx"

    print_header "Next Steps"
    echo ""
    echo "1. Start the VM:"
    echo "   open '$vmx_path'"
    echo "   # Or: vmrun start '$vmx_path'"
    echo ""
    echo "2. Install Windows 11:"
    echo "   - Select language and keyboard"
    echo "   - Click 'Install now'"
    echo "   - Select 'I don't have a product key' (or enter key)"
    echo "   - Choose 'Windows 11 Pro' edition"
    echo "   - Accept license terms"
    echo "   - Select 'Custom: Install Windows only'"
    echo "   - Select the virtual disk and click 'Next'"
    echo ""
    echo "3. Complete Windows OOBE:"
    echo "   - Skip internet connection (Shift+F10, type: OOBE\BYPASSNRO)"
    echo "   - Create local account"
    echo "   - Disable telemetry options"
    echo ""
    echo "4. After Windows is ready, run setup script:"
    echo "   # In Windows PowerShell (Admin):"
    echo "   git clone <your-dotfiles-repo> C:\\Users\\<user>\\dotfiles"
    echo "   cd dotfiles\\scripts\\windows"
    echo "   powershell -ExecutionPolicy Bypass -File setup.ps1 -InstallWSL"
    echo ""
}

# Main
main() {
    echo "=================================="
    echo "  Create Windows 11 ARM VM"
    echo "=================================="

    parse_args "$@"
    find_iso
    check_existing_vm
    create_vm_structure
    create_shared_folders
    generate_vmx
    register_vm
    print_next_steps

    print_success "VM creation complete!"
}

main "$@"
