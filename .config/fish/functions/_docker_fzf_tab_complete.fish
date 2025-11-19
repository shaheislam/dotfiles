function _docker_fzf_tab_complete -d "Map docker subcommands to fzf-docker.sh commands on TAB"
    # Ensure we don't interfere with Docker operations - handle errors gracefully
    set -l cmd (commandline -opc) 2>/dev/null

    # Need at least "docker subcommand" to determine which fzf command to use
    if test (count $cmd) -lt 2
        _fifc 2>/dev/null || complete
        return
    end

    set -l docker_subcommand $cmd[2]

    # Map docker subcommands to fzf-docker.sh commands
    switch $docker_subcommand
        case ps
            # Container listing
            __fzf_docker_sh containers 2>/dev/null
        case start stop restart kill pause unpause
            # Container operations - show all containers
            __fzf_docker_sh all_containers 2>/dev/null
        case exec attach
            # Interactive container operations - show running containers only
            __fzf_docker_sh containers 2>/dev/null
        case logs inspect stats top
            # Container inspection - show all containers
            __fzf_docker_sh all_containers 2>/dev/null
        case rm
            # Remove containers - show stopped containers
            __fzf_docker_sh all_containers 2>/dev/null
        case images
            # Image listing
            __fzf_docker_sh images 2>/dev/null
        case rmi
            # Remove images
            __fzf_docker_sh images 2>/dev/null
        case run
            # Run container from image
            __fzf_docker_sh images 2>/dev/null
        case pull push
            # Image registry operations - show images
            __fzf_docker_sh images 2>/dev/null
        case tag
            # Tag images
            __fzf_docker_sh images 2>/dev/null
        case volume
            # Volume operations - context-aware routing
            if test (count $cmd) -ge 3
                set -l volume_cmd $cmd[3]
                switch $volume_cmd
                    case ls
                        __fzf_docker_sh volumes 2>/dev/null
                    case rm
                        __fzf_docker_sh volumes 2>/dev/null
                    case inspect
                        __fzf_docker_sh volumes 2>/dev/null
                    case '*'
                        return 1
                end
            else
                return 1
            end
        case network
            # Network operations - context-aware routing
            if test (count $cmd) -ge 3
                set -l network_cmd $cmd[3]
                switch $network_cmd
                    case ls
                        __fzf_docker_sh networks 2>/dev/null
                    case rm
                        __fzf_docker_sh networks 2>/dev/null
                    case inspect
                        __fzf_docker_sh networks 2>/dev/null
                    case connect disconnect
                        # Show networks for connect/disconnect
                        __fzf_docker_sh networks 2>/dev/null
                    case '*'
                        return 1
                end
            else
                return 1
            end
        case compose
            # Docker Compose operations - context-aware routing
            if test (count $cmd) -ge 3
                set -l compose_cmd $cmd[3]
                switch $compose_cmd
                    case up down start stop restart
                        __fzf_docker_sh compose_services 2>/dev/null
                    case logs
                        __fzf_docker_sh compose_services 2>/dev/null
                    case '*'
                        return 1
                end
            else
                return 1
            end
        case container
            # Container management subcommands
            if test (count $cmd) -ge 3
                set -l container_cmd $cmd[3]
                switch $container_cmd
                    case ls
                        __fzf_docker_sh containers 2>/dev/null
                    case start stop restart kill pause unpause
                        __fzf_docker_sh all_containers 2>/dev/null
                    case rm
                        __fzf_docker_sh all_containers 2>/dev/null
                    case exec attach
                        __fzf_docker_sh containers 2>/dev/null
                    case logs inspect stats top
                        __fzf_docker_sh all_containers 2>/dev/null
                    case '*'
                        return 1
                end
            else
                return 1
            end
        case image
            # Image management subcommands
            if test (count $cmd) -ge 3
                set -l image_cmd $cmd[3]
                switch $image_cmd
                    case ls
                        __fzf_docker_sh images 2>/dev/null
                    case rm
                        __fzf_docker_sh images 2>/dev/null
                    case inspect
                        __fzf_docker_sh images 2>/dev/null
                    case tag
                        __fzf_docker_sh images 2>/dev/null
                    case '*'
                        return 1
                end
            else
                return 1
            end
        case '*'
            # Fall back to normal completion for other docker commands
            return 1
    end
end
