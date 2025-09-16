#!/usr/bin/env bash

# distant-ssm-tunnel.sh
# Creates SSM tunnel and connects distant.nvim through it
# Usage: ./distant-ssm-tunnel.sh [instance-id] [profile]

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
INSTANCE_ID="${1:-}"
AWS_PROFILE="${2:-labs}"
LOCAL_PORT="${DISTANT_LOCAL_PORT:-2222}"
REGION="${AWS_REGION:-us-east-1}"

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to cleanup on exit
cleanup() {
    if [ -n "${TUNNEL_PID:-}" ]; then
        print_info "Cleaning up SSM tunnel..."
        kill $TUNNEL_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Function to select instance if not provided
select_instance() {
    print_info "Fetching EC2 instances..." >&2

    local instances=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output text \
        --profile "$AWS_PROFILE" \
        --region "$REGION" 2>/dev/null)

    if [ -z "$instances" ]; then
        print_error "No running instances found" >&2
        exit 1
    fi

    # Use fzf to select
    local selected=$(echo "$instances" | awk '{print $1 "\t" ($2 == "None" ? "Unnamed" : $2)}' | \
        fzf --prompt="Select EC2 instance: " --height=40% --border)

    if [ -n "$selected" ]; then
        echo "$selected" | cut -f1
    else
        print_warning "No instance selected" >&2
        exit 1
    fi
}

# Main execution
main() {
    print_info "Distant-SSM Tunnel Setup"
    echo "========================"
    echo

    # Select instance if not provided
    if [ -z "$INSTANCE_ID" ]; then
        INSTANCE_ID=$(select_instance)
    fi

    print_info "Instance: $INSTANCE_ID"
    print_info "Profile: $AWS_PROFILE"
    print_info "Local Port: $LOCAL_PORT"
    echo

    # Check if port is already in use
    if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port $LOCAL_PORT is already in use"
        read -p "Kill existing process and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t | xargs kill -9
            sleep 1
        else
            exit 1
        fi
    fi

    # Start SSM tunnel in background
    print_info "Starting SSM tunnel on port $LOCAL_PORT..."
    aws ssm start-session \
        --target "$INSTANCE_ID" \
        --document-name AWS-StartPortForwardingSession \
        --parameters "{\"portNumber\":[\"22\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
        --profile "$AWS_PROFILE" \
        --region "$REGION" &
    TUNNEL_PID=$!

    # Wait for tunnel to establish
    print_info "Waiting for tunnel to establish..."
    for i in {1..10}; do
        if nc -z localhost $LOCAL_PORT 2>/dev/null; then
            print_success "Tunnel established!"
            break
        fi
        sleep 1
    done

    if ! nc -z localhost $LOCAL_PORT 2>/dev/null; then
        print_error "Failed to establish tunnel"
        exit 1
    fi

    # Update SSH known_hosts to prevent host key mismatch issues
    print_info "Updating SSH known_hosts for localhost:$LOCAL_PORT..."
    ssh-keygen -R "[localhost]:$LOCAL_PORT" 2>/dev/null || true
    ssh-keyscan -p $LOCAL_PORT localhost >> ~/.ssh/known_hosts 2>/dev/null
    print_success "SSH known_hosts updated"

    # Determine the user (try common ones)
    local SSH_USER=""
    for user in ubuntu ec2-user admin centos; do
        if ssh -p $LOCAL_PORT -i ~/.ssh/shahe-distant-nvim \
            -o ConnectTimeout=3 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            $user@localhost "exit" 2>/dev/null; then
            SSH_USER=$user
            print_success "Found working user: $SSH_USER"
            break
        fi
    done

    if [ -z "$SSH_USER" ]; then
        print_warning "Could not determine SSH user automatically"
        echo "Try one of these manually:"
        echo
        SSH_USER="ubuntu"
    fi

    # Display connection instructions
    echo
    print_success "SSM tunnel is ready!"
    echo
    echo "To connect with distant.nvim in Neovim, use:"
    echo
    echo "  :DistantConnect ssh://$SSH_USER@localhost:$LOCAL_PORT"
    echo
    echo "Or from command line:"
    echo
    echo "  echo 'y' | ~/.local/share/nvim/distant/distant.bin connect ssh://$SSH_USER@localhost:$LOCAL_PORT"
    echo
    echo "To SSH directly:"
    echo
    echo "  ssh -p $LOCAL_PORT -i ~/.ssh/shahe-distant-nvim $SSH_USER@localhost"
    echo
    print_info "Press Ctrl+C to close the tunnel when done"
    echo

    # Keep tunnel running
    wait $TUNNEL_PID
}

# Run main function
main "$@"