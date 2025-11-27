function _stern_fzf_tab_complete -d "FZF tab completion for stern with no trailing space"
    set -l cmd (commandline -opc) 2>/dev/null
    set -l current_token (commandline -ct)

    # Check if completing -n/--namespace flag value
    set -l prev_token ""
    if test (count $cmd) -ge 2
        set prev_token $cmd[-1]
    end

    if test "$prev_token" = "-n"; or test "$prev_token" = "--namespace"
        set -l result (kubectl get namespaces -o name 2>/dev/null | sed 's|namespace/||' | \
            fzf --height=40% --reverse --prompt="namespace > ")
        if test -n "$result"
            commandline -t -- "$result"
        end
        commandline -f repaint
        return
    end

    # Check if we're completing the first argument (workload name)
    if test (count $cmd) -eq 1; or begin
            test (count $cmd) -eq 2; and not string match -q -- '-*' "$current_token"
        end

        # Get all workloads that stern supports, formatted as type/name
        # Also include namespaces - selecting one expands to ". -n <namespace>"
        set -l result (begin
            kubectl get namespaces -o name 2>/dev/null  # namespace/xxx
            kubectl get deployments -o name 2>/dev/null | string replace "deployment.apps/" "deployment/"
            kubectl get statefulsets -o name 2>/dev/null | string replace "statefulset.apps/" "statefulset/"
            kubectl get daemonsets -o name 2>/dev/null | string replace "daemonset.apps/" "daemonset/"
            kubectl get replicasets -o name 2>/dev/null | string replace "replicaset.apps/" "replicaset/"
            kubectl get jobs -o name 2>/dev/null | string replace "job.batch/" "job/"
            kubectl get services -o name 2>/dev/null | string replace "service/" "service/"
            kubectl get replicationcontrollers -o name 2>/dev/null | string replace "replicationcontroller/" "replicationcontroller/"
        end | sort -u | fzf --height=40% --reverse --prompt="stern > " \
            --header="namespace/ → all pods in ns | workload → pods matching pattern")

        if test -n "$result"
            # Transform namespace selections to ". -n <namespace>" for tailing all pods
            if string match -q "namespace/*" "$result"
                set -l ns (string replace "namespace/" "" "$result")
                commandline -t -- ". -n $ns"
            else
                # NO trailing space - allows immediate <TAB> for flags
                commandline -t -- "$result"
            end
        end

        commandline -f repaint
        return
    end

    # For flags, fall back to fifc
    _fifc 2>/dev/null
    commandline -f repaint
end
