#!/bin/bash

# Remote Neovim SSHFS Helper Script
# This script manages the Neovim server/client socket workflow for remote editing

SOCKET_PATH="${NVIM_SOCKET:-/tmp/nvim.socket}"
SSHFS_BASE="$HOME/.sshfs"
SCRIPT_NAME=$(basename "$0")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
    start               Start Neovim server with socket listener
    connect <host>      Connect to remote host and mount via SSHFS
    open <path>         Open file/directory in remote-mounted Neovim
    disconnect [host]   Disconnect from remote host(s)
    status              Show current connections and socket status
    cleanup             Clean up stale sockets and mounts

Options:
    --socket <path>     Custom socket path (default: $SOCKET_PATH)
    --help              Show this help message

Examples:
    $SCRIPT_NAME start                        # Start Neovim server
    $SCRIPT_NAME connect myserver             # Connect to myserver
    $SCRIPT_NAME open projects/myproject      # Open remote directory
    $SCRIPT_NAME disconnect                   # Disconnect all
    $SCRIPT_NAME status                       # Check connection status

Workflow:
    1. $SCRIPT_NAME start                     # On local machine
    2. ssh -R /tmp/nvim.socket:/tmp/nvim.socket remote-host
    3. $SCRIPT_NAME connect \$HOST             # From remote shell
    4. $SCRIPT_NAME open path/to/project      # Open remote files
EOF
}

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if socket exists and is valid
check_socket() {
    if [[ -S "$SOCKET_PATH" ]]; then
        # Try to send a simple command to test the socket
        if nvim --server "$SOCKET_PATH" --remote-send ":echo 'test'<CR>" 2>/dev/null; then
            return 0
        else
            warning "Socket exists but appears stale: $SOCKET_PATH"
            return 1
        fi
    else
        return 1
    fi
}

# Start Neovim server with socket
start_server() {
    if check_socket; then
        warning "Neovim server already running on $SOCKET_PATH"
        return 0
    fi

    # Clean up stale socket if it exists
    if [[ -e "$SOCKET_PATH" ]]; then
        log "Removing stale socket..."
        rm -f "$SOCKET_PATH"
    fi

    log "Starting Neovim server on $SOCKET_PATH..."
    nvim --listen "$SOCKET_PATH" &

    # Wait for socket to be ready
    for i in {1..10}; do
        if check_socket; then
            success "Neovim server started successfully!"
            return 0
        fi
        sleep 0.5
    done

    error "Failed to start Neovim server"
    return 1
}

# Connect to remote host via SSHFS
connect_remote() {
    local host="$1"

    if [[ -z "$host" ]]; then
        error "Host required. Usage: $SCRIPT_NAME connect <host>"
        return 1
    fi

    if ! check_socket; then
        error "Neovim server not running. Start with: $SCRIPT_NAME start"
        return 1
    fi

    log "Connecting to $host via SSHFS..."

    # Create mount directory if it doesn't exist
    mkdir -p "$SSHFS_BASE"

    # Send RemoteSSHFSConnect command to Neovim
    if nvim --server "$SOCKET_PATH" --remote-send ":RemoteSSHFSConnect $host<CR>" 2>/dev/null; then
        success "Connected to $host"

        # Wait a moment for the mount to establish
        sleep 1

        # Check if mount was successful
        if mount | grep -q "$SSHFS_BASE/$host"; then
            success "SSHFS mount established at $SSHFS_BASE/$host"
        else
            warning "Connection command sent but mount not verified"
        fi
    else
        error "Failed to send connect command to Neovim"
        return 1
    fi
}

# Open file/directory in Neovim
open_in_nvim() {
    local path="$1"

    if [[ -z "$path" ]]; then
        error "Path required. Usage: $SCRIPT_NAME open <path>"
        return 1
    fi

    if ! check_socket; then
        error "Neovim server not running. Start with: $SCRIPT_NAME start"
        return 1
    fi

    log "Opening $path in Neovim..."

    # Open in new tab
    if nvim --server "$SOCKET_PATH" --remote-tab "$path" 2>/dev/null; then
        success "Opened $path in new tab"
    else
        error "Failed to open $path"
        return 1
    fi
}

# Disconnect from remote host(s)
disconnect_remote() {
    local host="$1"

    if ! check_socket; then
        warning "Neovim server not running"
    else
        if [[ -n "$host" ]]; then
            log "Disconnecting from $host..."
            nvim --server "$SOCKET_PATH" --remote-send ":RemoteSSHFSDisconnect $host<CR>" 2>/dev/null
        else
            log "Disconnecting all remote connections..."
            nvim --server "$SOCKET_PATH" --remote-send ":RemoteSSHFSDisconnect<CR>" 2>/dev/null
        fi
    fi

    # Check and unmount any remaining SSHFS mounts
    for mount_point in "$SSHFS_BASE"/*; do
        if [[ -d "$mount_point" ]] && mount | grep -q "$mount_point"; then
            log "Unmounting $mount_point..."
            umount "$mount_point" 2>/dev/null || fusermount -u "$mount_point" 2>/dev/null
        fi
    done

    success "Disconnection complete"
}

# Show status
show_status() {
    echo -e "${BLUE}=== Remote Neovim Status ===${NC}"

    echo -e "\n${YELLOW}Socket Status:${NC}"
    if check_socket; then
        success "Neovim server running on $SOCKET_PATH"
    else
        warning "Neovim server not running"
    fi

    echo -e "\n${YELLOW}SSHFS Mounts:${NC}"
    local mount_count=0
    while IFS= read -r line; do
        if [[ "$line" == *"$SSHFS_BASE"* ]]; then
            echo "  • $line"
            ((mount_count++))
        fi
    done < <(mount)

    if [[ $mount_count -eq 0 ]]; then
        echo "  No active SSHFS mounts"
    fi

    echo -e "\n${YELLOW}Mount Directories:${NC}"
    if [[ -d "$SSHFS_BASE" ]]; then
        for dir in "$SSHFS_BASE"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if mount | grep -q "$dir"; then
                    echo -e "  • ${GREEN}$dirname${NC} (mounted)"
                else
                    echo -e "  • ${RED}$dirname${NC} (not mounted)"
                fi
            fi
        done
    else
        echo "  Mount directory does not exist: $SSHFS_BASE"
    fi
}

# Cleanup stale sockets and mounts
cleanup() {
    log "Cleaning up stale resources..."

    # Clean up socket
    if [[ -e "$SOCKET_PATH" ]] && ! check_socket; then
        log "Removing stale socket: $SOCKET_PATH"
        rm -f "$SOCKET_PATH"
    fi

    # Clean up unmounted directories
    if [[ -d "$SSHFS_BASE" ]]; then
        for dir in "$SSHFS_BASE"/*; do
            if [[ -d "$dir" ]] && ! mount | grep -q "$dir"; then
                log "Removing unmounted directory: $dir"
                rmdir "$dir" 2>/dev/null
            fi
        done
    fi

    success "Cleanup complete"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --socket)
            SOCKET_PATH="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        start)
            start_server
            exit $?
            ;;
        connect)
            connect_remote "$2"
            exit $?
            ;;
        open)
            open_in_nvim "$2"
            exit $?
            ;;
        disconnect)
            disconnect_remote "$2"
            exit $?
            ;;
        status)
            show_status
            exit 0
            ;;
        cleanup)
            cleanup
            exit 0
            ;;
        *)
            error "Unknown command: $1"
            echo "Run '$SCRIPT_NAME --help' for usage information"
            exit 1
            ;;
    esac
done

# If no command provided, show help
show_help
exit 0