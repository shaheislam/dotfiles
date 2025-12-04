function _kubectl_fzf_tab_complete -d "FZF tab completion for kubectl"
    set -l cmd (commandline -opc) 2>/dev/null

    # Need at least "kubectl" to proceed
    if test (count $cmd) -lt 1
        _fifc 2>/dev/null
        return
    end

    # Get previous token and current token
    set -l prev_token ""
    if test (count $cmd) -ge 2
        set prev_token $cmd[-1]
    end
    set -l current_token (commandline -t)

    # For label completion, use bash helper (like fzf-git.sh pattern)
    # This provides proper TTY access for fzf during tab completion
    if string match -qr -- '^-(l|-selector)$' "$prev_token"; or \
       string match -qr -- '^[a-zA-Z0-9_./-]+=' "$current_token"
        set -l script_path (realpath (status dirname))/kubectl-fzf.sh

        # Determine resource type from command
        set -l resource_type "pods"
        for arg in $cmd
            if contains -- $arg pods pod deployments deployment deploy services service svc nodes node configmaps configmap cm secrets secret
                set resource_type $arg
                break
            end
        end

        set -l selected (SHELL=bash bash "$script_path" labels "$resource_type" "$current_token" 2>/dev/null)

        if test -n "$selected"
            commandline -t -- "$selected"
        end
        commandline -f repaint
        return
    end

    # For other completions (resources, etc.), use existing logic
    set -l result (kubectl_fzf_native)

    if test -n "$result"
        # Replace current token with selection(s)
        commandline -t -- "$result "
    end

    commandline -f repaint
end
