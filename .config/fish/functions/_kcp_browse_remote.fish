# Helper: Browse remote filesystem with fzf for kcp
function _kcp_browse_remote --argument-names namespace pod container path
    set -l container_flag ""
    if test -n "$container"
        set container_flag "-c $container"
    end

    set -l current_path $path

    while true
        # List directory contents
        set -l listing (eval kubectl exec $pod -n $namespace $container_flag -- ls -la $current_path 2>/dev/null | tail -n +2)

        if test -z "$listing"
            echo "Cannot list directory: $current_path" >&2
            return 1
        end

        # Add parent directory option if not at root
        set -l options
        if test "$current_path" != "/"
            set options ".."
        end
        set options $options $listing

        # Select with fzf
        set -l selection (printf '%s\n' $options | \
            fzf --prompt="Browse $current_path: " \
                --height=70% \
                --reverse \
                --preview="
                    if test '{}' = '..'; then
                        echo 'Parent directory'
                    else
                        set item (echo '{}' | awk '{print \$NF}')
                        set full_path '$current_path/'\$item
                        # Clean up double slashes
                        set full_path (echo \$full_path | sed 's|//|/|g')
                        if echo '{}' | grep -q '^d'; then
                            kubectl exec $pod -n $namespace $container_flag -- ls -la \$full_path 2>/dev/null | head -30
                        else
                            kubectl exec $pod -n $namespace $container_flag -- head -100 \$full_path 2>/dev/null
                        end
                    end
                " \
                --preview-window=right:50%:wrap \
                --bind="ctrl-u:preview-page-up,ctrl-d:preview-page-down")

        if test -z "$selection"
            return 1
        end

        if test "$selection" = ".."
            # Go up one directory
            set current_path (dirname $current_path)
            continue
        end

        # Parse selection
        set -l item_name (echo $selection | awk '{print $NF}')
        set -l is_dir (echo $selection | grep -q '^d' && echo "yes" || echo "no")

        # Build full path
        if test "$current_path" = "/"
            set -l full_path "/$item_name"
        else
            set -l full_path "$current_path/$item_name"
        end

        if test "$is_dir" = "yes"
            # Navigate into directory
            set current_path $full_path
        else
            # File selected, return it
            echo $full_path
            return 0
        end
    end
end
