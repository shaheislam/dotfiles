#!/bin/bash
# Netman.nvim Testing Script
# This script provides various test scenarios for netman.nvim

set -e

echo "================================"
echo "Netman.nvim Test Scenarios"
echo "================================"
echo ""

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. Installation${NC}"
echo "   The plugin has been configured in: ~/.config/nvim/lua/plugins/netman-test.lua"
echo "   Run :Lazy sync in Neovim to install"
echo ""

echo -e "${BLUE}2. Basic Commands to Test${NC}"
echo ""

echo -e "${GREEN}SSH Tests:${NC}"
echo "   # Read a remote file via SSH"
echo "   :Nmread ssh://user@hostname/path/to/file.txt"
echo ""
echo "   # Edit and save a remote file"
echo "   :edit ssh://user@hostname/path/to/file.txt"
echo "   :w"
echo ""
echo "   # Browse remote directory (if Neo-tree is installed)"
echo "   :Nmread ssh://user@hostname/path/to/directory/"
echo ""

echo -e "${GREEN}Docker Tests:${NC}"
echo "   # Read a file from a Docker container"
echo "   :Nmread docker://container_name/path/to/file"
echo ""
echo "   # Edit a file in a running container"
echo "   :edit docker://container_id/etc/hosts"
echo ""

echo -e "${GREEN}Local SSH Test (using localhost):${NC}"
echo "   # Test with your local machine"
echo "   :Nmread ssh://localhost/tmp/test.txt"
echo "   :Nmread ssh://$(whoami)@localhost/home/$(whoami)/.bashrc"
echo ""

echo -e "${BLUE}3. Test File Creation${NC}"
echo "Creating a test file for local SSH testing..."
echo "Hello from Netman.nvim test!" > /tmp/netman-test.txt
echo -e "${GREEN}✓${NC} Created /tmp/netman-test.txt"
echo ""

echo -e "${BLUE}4. Quick Test Commands${NC}"
cat << 'EOF'
# In Neovim, try these commands:

" Test reading the local test file via SSH
:Nmread ssh://localhost/tmp/netman-test.txt

" List your home directory via SSH
:Nmread ssh://localhost/home/$USER/

" Test with your AWS EC2 instances (if configured)
:Nmread ssh://ec2-instance/home/ubuntu/

" With custom port
:Nmread ssh://user@host:2222/path/to/file

EOF

echo -e "${BLUE}5. Keymaps Available${NC}"
echo "   <leader>nm - Start Nmread command"
echo "   <leader>nw - Start Nmwrite command"
echo "   <leader>nd - Start Nmdelete command"
echo "   <leader>nl - Show Netman status"
echo ""

echo -e "${BLUE}6. Docker Container Test Setup${NC}"
cat << 'EOF'
# If you have Docker, create a test container:
docker run -d --name netman-test alpine:latest tail -f /dev/null
docker exec netman-test sh -c "echo 'Test content' > /tmp/test.txt"

# Then in Neovim:
:Nmread docker://netman-test/tmp/test.txt

# Clean up:
docker stop netman-test && docker rm netman-test
EOF

echo ""
echo -e "${YELLOW}Note:${NC} Make sure you have SSH access configured for remote hosts"
echo "      For Docker, ensure containers are running before testing"
echo ""
echo "Ready to test! Open Neovim and run :Lazy sync to install netman.nvim"