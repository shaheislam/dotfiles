# kubectl cp with fzf integration
# Interactive file copying between local machine and Kubernetes pods
#
# Usage:
#   kcp from [pod] [remote_path] [local_path]  - Copy from pod to local
#   kcp to [pod] [local_path] [remote_path]    - Copy from local to pod
#   kcp                                         - Interactive mode (prompts for direction)
#
# Examples:
#   kcp from                                    # Interactive: select pod, browse remote fs
#   kcp from my-pod /etc/config.yaml ./         # Direct copy from pod
#   kcp to my-pod ./config.yaml /tmp/           # Direct copy to pod
#
# Shortcuts:
#   kcpf - kubectl cp from pod
#   kcpt - kubectl cp to pod

function kcp --description "kubectl cp with fzf"
    set -l direction $argv[1]
    set -l pod $argv[2]
    set -l path1 $argv[3]
    set -l path2 $argv[4]

    # Get current namespace
    set -l namespace (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
    if test -z "$namespace"
        set namespace "default"
    end

    # If no direction specified, prompt
    if test -z "$direction"
        set direction (printf "from\nto" | fzf --prompt="Copy direction: " --height=10 --reverse)
        if test -z "$direction"
            echo "Cancelled"
            return 1
        end
    end

    # Validate direction
    if not contains -- $direction from to
        echo "Usage: kcp [from|to] [pod] [remote_path] [local_path]"
        echo "  from - Copy from pod to local"
        echo "  to   - Copy from local to pod"
        return 1
    end

    # Select pod if not provided
    if test -z "$pod"
        set pod (_kcp_select_pod $namespace)
        if test -z "$pod"
            echo "No pod selected"
            return 1
        end
    end

    # Get container if multi-container pod
    set -l container (_kcp_select_container $namespace $pod)
    set -l container_flag ""
    if test -n "$container"
        set container_flag "-c $container"
    end

    if test "$direction" = "from"
        # Copy FROM pod
        set -l remote_path $path1
        set -l local_path $path2

        # Browse remote filesystem if path not provided
        if test -z "$remote_path"
            set remote_path (_kcp_browse_remote $namespace $pod $container "/")
            if test -z "$remote_path"
                echo "No file selected"
                return 1
            end
        end

        # Default local path to current directory with same filename
        if test -z "$local_path"
            set local_path "./"(basename $remote_path)
        end

        echo "Copying $namespace/$pod:$remote_path → $local_path"
        eval kubectl cp $namespace/$pod:$remote_path $local_path $container_flag
        and echo "Done: $local_path"

    else if test "$direction" = "to"
        # Copy TO pod
        set -l local_path $path1
        set -l remote_path $path2

        # Select local file if not provided
        if test -z "$local_path"
            set local_path (fd --type f | fzf --prompt="Select local file: " --preview="bat --color=always --style=numbers {}" --height=80%)
            if test -z "$local_path"
                echo "No file selected"
                return 1
            end
        end

        # Default remote path
        if test -z "$remote_path"
            set remote_path "/tmp/"(basename $local_path)
            echo "Remote path not specified, using: $remote_path"
        end

        echo "Copying $local_path → $namespace/$pod:$remote_path"
        eval kubectl cp $local_path $namespace/$pod:$remote_path $container_flag
        and echo "Done: $namespace/$pod:$remote_path"
    end
end
