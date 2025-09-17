#!/bin/bash
# Quick setup script for testing netman with port forwarding

CONTAINER_NAME="netman-ssh"
LOCAL_PORT="${1:-2222}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Setting up SSH container for netman.nvim testing..."
echo "Local port: $LOCAL_PORT -> Container port: 22"
echo ""

# Check if container exists
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Removing existing container..."
    docker rm -f $CONTAINER_NAME > /dev/null 2>&1
fi

echo "Creating SSH-enabled Alpine container..."
docker run -d \
    --name $CONTAINER_NAME \
    -p ${LOCAL_PORT}:22 \
    alpine:latest \
    sh -c "apk add --no-cache openssh-server && \
           ssh-keygen -A && \
           echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
           echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
           echo 'root:alpine' | chpasswd && \
           mkdir -p /data /workspace /config && \
           echo 'Welcome to netman test container!' > /data/README.txt && \
           echo 'Edit this file via netman.nvim' > /workspace/test.txt && \
           echo '# Config file' > /config/app.conf && \
           /usr/sbin/sshd -D" > /dev/null 2>&1

echo "Waiting for SSH service to start..."
sleep 3

# Test SSH connection
if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
   root@localhost -p $LOCAL_PORT "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✓ Container is ready!${NC}"
else
    echo -e "${YELLOW}Note: SSH is starting up, give it a moment...${NC}"
fi

echo ""
echo "================================"
echo "Test Commands for Neovim:"
echo "================================"
echo ""
echo "# Browse container filesystem:"
echo -e "${GREEN}:Nmread ssh://root@localhost:${LOCAL_PORT}/${NC}"
echo ""
echo "# Read specific files:"
echo -e "${GREEN}:Nmread ssh://root@localhost:${LOCAL_PORT}/data/README.txt${NC}"
echo -e "${GREEN}:Nmread ssh://root@localhost:${LOCAL_PORT}/workspace/test.txt${NC}"
echo ""
echo "# Edit a file directly:"
echo -e "${GREEN}:edit ssh://root@localhost:${LOCAL_PORT}/config/app.conf${NC}"
echo ""
echo "# Password: alpine"
echo ""
echo "================================"
echo "Container Management:"
echo "================================"
echo "Stop:    docker stop $CONTAINER_NAME"
echo "Remove:  docker rm $CONTAINER_NAME"
echo "Logs:    docker logs $CONTAINER_NAME"
echo "Shell:   docker exec -it $CONTAINER_NAME sh"