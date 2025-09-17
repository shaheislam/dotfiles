function k8s-ssh --description "SSH to Kubernetes pod with port forwarding"
    set -l namespace $argv[1]
    set -l pod $argv[2]
    set -l local_port $argv[3]

    # Default values
    if test -z "$namespace"
        set namespace "default"
    end

    if test -z "$local_port"
        set local_port 2222
    end

    # If no pod specified, list pods and let user select
    if test -z "$pod"
        echo "Fetching pods in namespace: $namespace"
        set -l pods (kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name,:status.phase" | grep Running)

        if test -z "$pods"
            echo "❌ No running pods found in namespace: $namespace"
            return 1
        end

        set pod (printf "%s\n" $pods | fzf \
            --prompt="Select pod to SSH into > " \
            --height=40% \
            --layout=reverse \
            --border \
            --header="Select a running pod" | awk '{print $1}')

        if test -z "$pod"
            echo "Cancelled"
            return 1
        end
    end

    echo "🔌 Setting up SSH port forward to $pod in namespace $namespace..."
    echo "Local port: $local_port → Pod port: 22"

    # Start port forward in background
    kubectl port-forward -n $namespace $pod $local_port:22 &
    set -l pf_pid $last_pid

    # Wait for port forward to be ready
    sleep 2

    echo ""
    echo "✅ Port forward established!"
    echo ""
    echo "You can now SSH to the pod:"
    echo "  ssh -p $local_port root@localhost"
    echo ""
    echo "Or with remote-sshfs workflow:"
    echo "  1. Add to ~/.ssh/config:"
    echo "     Host $pod"
    echo "         HostName localhost"
    echo "         Port $local_port"
    echo "         User root"
    echo "         StrictHostKeyChecking no"
    echo "         UserKnownHostsFile /dev/null"
    echo ""
    echo "  2. Use remote-nvim:"
    echo "     rnvim connect $pod"
    echo ""
    echo "Press Ctrl+C to stop port forwarding..."

    # Keep port forward running
    wait $pf_pid
end

function k8s-sshfs --description "Mount Kubernetes pod filesystem via SSHFS"
    set -l namespace $argv[1]
    set -l pod $argv[2]
    set -l mount_path $argv[3]

    # Default values
    if test -z "$namespace"
        set namespace "default"
    end

    if test -z "$mount_path"
        set mount_path "$HOME/.sshfs/k8s-$pod"
    end

    # If no pod specified, list pods
    if test -z "$pod"
        echo "Fetching pods in namespace: $namespace"
        set -l pods (kubectl get pods -n $namespace --no-headers -o custom-columns=":metadata.name,:status.phase" | grep Running)

        if test -z "$pods"
            echo "❌ No running pods found in namespace: $namespace"
            return 1
        end

        set pod (printf "%s\n" $pods | fzf \
            --prompt="Select pod to mount > " \
            --height=40% \
            --layout=reverse \
            --border \
            --header="Select a running pod" | awk '{print $1}')

        if test -z "$pod"
            echo "Cancelled"
            return 1
        end
    end

    # Find an available port
    set -l port 2224
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1
        set port (math $port + 1)
    end

    echo "🔌 Setting up port forward to $pod..."
    kubectl port-forward -n $namespace $pod $port:22 &
    set -l pf_pid $last_pid

    sleep 2

    # Create mount directory
    mkdir -p "$mount_path"

    echo "📂 Mounting pod filesystem..."
    sshfs -p $port \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o reconnect \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        root@localhost:/ "$mount_path"

    if test $status -eq 0
        echo "✅ Pod filesystem mounted at: $mount_path"
        echo ""
        echo "You can now:"
        echo "  cd $mount_path      # Browse pod files"
        echo "  nvim $mount_path    # Edit with Neovim"
        echo ""
        echo "To unmount:"
        echo "  umount $mount_path"
        echo ""
        echo "Press Ctrl+C to stop..."
        wait $pf_pid
    else
        echo "❌ Failed to mount filesystem"
        kill $pf_pid 2>/dev/null
        return 1
    end

    # Cleanup on exit
    echo "🧹 Cleaning up..."
    umount "$mount_path" 2>/dev/null || fusermount -u "$mount_path" 2>/dev/null
    rmdir "$mount_path" 2>/dev/null
end