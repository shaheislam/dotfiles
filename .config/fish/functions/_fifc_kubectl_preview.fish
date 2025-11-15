function _fifc_kubectl_preview
    # Comprehensive debug logging
    set -l debug_file /tmp/kubectl-preview-debug.log
    echo "=== _fifc_kubectl_preview CALLED at $(date) ===" >> $debug_file
    echo "fifc_commandline: $fifc_commandline" >> $debug_file
    echo "fifc_candidate: $fifc_candidate" >> $debug_file
    echo "fifc_group: $fifc_group" >> $debug_file
    echo "fifc_desc: $fifc_desc" >> $debug_file
    echo "PWD: $PWD" >> $debug_file
    echo "KUBECONFIG: $KUBECONFIG" >> $debug_file

    # Also output to stderr for immediate feedback
    echo "=== KUBECTL PREVIEW CALLED ===" >&2
    echo "Candidate: $fifc_candidate" >&2

    # Extract the resource type from the command line
    # e.g., "kubectl get deployment" -> "deployment"
    set -l cmd_parts (string split " " "$fifc_commandline")
    set -l resource_type ""

    # Find the resource type (comes after "get")
    set -l found_get false
    for part in $cmd_parts
        if test "$found_get" = "true"
            set resource_type $part
            break
        end
        if test "$part" = "get"
            set found_get true
        end
    end

    echo "Extracted resource_type: $resource_type" >> $debug_file

    # If we found the resource type, construct the full path and get YAML
    if test -n "$resource_type"
        echo "Attempting: kubectl get $resource_type/$fifc_candidate -o yaml" >> $debug_file
        # Try with just resource/name first
        kubectl get "$resource_type/$fifc_candidate" -o yaml 2>>$debug_file | bat --paging=never --style=numbers --color=always --language=yaml
        or begin
            echo "First attempt failed, trying without resource prefix" >> $debug_file
            # If that fails, try just the candidate (might already be in format resource.group/name)
            kubectl get "$fifc_candidate" -o yaml 2>>$debug_file | bat --paging=never --style=numbers --color=always --language=yaml
            or echo "Failed to get YAML for $fifc_candidate"
        end
    else
        # Fallback: just show the candidate name
        echo "No resource type found in commandline" >> $debug_file
        echo "No resource type found"
        echo "Candidate: $fifc_candidate"
    end
end
