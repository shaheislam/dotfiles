#!/bin/bash
# Netman.nvim Port Forwarding Test
# Test netman.nvim by forwarding SSH from containers to localhost

set -e

echo "================================"
echo "Netman.nvim Port Forwarding Test"
echo "================================"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Method 1: Docker Container with SSH Server${NC}"
cat << 'EOF'
# Create a container with SSH server
docker run -d \
  --name netman-ssh-test \
  -p 2222:22 \
  -e SSH_ENABLE_ROOT=true \
  linuxserver/openssh-server:latest

# Wait for container to start
sleep 5

# Set a password for testing (or use SSH keys)
docker exec netman-ssh-test sh -c "echo 'root:testpass' | chpasswd"

# Create test files in container
docker exec netman-ssh-test sh -c "echo 'Hello from container!' > /tmp/test.txt"
docker exec netman-ssh-test sh -c "mkdir -p /data && echo 'Data file' > /data/file.txt"

# In Neovim, access via localhost port forwarding:
:Nmread ssh://root@localhost:2222/tmp/test.txt
:Nmread ssh://root@localhost:2222/data/file.txt
:Nmread ssh://root@localhost:2222/etc/hostname

# Browse directories
:Nmread ssh://root@localhost:2222/

EOF

echo ""
echo -e "${BLUE}Method 2: Kubernetes Pod Port Forwarding${NC}"
cat << 'EOF'
# If you have a Kubernetes cluster with a pod running SSH
kubectl port-forward pod-name 2222:22 &

# Then in Neovim:
:Nmread ssh://user@localhost:2222/path/to/file

# For pods without SSH, use kubectl exec approach (see Method 3)
EOF

echo ""
echo -e "${BLUE}Method 3: Remote Development Container (Podman/Docker)${NC}"
cat << 'EOF'
# Create a development container with SSH
docker run -d \
  --name dev-container \
  -p 2223:22 \
  -v ~/dotfiles:/home/developer/dotfiles \
  ubuntu:latest \
  sh -c "apt-get update && apt-get install -y openssh-server && \
         mkdir /run/sshd && \
         echo 'root:dev' | chpasswd && \
         sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
         /usr/sbin/sshd -D"

# Access in Neovim:
:Nmread ssh://root@localhost:2223/home/developer/dotfiles/
EOF

echo ""
echo -e "${BLUE}Method 4: EC2/Cloud Instance via SSM Port Forwarding${NC}"
cat << 'EOF'
# Use AWS SSM to forward SSH from EC2 instance
aws ssm start-session \
  --target i-instanceid \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["22"],"localPortNumber":["2224"]}'

# Then in Neovim:
:Nmread ssh://ec2-user@localhost:2224/home/ec2-user/
EOF

echo ""
echo -e "${GREEN}Quick Setup Script:${NC}"
echo "Creating a ready-to-use SSH container..."
cat << 'SCRIPT'
#!/bin/bash
# Quick SSH container for testing netman

CONTAINER_NAME="netman-ssh"
LOCAL_PORT="2222"

# Check if container exists
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Removing existing container..."
    docker rm -f $CONTAINER_NAME
fi

echo "Creating SSH-enabled container..."
docker run -d \
    --name $CONTAINER_NAME \
    -p ${LOCAL_PORT}:22 \
    alpine:latest \
    sh -c "apk add --no-cache openssh-server && \
           ssh-keygen -A && \
           echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
           echo 'root:alpine' | chpasswd && \
           mkdir -p /data /workspace && \
           echo 'Test file from container' > /data/test.txt && \
           echo 'Workspace file' > /workspace/work.txt && \
           /usr/sbin/sshd -D"

echo "Waiting for SSH to start..."
sleep 3

echo ""
echo "Container ready! Test with:"
echo "  nvim 'ssh://root@localhost:2222/data/test.txt'"
echo "  Password: alpine"
echo ""
echo "In Neovim:"
echo "  :Nmread ssh://root@localhost:2222/data/"
echo "  :edit ssh://root@localhost:2222/workspace/work.txt"
SCRIPT

echo ""
echo -e "${BLUE}Method 5: Using SSHFS Mount (Alternative)${NC}"
cat << 'EOF'
# Instead of netman, you could mount via SSHFS
mkdir -p ~/mnt/container
sshfs root@localhost:2222:/ ~/mnt/container -p 2222

# Then edit normally in Neovim:
nvim ~/mnt/container/data/test.txt

# Unmount when done:
fusermount -u ~/mnt/container  # Linux
umount ~/mnt/container         # macOS
EOF

echo ""
echo -e "${YELLOW}Port Forwarding Benefits:${NC}"
echo "✓ Access containers without installing SSH inside them"
echo "✓ Use consistent localhost:port pattern"
echo "✓ Works with any containerized environment"
echo "✓ Can chain through bastion hosts"
echo "✓ Integrates with your existing SSH config"
echo ""

echo -e "${YELLOW}SSH Config Tip:${NC}"
echo "Add to ~/.ssh/config for easier access:"
cat << 'EOF'
Host container-dev
    HostName localhost
    Port 2222
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# Then in Neovim:
:Nmread ssh://container-dev/data/test.txt
EOF

echo ""
echo -e "${GREEN}Testing Workflow:${NC}"
echo "1. Start a container with port forwarding (port 2222 -> 22)"
echo "2. Open Neovim"
echo "3. Use: :Nmread ssh://root@localhost:2222/path/to/file"
echo "4. Edit and save with :w"
echo "5. Browse with: :Nmread ssh://root@localhost:2222/"