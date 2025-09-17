#!/bin/bash

# SSH wrapper with automatic Neovim socket forwarding
# This script automatically forwards the Neovim socket when SSHing to remote hosts

SOCKET_PATH="${NVIM_SOCKET:-/tmp/nvim.socket}"
SCRIPT_NAME=$(basename "$0")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [ssh-options] <host> [command]

This is a wrapper around SSH that automatically forwards the Neovim socket.

Options:
    --no-socket         Don't forward the Neovim socket
    --socket <path>     Use custom socket path (default: $SOCKET_PATH)
    --auto-mount        Automatically mount SSHFS on connection
    --help              Show this help message

All other options are passed directly to SSH.

Examples:
    $SCRIPT_NAME myserver                    # SSH with socket forwarding
    $SCRIPT_NAME --auto-mount myserver       # SSH and auto-mount SSHFS
    $SCRIPT_NAME -p 2222 user@host          # Custom SSH options
    $SCRIPT_NAME --no-socket myserver       # SSH without socket forwarding

After connecting, you can use these commands on the remote:
    remote-nvim connect \$HOST               # Mount local SSHFS
    remote-nvim open path/to/file           # Open file in local Neovim
EOF
}

log() {
    echo -e "${BLUE}[SSH-Nvim]${NC} $1"
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

# Parse our custom options
FORWARD_SOCKET=true
AUTO_MOUNT=false
SSH_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --no-socket)
            FORWARD_SOCKET=false
            shift
            ;;
        --socket)
            SOCKET_PATH="$2"
            shift 2
            ;;
        --auto-mount)
            AUTO_MOUNT=true
            shift
            ;;
        *)
            SSH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Check if we should forward the socket
if [[ "$FORWARD_SOCKET" == true ]]; then
    # Check if socket exists
    if [[ -S "$SOCKET_PATH" ]]; then
        log "Forwarding Neovim socket: $SOCKET_PATH"
        SSH_ARGS=("-R" "$SOCKET_PATH:$SOCKET_PATH" "${SSH_ARGS[@]}")

        # Extract hostname from SSH args for auto-mount
        if [[ "$AUTO_MOUNT" == true ]]; then
            # Try to find the hostname in the args
            HOST=""
            for arg in "${SSH_ARGS[@]}"; do
                if [[ ! "$arg" =~ ^- ]]; then
                    HOST="$arg"
                    break
                fi
            done

            if [[ -n "$HOST" ]]; then
                # Create a temporary script to run after SSH connection
                REMOTE_CMD="echo 'Auto-mounting SSHFS...'; remote-nvim connect \$HOST 2>/dev/null || echo 'Note: remote-nvim not found on remote host'"
                SSH_ARGS+=("-t" "bash -c '$REMOTE_CMD; exec \$SHELL'")
            fi
        fi
    else
        warning "Neovim socket not found at $SOCKET_PATH"
        warning "Start Neovim server with: remote-nvim start"
    fi
fi

# Execute SSH with our modified arguments
exec ssh "${SSH_ARGS[@]}"