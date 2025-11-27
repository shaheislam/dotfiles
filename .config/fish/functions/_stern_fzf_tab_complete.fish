function _stern_fzf_tab_complete -d "FZF tab completion for stern with no trailing space"
    set -l cmd (commandline -opc) 2>/dev/null
    set -l current_token (commandline -ct)

    # Check if we're completing the first argument (workload name)
    if test (count $cmd) -eq 1; or begin
            test (count $cmd) -eq 2; and not string match -q -- '-*' "$current_token"
        end

        # Get all workloads that stern supports (deployment, statefulset, daemonset, replicaset, job, service, replicationcontroller)
        set -l result (begin
            kubectl get deployments -o name 2>/dev/null | string replace "deployment.apps/" ""
            kubectl get statefulsets -o name 2>/dev/null | string replace "statefulset.apps/" ""
            kubectl get daemonsets -o name 2>/dev/null | string replace "daemonset.apps/" ""
            kubectl get replicasets -o name 2>/dev/null | string replace "replicaset.apps/" ""
            kubectl get jobs -o name 2>/dev/null | string replace "job.batch/" ""
            kubectl get services -o name 2>/dev/null | string replace "service/" ""
            kubectl get replicationcontrollers -o name 2>/dev/null | string replace "replicationcontroller/" ""
        end | sort -u | fzf --height=40% --reverse --prompt="stern workload> ")

        if test -n "$result"
            # NO trailing space - allows immediate <TAB> for flags
            commandline -t -- "$result"
        end

        commandline -f repaint
        return
    end

    # For flags, fall back to fifc
    _fifc 2>/dev/null
    commandline -f repaint
end
