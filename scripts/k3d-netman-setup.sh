#!/bin/bash
# K3d Pods Port Forwarding for Netman.nvim
# Access your k3d cluster pods via netman.nvim in Neovim

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================"
echo "K3d Pods Netman.nvim Setup"
echo "================================"
echo ""

# Function to start port forwarding
start_port_forward() {
    local pod=$1
    local port=$2
    local container_port=${3:-22}

    echo -e "${BLUE}Starting port forward for ${pod} on localhost:${port}...${NC}"
    kubectl port-forward pod/${pod} ${port}:${container_port} > /dev/null 2>&1 &
    echo $! > /tmp/netman-pf-${pod}.pid
    echo -e "${GREEN}✓${NC} Port forward started (PID: $(cat /tmp/netman-pf-${pod}.pid))"
}

# Function to stop port forwarding
stop_port_forwards() {
    echo -e "${YELLOW}Stopping all port forwards...${NC}"
    for pidfile in /tmp/netman-pf-*.pid; do
        if [ -f "$pidfile" ]; then
            kill $(cat $pidfile) 2>/dev/null || true
            rm -f $pidfile
        fi
    done
    echo -e "${GREEN}✓${NC} All port forwards stopped"
}

# Function to setup SSH in pod if needed
setup_pod_ssh() {
    local pod=$1
    echo -e "${BLUE}Setting up SSH in ${pod}...${NC}"

    # Check if SSH is already running
    if kubectl exec ${pod} -- pgrep sshd > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} SSH already running in ${pod}"
        return 0
    fi

    # Start SSH service
    kubectl exec ${pod} -- sh -c "
        if [ -f /usr/sbin/sshd ]; then
            # Generate host keys if missing
            [ ! -f /etc/ssh/ssh_host_rsa_key ] && ssh-keygen -A 2>/dev/null

            # Set root password
            echo 'root:k3d' | chpasswd 2>/dev/null || true

            # Configure SSH
            mkdir -p /run/sshd
            echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
            echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

            # Start SSH daemon
            /usr/sbin/sshd
            echo 'SSH started successfully'
        else
            echo 'SSH not available in this pod'
        fi
    " || echo -e "${YELLOW}⚠${NC} Could not start SSH in ${pod}"
}

# Main menu
case "${1:-menu}" in
    start)
        echo -e "${GREEN}Starting port forwards for k3d pods...${NC}"
        echo ""

        # Setup SSH pod (has SSH server)
        if kubectl get pod dev-pod-ssh > /dev/null 2>&1; then
            setup_pod_ssh dev-pod-ssh
            start_port_forward dev-pod-ssh 2222 22
            echo "  SSH Pod: ssh://root@localhost:2222/ (password: k3d)"
        fi

        # For other pods, we'll use kubectl exec approach
        echo ""
        echo -e "${BLUE}For pods without SSH, use kubectl exec:${NC}"
        echo "  kubectl exec -it dev-pod-alpine -- sh"
        echo "  kubectl exec -it dev-pod-python -- bash"
        echo ""

        echo -e "${GREEN}Netman.nvim commands:${NC}"
        echo "  :Nmread ssh://root@localhost:2222/etc/hostname"
        echo "  :edit ssh://root@localhost:2222/tmp/"
        echo ""
        ;;

    stop)
        stop_port_forwards
        ;;

    direct)
        # Alternative: Direct file access without SSH
        echo -e "${BLUE}Direct File Access (without SSH):${NC}"
        echo ""

        # Create helper script for direct access
        cat > /tmp/k3d-file-access.sh << 'SCRIPT'
#!/bin/bash
# Direct file access from k3d pods
POD=$1
FILE=$2
ACTION=${3:-read}

case $ACTION in
    read)
        kubectl exec $POD -- cat $FILE
        ;;
    write)
        kubectl exec -i $POD -- sh -c "cat > $FILE"
        ;;
    list)
        kubectl exec $POD -- ls -la $FILE
        ;;
esac
SCRIPT
        chmod +x /tmp/k3d-file-access.sh

        echo "Helper script created: /tmp/k3d-file-access.sh"
        echo ""
        echo "Usage:"
        echo "  /tmp/k3d-file-access.sh dev-pod-alpine /etc/hostname read"
        echo "  echo 'content' | /tmp/k3d-file-access.sh dev-pod-alpine /tmp/test.txt write"
        echo "  /tmp/k3d-file-access.sh dev-pod-python /tmp list"
        ;;

    test)
        echo -e "${BLUE}Testing file access in pods...${NC}"
        echo ""

        for pod in dev-pod-alpine dev-pod-python dev-pod-ssh dev-pod-secure; do
            echo -e "${GREEN}Pod: ${pod}${NC}"
            kubectl exec ${pod} -- sh -c "
                echo 'Test file from ${pod}' > /tmp/netman-test.txt
                echo 'Created /tmp/netman-test.txt'
                ls -la /tmp/netman-test.txt
            " 2>/dev/null || echo "  Failed to create test file"
            echo ""
        done
        ;;

    menu|*)
        echo "Usage: $0 {start|stop|direct|test}"
        echo ""
        echo "Options:"
        echo "  start  - Start SSH and port forwarding"
        echo "  stop   - Stop all port forwards"
        echo "  direct - Setup direct file access (no SSH)"
        echo "  test   - Create test files in all pods"
        echo ""
        echo -e "${BLUE}Current pods in cluster:${NC}"
        kubectl get pods
        echo ""
        echo -e "${BLUE}Quick Start:${NC}"
        echo "  1. Run: $0 start"
        echo "  2. In Neovim: :Nmread ssh://root@localhost:2222/"
        echo "  3. Password: k3d"
        ;;
esac

# Show active port forwards
if ls /tmp/netman-pf-*.pid 2>/dev/null | grep -q pid; then
    echo ""
    echo -e "${GREEN}Active port forwards:${NC}"
    for pidfile in /tmp/netman-pf-*.pid; do
        if [ -f "$pidfile" ]; then
            pod=$(basename $pidfile .pid | sed 's/netman-pf-//')
            pid=$(cat $pidfile)
            if ps -p $pid > /dev/null 2>&1; then
                port=$(lsof -p $pid 2>/dev/null | grep LISTEN | awk '{print $9}' | cut -d: -f2 | head -1)
                echo "  ${pod}: localhost:${port:-?} (PID: $pid)"
            fi
        fi
    done
fi