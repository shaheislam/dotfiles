# FZF-powered ECS navigation - E1S replacement
# Provides hierarchical navigation: Cluster -> Service -> Task -> Container
# with keybindings for common operations (logs, exec, scale, etc.)

# Toggle for FZF mode
set -g ecs_use_fzf true

# ============================================================================
# Helper Functions
# ============================================================================

function __ecs_list_clusters --description "List ECS clusters"
    aws ecs list-clusters --query 'clusterArns[*]' --output text 2>/dev/null | tr '\t' '\n' | sed 's|.*/||'
end

function __ecs_list_services --argument cluster --description "List services in cluster"
    aws ecs list-services --cluster $cluster --query 'serviceArns[*]' --output text 2>/dev/null | tr '\t' '\n' | sed 's|.*/||'
end

function __ecs_list_tasks --argument cluster --argument service --description "List tasks for service"
    aws ecs list-tasks --cluster $cluster --service-name $service --query 'taskArns[*]' --output text 2>/dev/null | tr '\t' '\n' | sed 's|.*/||'
end

function __ecs_list_all_tasks --argument cluster --description "List all tasks in cluster"
    aws ecs list-tasks --cluster $cluster --query 'taskArns[*]' --output text 2>/dev/null | tr '\t' '\n' | sed 's|.*/||'
end

function __ecs_get_task_containers --argument cluster --argument task --description "Get container names for task"
    aws ecs describe-tasks --cluster $cluster --tasks $task --query 'tasks[0].containers[*].name' --output text 2>/dev/null | tr '\t' '\n'
end

function __ecs_get_log_group --argument cluster --argument service --description "Get CloudWatch log group for service"
    set -l task_def (aws ecs describe-services --cluster $cluster --services $service --query 'services[0].taskDefinition' --output text 2>/dev/null)
    if test -n "$task_def"
        aws ecs describe-task-definition --task-definition $task_def --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-group"' --output text 2>/dev/null
    end
end

function __ecs_get_log_stream_prefix --argument cluster --argument service --description "Get CloudWatch log stream prefix"
    set -l task_def (aws ecs describe-services --cluster $cluster --services $service --query 'services[0].taskDefinition' --output text 2>/dev/null)
    if test -n "$task_def"
        aws ecs describe-task-definition --task-definition $task_def --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-stream-prefix"' --output text 2>/dev/null
    end
end

# ============================================================================
# Selection Functions (for convenience aliases)
# ============================================================================

function ecs_select_cluster --description "Interactive cluster selection"
    __ecs_list_clusters | fzf --height=40% --prompt="Cluster: " --preview="aws ecs describe-clusters --clusters {} --query 'clusters[0]' --output json 2>/dev/null | jq -C '{clusterName, status, runningTasksCount, pendingTasksCount, activeServicesCount}'"
end

function ecs_select_service --argument cluster --description "Interactive service selection"
    __ecs_list_services $cluster | fzf --height=40% --prompt="Service: " --preview="aws ecs describe-services --cluster $cluster --services {} --query 'services[0]' --output json 2>/dev/null | jq -C '{serviceName, status, desiredCount, runningCount, pendingCount}'"
end

function ecs_select_task --argument cluster --argument service --description "Interactive task selection"
    __ecs_list_tasks $cluster $service | fzf --height=40% --prompt="Task: " --preview="aws ecs describe-tasks --cluster $cluster --tasks {} --query 'tasks[0]' --output json 2>/dev/null | jq -C '{taskArn, lastStatus, cpu, memory, containers: [.containers[] | {name, lastStatus}]}'"
end

# ============================================================================
# Main ECS Command
# ============================================================================

function ecs --description "FZF-powered ECS navigation"
    set -l argc (count $argv)

    # No arguments - start interactive cluster selection
    if test $argc -eq 0
        set -l cluster (ecs_select_cluster)
        if test -z "$cluster"
            return 1
        end
        # Continue to service selection
        set -l service (ecs_select_service $cluster)
        if test -z "$service"
            return 1
        end
        # Show tasks with full keybindings
        __ecs_show_tasks $cluster $service
        return
    end

    # Handle subcommands
    switch $argv[1]
        case logs
            if test $argc -lt 3
                echo "Usage: ecs logs <cluster> <service>"
                return 1
            end
            __ecs_logs $argv[2] $argv[3]

        case exec
            if test $argc -lt 3
                echo "Usage: ecs exec <cluster> <service> [task]"
                return 1
            end
            if test $argc -eq 3
                # Select task interactively
                set -l task (ecs_select_task $argv[2] $argv[3])
                if test -n "$task"
                    __ecs_exec $argv[2] $task
                end
            else
                __ecs_exec $argv[2] $argv[4]
            end

        case scale
            if test $argc -lt 4
                echo "Usage: ecs scale <cluster> <service> <count>"
                return 1
            end
            __ecs_scale $argv[2] $argv[3] $argv[4]

        case deploy
            if test $argc -lt 3
                echo "Usage: ecs deploy <cluster> <service>"
                return 1
            end
            __ecs_force_deploy $argv[2] $argv[3]

        case stop
            if test $argc -lt 3
                echo "Usage: ecs stop <cluster> <task>"
                return 1
            end
            __ecs_stop_task $argv[2] $argv[3]

        case '*'
            # Treat first arg as cluster, show services
            set -l cluster $argv[1]
            if test $argc -eq 1
                set -l service (ecs_select_service $cluster)
                if test -n "$service"
                    __ecs_show_tasks $cluster $service
                end
            else
                # cluster and service provided, show tasks
                __ecs_show_tasks $argv[1] $argv[2]
            end
    end
end

# ============================================================================
# Operation Functions
# ============================================================================

function __ecs_show_tasks --argument cluster --argument service --description "Show tasks with FZF and keybindings"
    set -l tasks (__ecs_list_tasks $cluster $service)

    if test (count $tasks) -eq 0
        echo "No tasks found for $service in $cluster"
        return 1
    end

    # Preview command for tasks
    set -l preview_cmd "aws ecs describe-tasks --cluster $cluster --tasks {} --query 'tasks[0]' --output json 2>/dev/null | jq -C '{taskArn: .taskArn, lastStatus: .lastStatus, desiredStatus: .desiredStatus, cpu: .cpu, memory: .memory, startedAt: .startedAt, containers: [.containers[] | {name, lastStatus, healthStatus}]}'"

    # Keybinding commands
    set -l exec_cmd "bash -c 'container=\$(aws ecs describe-tasks --cluster $cluster --tasks {} --query \"tasks[0].containers[*].name\" --output text 2>/dev/null | tr \"\\t\" \"\\n\" | fzf --height=30% --prompt=\"Container: \"); if [ -n \"\$container\" ]; then aws ecs execute-command --cluster $cluster --task {} --container \$container --interactive --command /bin/bash; fi'"

    set -l logs_cmd "bash -c 'log_group=\"\$(aws ecs describe-services --cluster $cluster --services $service --query \"services[0].taskDefinition\" --output text 2>/dev/null | xargs -I@ aws ecs describe-task-definition --task-definition @ --query \"taskDefinition.containerDefinitions[0].logConfiguration.options.\\\"awslogs-group\\\"\" --output text 2>/dev/null)\"; if [ -n \"\$log_group\" ]; then aws logs tail \"\$log_group\" --follow --format short; else echo \"No log group found\"; sleep 2; fi'"

    set -l describe_cmd "aws ecs describe-tasks --cluster $cluster --tasks {} --output json 2>/dev/null | jq -C . | less -R"

    set -l json_cmd "aws ecs describe-tasks --cluster $cluster --tasks {} --output json 2>/dev/null | bat --color=always -l json --paging=always"

    set -l taskdef_cmd "bash -c 'task_def=\$(aws ecs describe-tasks --cluster $cluster --tasks {} --query \"tasks[0].taskDefinitionArn\" --output text 2>/dev/null); aws ecs describe-task-definition --task-definition \$task_def --output json 2>/dev/null | jq -C . | less -R'"

    set -l stop_cmd "bash -c 'read -p \"Stop task {}? [y/N] \" c; if [ \"\$c\" = \"y\" ]; then aws ecs stop-task --cluster $cluster --task {} && echo \"Task stopped\" && sleep 1; fi'"

    set -l scale_cmd "bash -c 'exec </dev/tty >/dev/tty 2>&1; read -p \"Desired count (0-20): \" n; aws ecs update-service --cluster $cluster --service $service --desired-count \$n >/dev/null && echo \"Scaled $service to \$n\" && sleep 1'"

    set -l deploy_cmd "bash -c 'aws ecs update-service --cluster $cluster --service $service --force-new-deployment >/dev/null && echo \"Force deployment initiated for $service\" && sleep 1'"

    set -l reload_cmd "aws ecs list-tasks --cluster $cluster --service-name $service --query 'taskArns[*]' --output text 2>/dev/null | tr '\t' '\n' | sed 's|.*/||'"

    set -l copy_cmd "bash -c 'echo -n \"arn:aws:ecs:\$(aws configure get region):\$(aws sts get-caller-identity --query Account --output text):task/$cluster/{}\" | pbcopy && echo \"Task ARN copied to clipboard\" && sleep 1'"

    # Header with keybinding help
    set -l header_text "Alt+1:taskdef 2:exec 3:json 4:desc 5:logs 8:scale 9:deploy X:stop | C:copy R:reload"

    printf '%s\n' $tasks | fzf --height=60% \
        --header "$header_text" \
        --prompt="Task ($service): " \
        --preview="$preview_cmd" \
        --preview-window='right:50%:wrap' \
        --bind "ctrl-r:reload($reload_cmd)" \
        --bind "alt-1:execute($taskdef_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-2:execute($exec_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-3:execute($json_cmd)" \
        --bind "alt-4:execute($describe_cmd)" \
        --bind "alt-5:execute($logs_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-8:execute($scale_cmd)" \
        --bind "alt-9:execute($deploy_cmd < /dev/tty > /dev/tty)" \
        --bind "alt-x:execute($stop_cmd < /dev/tty > /dev/tty)+reload($reload_cmd)" \
        --bind "alt-c:execute($copy_cmd)"
end

function __ecs_logs --argument cluster --argument service --description "Tail CloudWatch logs for service"
    set -l log_group (__ecs_get_log_group $cluster $service)

    if test -z "$log_group"; or test "$log_group" = "None"
        echo "No log group found for $service"
        return 1
    end

    echo "Tailing logs from: $log_group"
    aws logs tail "$log_group" --follow --format short
end

function __ecs_exec --argument cluster --argument task --description "ECS Exec into container"
    set -l containers (__ecs_get_task_containers $cluster $task)

    if test (count $containers) -eq 0
        echo "No containers found in task"
        return 1
    end

    set -l container
    if test (count $containers) -eq 1
        set container $containers[1]
    else
        set container (printf '%s\n' $containers | fzf --height=30% --prompt="Container: ")
    end

    if test -z "$container"
        return 1
    end

    echo "Connecting to $container in task $task..."
    aws ecs execute-command --cluster $cluster --task $task --container $container --interactive --command /bin/bash
end

function __ecs_scale --argument cluster --argument service --argument count --description "Scale service"
    echo "Scaling $service to $count tasks..."
    aws ecs update-service --cluster $cluster --service $service --desired-count $count --query 'service.{name:serviceName,desired:desiredCount,running:runningCount}' --output table
end

function __ecs_force_deploy --argument cluster --argument service --description "Force new deployment"
    echo "Forcing new deployment for $service..."
    aws ecs update-service --cluster $cluster --service $service --force-new-deployment --query 'service.{name:serviceName,status:status,deployments:deployments[0].status}' --output table
end

function __ecs_stop_task --argument cluster --argument task --description "Stop a task"
    echo "Stopping task $task..."
    aws ecs stop-task --cluster $cluster --task $task --query 'task.{taskArn:taskArn,lastStatus:lastStatus,stoppedReason:stoppedReason}' --output table
end

# ============================================================================
# Convenience Aliases
# ============================================================================

function ecslogs --description "Interactive ECS log viewer"
    set -l cluster (ecs_select_cluster)
    test -z "$cluster"; and return 1

    set -l service (ecs_select_service $cluster)
    test -z "$service"; and return 1

    __ecs_logs $cluster $service
end

function ecsexec --description "Interactive ECS Exec"
    set -l cluster (ecs_select_cluster)
    test -z "$cluster"; and return 1

    set -l service (ecs_select_service $cluster)
    test -z "$service"; and return 1

    set -l task (ecs_select_task $cluster $service)
    test -z "$task"; and return 1

    __ecs_exec $cluster $task
end

function ecsscale --description "Interactive ECS service scaling"
    set -l cluster (ecs_select_cluster)
    test -z "$cluster"; and return 1

    set -l service (ecs_select_service $cluster)
    test -z "$service"; and return 1

    read -P "Desired count: " count
    if test -n "$count"
        __ecs_scale $cluster $service $count
    end
end

function ecsdeploy --description "Interactive ECS force deployment"
    set -l cluster (ecs_select_cluster)
    test -z "$cluster"; and return 1

    set -l service (ecs_select_service $cluster)
    test -z "$service"; and return 1

    __ecs_force_deploy $cluster $service
end

# Toggle function
function ecs_toggle_fzf --description "Toggle FZF mode for ECS"
    if test "$ecs_use_fzf" = "true"
        set -g ecs_use_fzf false
        echo "ECS FZF mode disabled"
    else
        set -g ecs_use_fzf true
        echo "ECS FZF mode enabled"
    end
end
