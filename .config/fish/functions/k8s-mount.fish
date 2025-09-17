function k8s-mount --description "Mount Kubernetes pod filesystem using kubectl cp"
    set -l namespace $argv[1]
    set -l pod $argv[2]
    set -l remote_path $argv[3]
    set -l local_path $argv[4]

    # Default values
    if test -z "$namespace"
        set namespace "default"
    end

    if test -z "$remote_path"
        set remote_path "/"
    end

    if test -z "$local_path"
        set local_path "$HOME/.k8s-mounts"
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
            --prompt="Select pod to access > " \
            --height=40% \
            --layout=reverse \
            --border \
            --header="Select a running pod" | awk '{print $1}')

        if test -z "$pod"
            echo "Cancelled"
            return 1
        end
    end

    set -l mount_dir "$local_path/$namespace-$pod"
    mkdir -p "$mount_dir"

    echo "📂 Pod: $pod (namespace: $namespace)"
    echo "📍 Mount point: $mount_dir"
    echo ""
    echo "Options:"
    echo "  1. kubectl exec -it -n $namespace $pod -- bash"
    echo "  2. kubectl cp for file transfer"
    echo "  3. Use kubectl-fuse if installed"
    echo ""

    # Check if kubectl-fuse is available (3rd party tool)
    if command -v kubectl-fuse > /dev/null 2>&1
        echo "✅ kubectl-fuse detected! Mounting..."
        kubectl-fuse mount -n $namespace $pod:$remote_path $mount_dir
    else
        echo "💡 Tip: Install kubectl-fuse for FUSE mounting:"
        echo "  go install github.com/jarodlam/kubectl-fuse@latest"
        echo ""
        echo "For now, using kubectl exec:"
        kubectl exec -it -n $namespace $pod -- bash
    end
end

function k8s-edit --description "Edit files in Kubernetes pod using Neovim"
    set -l namespace $argv[1]
    set -l pod $argv[2]
    set -l file $argv[3]

    # Default namespace
    if test -z "$namespace"
        set namespace "default"
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
            --prompt="Select pod to edit files in > " \
            --height=40% \
            --layout=reverse \
            --border \
            --header="Select a running pod" | awk '{print $1}')

        if test -z "$pod"
            echo "Cancelled"
            return 1
        end
    end

    if test -z "$file"
        echo "Usage: k8s-edit [namespace] [pod] <file>"
        echo ""
        echo "Opening shell in pod instead..."
        kubectl exec -it -n $namespace $pod -- bash
        return
    end

    # Create temp file
    set -l tmpfile (mktemp)

    echo "📥 Downloading $file from $pod..."
    kubectl cp -n $namespace $pod:$file $tmpfile 2>/dev/null

    if test $status -ne 0
        echo "❌ Failed to download file. File might not exist."
        rm -f $tmpfile
        return 1
    end

    # Get original file hash
    set -l original_hash (sha256sum $tmpfile | awk '{print $1}')

    # Edit file
    nvim $tmpfile

    # Check if file was modified
    set -l new_hash (sha256sum $tmpfile | awk '{print $1}')

    if test "$original_hash" != "$new_hash"
        echo "📤 Uploading changes back to pod..."
        kubectl cp -n $namespace $tmpfile $pod:$file

        if test $status -eq 0
            echo "✅ File updated successfully!"
        else
            echo "❌ Failed to upload file"
        end
    else
        echo "ℹ️  No changes made"
    end

    # Cleanup
    rm -f $tmpfile
end