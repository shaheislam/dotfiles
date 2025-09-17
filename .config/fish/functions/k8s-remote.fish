function k8s-remote --description "Remote editing workflow for Kubernetes pods"
    set -l action $argv[1]
    set -l namespace $argv[2]
    set -l pod $argv[3]

    switch $action
        case "list"
            # List all pods across namespaces
            echo "📋 Listing all running pods..."
            kubectl get pods --all-namespaces --no-headers | grep Running | \
                awk '{printf "%-20s %-40s %s\n", $1, $2, $4}'

        case "ssh-setup"
            # Install SSH server in pod (for development pods only!)
            if test -z "$namespace" -o -z "$pod"
                echo "Usage: k8s-remote ssh-setup <namespace> <pod>"
                return 1
            end

            echo "🔧 Setting up SSH in pod $pod..."

            # Commands to install SSH server
            set -l setup_cmds \
                "apt-get update 2>/dev/null || yum check-update 2>/dev/null || apk update 2>/dev/null || true" \
                "apt-get install -y openssh-server 2>/dev/null || yum install -y openssh-server 2>/dev/null || apk add --no-cache openssh 2>/dev/null" \
                "mkdir -p /var/run/sshd" \
                "echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config" \
                "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config" \
                "echo 'root:root' | chpasswd" \
                "ssh-keygen -A 2>/dev/null || true" \
                "/usr/sbin/sshd -D &"

            for cmd in $setup_cmds
                echo "Running: $cmd"
                kubectl exec -n $namespace $pod -- sh -c "$cmd"
            end

            echo "✅ SSH server started in pod"
            echo "Default credentials: root/root (change immediately!)"

        case "connect"
            # Connect with SSHFS using port forwarding
            if test -z "$namespace"
                set namespace "default"
            end

            if test -z "$pod"
                # Select pod interactively
                echo "Fetching pods in namespace: $namespace"
                set -l pods (kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name,:status.phase" | grep Running)

                if test -z "$pods"
                    echo "❌ No running pods found"
                    return 1
                end

                set pod (printf "%s\n" $pods | fzf \
                    --prompt="Select pod > " \
                    --height=40% \
                    --layout=reverse \
                    --border | awk '{print $1}')

                if test -z "$pod"
                    return 1
                end
            end

            # Ensure Neovim server is running
            if not pgrep -f "nvim.*--listen.*/tmp/nvim.socket" > /dev/null 2>&1
                echo "📝 Starting Neovim server..."
                rnvim start
                sleep 2
            end

            # Find available port
            set -l port 2230
            while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1
                set port (math $port + 1)
            end

            echo "🔌 Port forwarding to $pod on port $port..."
            kubectl port-forward -n $namespace $pod $port:22 &
            set -l pf_pid $last_pid

            sleep 2

            # Try to mount with SSHFS
            set -l mount_dir "$HOME/.sshfs/k8s-$namespace-$pod"
            mkdir -p "$mount_dir"

            echo "📂 Mounting pod filesystem..."
            sshfs -p $port \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o password_stdin \
                root@localhost:/ "$mount_dir" <<< "root"

            if test $status -eq 0
                echo "✅ Mounted at: $mount_dir"

                # Open in Neovim
                nvim --server /tmp/nvim.socket --remote-send ":cd $mount_dir<CR>" 2>/dev/null

                echo ""
                echo "Ready to edit! Press Ctrl+C to disconnect..."
                wait $pf_pid
            else
                echo "❌ Mount failed. Ensure SSH is running in the pod."
                echo "Run: k8s-remote ssh-setup $namespace $pod"
                kill $pf_pid 2>/dev/null
            end

            # Cleanup
            umount "$mount_dir" 2>/dev/null
            rmdir "$mount_dir" 2>/dev/null

        case "exec"
            # Direct kubectl exec fallback
            if test -z "$namespace"
                set namespace "default"
            end

            if test -z "$pod"
                echo "Usage: k8s-remote exec <namespace> <pod>"
                return 1
            end

            kubectl exec -it -n $namespace $pod -- bash || \
            kubectl exec -it -n $namespace $pod -- sh

        case "*"
            echo "Kubernetes Remote Editing Helper"
            echo ""
            echo "Usage: k8s-remote <action> [namespace] [pod]"
            echo ""
            echo "Actions:"
            echo "  list                List all running pods"
            echo "  ssh-setup           Install SSH server in pod (dev only!)"
            echo "  connect             Connect with SSHFS mount"
            echo "  exec                Direct shell access"
            echo ""
            echo "Examples:"
            echo "  k8s-remote list"
            echo "  k8s-remote ssh-setup default my-pod"
            echo "  k8s-remote connect default my-pod"
            echo "  k8s-remote exec default my-pod"
            echo ""
            echo "For production pods, use:"
            echo "  k8s-edit - Edit files with kubectl cp"
            echo "  kubectl exec - Direct shell access"
    end
end