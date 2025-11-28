# TAB completion router for ECS FZF
# Routes ecs command completions through FZF

function _ecs_fzf_tab_complete --description "FZF-powered ECS tab completion"
    set -l cmd (commandline -opc)
    set -l current (commandline -ct)

    # Skip if not ecs command
    if test "$cmd[1]" != "ecs"
        return
    end

    set -l argc (math (count $cmd) - 1)

    # Determine what to complete based on position
    if test $argc -eq 0
        # No args yet - complete with clusters or subcommands
        set -l subcommands "logs" "exec" "scale" "deploy" "stop"
        set -l clusters (__ecs_list_clusters 2>/dev/null)

        # Combine subcommands and clusters
        set -l completions $subcommands $clusters

        if test -n "$current"
            set -l filtered
            for c in $completions
                if string match -q -- "$current*" $c
                    set -a filtered $c
                end
            end
            set completions $filtered
        end

        if test (count $completions) -eq 0
            return
        end

        if test (count $completions) -eq 1
            echo $completions[1]
            return
        end

        # FZF selection
        set -l selected (printf '%s\n' $completions | fzf --height=40% --prompt="Cluster/Command: " --query="$current")
        echo $selected

    else if test $argc -eq 1
        # One arg - could be subcommand or cluster
        set -l first_arg $cmd[2]

        switch $first_arg
            case logs exec scale deploy stop
                # Subcommand - complete with clusters
                set -l clusters (__ecs_list_clusters 2>/dev/null)

                if test -n "$current"
                    set -l filtered
                    for c in $clusters
                        if string match -q -- "$current*" $c
                            set -a filtered $c
                        end
                    end
                    set clusters $filtered
                end

                if test (count $clusters) -eq 0
                    return
                end

                if test (count $clusters) -eq 1
                    echo $clusters[1]
                    return
                end

                set -l preview_cmd "aws ecs describe-clusters --clusters {} --query 'clusters[0]' --output json 2>/dev/null | jq -C '{clusterName, status, runningTasksCount, pendingTasksCount}'"
                set -l selected (printf '%s\n' $clusters | fzf --height=40% --prompt="Cluster: " --preview="$preview_cmd" --query="$current")
                echo $selected

            case '*'
                # First arg is cluster - complete with services
                set -l cluster $first_arg
                set -l services (__ecs_list_services $cluster 2>/dev/null)

                if test -n "$current"
                    set -l filtered
                    for s in $services
                        if string match -q -- "$current*" $s
                            set -a filtered $s
                        end
                    end
                    set services $filtered
                end

                if test (count $services) -eq 0
                    return
                end

                if test (count $services) -eq 1
                    echo $services[1]
                    return
                end

                set -l preview_cmd "aws ecs describe-services --cluster $cluster --services {} --query 'services[0]' --output json 2>/dev/null | jq -C '{serviceName, status, desiredCount, runningCount, pendingCount}'"
                set -l selected (printf '%s\n' $services | fzf --height=40% --prompt="Service: " --preview="$preview_cmd" --query="$current")
                echo $selected
        end

    else if test $argc -eq 2
        # Two args - complete with services or tasks depending on context
        set -l first_arg $cmd[2]
        set -l second_arg $cmd[3]

        switch $first_arg
            case logs exec scale deploy
                # Subcommand + cluster - complete with services
                set -l cluster $second_arg
                set -l services (__ecs_list_services $cluster 2>/dev/null)

                if test -n "$current"
                    set -l filtered
                    for s in $services
                        if string match -q -- "$current*" $s
                            set -a filtered $s
                        end
                    end
                    set services $filtered
                end

                if test (count $services) -eq 0
                    return
                end

                if test (count $services) -eq 1
                    echo $services[1]
                    return
                end

                set -l preview_cmd "aws ecs describe-services --cluster $cluster --services {} --query 'services[0]' --output json 2>/dev/null | jq -C '{serviceName, status, desiredCount, runningCount}'"
                set -l selected (printf '%s\n' $services | fzf --height=40% --prompt="Service: " --preview="$preview_cmd" --query="$current")
                echo $selected

            case stop
                # stop needs cluster + task
                set -l cluster $second_arg
                set -l tasks (__ecs_list_all_tasks $cluster 2>/dev/null)

                if test -n "$current"
                    set -l filtered
                    for t in $tasks
                        if string match -q -- "$current*" $t
                            set -a filtered $t
                        end
                    end
                    set tasks $filtered
                end

                if test (count $tasks) -eq 0
                    return
                end

                if test (count $tasks) -eq 1
                    echo $tasks[1]
                    return
                end

                set -l preview_cmd "aws ecs describe-tasks --cluster $cluster --tasks {} --query 'tasks[0]' --output json 2>/dev/null | jq -C '{taskArn, lastStatus, cpu, memory}'"
                set -l selected (printf '%s\n' $tasks | fzf --height=40% --prompt="Task: " --preview="$preview_cmd" --query="$current")
                echo $selected

            case '*'
                # cluster + service - complete with tasks
                set -l cluster $first_arg
                set -l service $second_arg
                set -l tasks (__ecs_list_tasks $cluster $service 2>/dev/null)

                if test -n "$current"
                    set -l filtered
                    for t in $tasks
                        if string match -q -- "$current*" $t
                            set -a filtered $t
                        end
                    end
                    set tasks $filtered
                end

                if test (count $tasks) -eq 0
                    return
                end

                if test (count $tasks) -eq 1
                    echo $tasks[1]
                    return
                end

                set -l preview_cmd "aws ecs describe-tasks --cluster $cluster --tasks {} --query 'tasks[0]' --output json 2>/dev/null | jq -C '{taskArn, lastStatus, cpu, memory, containers: [.containers[] | {name, lastStatus}]}'"
                set -l selected (printf '%s\n' $tasks | fzf --height=40% --prompt="Task: " --preview="$preview_cmd" --query="$current")
                echo $selected
        end

    else if test $argc -eq 3
        # Three args - for exec subcommand, complete with tasks
        set -l first_arg $cmd[2]

        if test "$first_arg" = "exec"
            set -l cluster $cmd[3]
            set -l service $cmd[4]
            set -l tasks (__ecs_list_tasks $cluster $service 2>/dev/null)

            if test -n "$current"
                set -l filtered
                for t in $tasks
                    if string match -q -- "$current*" $t
                        set -a filtered $t
                    end
                end
                set tasks $filtered
            end

            if test (count $tasks) -eq 0
                return
            end

            if test (count $tasks) -eq 1
                echo $tasks[1]
                return
            end

            set -l preview_cmd "aws ecs describe-tasks --cluster $cluster --tasks {} --query 'tasks[0]' --output json 2>/dev/null | jq -C '{taskArn, lastStatus, containers: [.containers[] | {name, lastStatus}]}'"
            set -l selected (printf '%s\n' $tasks | fzf --height=40% --prompt="Task: " --preview="$preview_cmd" --query="$current")
            echo $selected
        end
    end
end
