function devcon --description "Launch devcontainer with dynamic mounts and advanced options"
    # Container type configurations
    # Format: "name:path"
    set -l containers
    set -a containers "claude:$HOME/.claude/plugins/marketplaces/claude-code-plugins"
    # Add more container types here as needed:
    # set -a containers "node:$HOME/.devcontainers/node"

    # Parse arguments
    set -l container_type $argv[1]
    set -l dirs
    set -l env_vars
    set -l features
    set -l do_exec false
    set -l do_down false
    set -l do_rebuild false
    set -l do_fast false
    set -l do_gpu false
    set -l do_config false
    set -l do_build false
    set -l show_help false
    set -l skip_next false

    # Common feature shortcuts (maps short name to full ghcr.io path)
    set -l feature_shortcuts
    set -a feature_shortcuts "python:ghcr.io/devcontainers/features/python:1"
    set -a feature_shortcuts "node:ghcr.io/devcontainers/features/node:1"
    set -a feature_shortcuts "go:ghcr.io/devcontainers/features/go:1"
    set -a feature_shortcuts "rust:ghcr.io/devcontainers/features/rust:1"
    set -a feature_shortcuts "java:ghcr.io/devcontainers/features/java:1"
    set -a feature_shortcuts "ruby:ghcr.io/devcontainers/features/ruby:1"
    set -a feature_shortcuts "php:ghcr.io/devcontainers/features/php:1"
    set -a feature_shortcuts "dotnet:ghcr.io/devcontainers/features/dotnet:2"
    set -a feature_shortcuts "aws:ghcr.io/devcontainers/features/aws-cli:1"
    set -a feature_shortcuts "azure:ghcr.io/devcontainers/features/azure-cli:1"
    set -a feature_shortcuts "gcloud:ghcr.io/devcontainers/features/gcloud:1"
    set -a feature_shortcuts "terraform:ghcr.io/devcontainers/features/terraform:1"
    set -a feature_shortcuts "kubectl:ghcr.io/devcontainers/features/kubectl-helm-minikube:1"
    set -a feature_shortcuts "docker:ghcr.io/devcontainers/features/docker-in-docker:2"
    set -a feature_shortcuts "git:ghcr.io/devcontainers/features/git:1"
    set -a feature_shortcuts "github:ghcr.io/devcontainers/features/github-cli:1"
    set -a feature_shortcuts "common:ghcr.io/devcontainers/features/common-utils:2"

    # No arguments or help flag as first arg - show help
    if test (count $argv) -eq 0
        set show_help true
    else if test "$container_type" = "--help" -o "$container_type" = "-h"
        set show_help true
    end

    # Parse remaining args
    set -l i 2
    while test $i -le (count $argv)
        set -l arg $argv[$i]

        # Check if we should skip this arg (it was consumed as a value)
        if $skip_next
            set skip_next false
            set i (math $i + 1)
            continue
        end

        switch $arg
            case --exec -e
                set do_exec true
            case --down -d
                set do_down true
            case --rebuild -r
                set do_rebuild true
            case --fast -f
                set do_fast true
            case --gpu -g
                set do_gpu true
            case --config -c
                set do_config true
            case --build -b
                set do_build true
            case --help -h
                set show_help true
            case --env -E
                # Next arg is the env var value
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -a env_vars $argv[$next_i]
                    set skip_next true
                else
                    echo "Error: --env requires a value (e.g., --env KEY=value)"
                    return 1
                end
            case --feature -F
                # Next arg is the feature name
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l feature_name $argv[$next_i]
                    # Check if it's a shortcut or full path
                    set -l resolved_feature ""
                    for shortcut in $feature_shortcuts
                        set -l short_name (string split ":" $shortcut)[1]
                        set -l full_path (string split ":" $shortcut)[2..]
                        if test "$feature_name" = "$short_name"
                            set resolved_feature (string join ":" $full_path)
                            break
                        end
                    end
                    # If not a shortcut, use as-is (assume full ghcr.io path)
                    if test -z "$resolved_feature"
                        set resolved_feature $feature_name
                    end
                    set -a features $resolved_feature
                    set skip_next true
                else
                    echo "Error: --feature requires a value (e.g., --feature python)"
                    return 1
                end
            case '*'
                # Check if it's KEY=VALUE format after -E (for -E KEY=VALUE without space)
                if string match -q "*=*" $arg
                    # Could be an env var passed directly
                    set -a env_vars $arg
                else
                    # Treat as directory to mount
                    set -l expanded_arg (eval echo $arg)
                    if test -d "$expanded_arg"
                        set -a dirs $expanded_arg
                    else
                        echo "Warning: Directory not found: $arg"
                    end
                end
        end
        set i (math $i + 1)
    end

    # Show help
    if $show_help
        echo "Usage: devcon <container-type> [directories...] [options]"
        echo ""
        echo "Container types:"
        for c in $containers
            set -l name (string split ":" $c)[1]
            set -l path (string split ":" $c)[2]
            echo "  $name -> $path"
        end
        echo ""
        echo "Options:"
        echo "  --exec, -e      Enter container shell after starting"
        echo "  --down, -d      Stop the container"
        echo "  --env, -E       Set environment variable (repeatable): -E KEY=value"
        echo "  --feature, -F   Add feature (repeatable, implies rebuild): -F python"
        echo "  --rebuild, -r   Remove existing container and rebuild"
        echo "  --fast, -f      Skip lifecycle hooks (postCreateCommand, etc)"
        echo "  --gpu, -g       Enable GPU passthrough"
        echo "  --config, -c    Show resolved configuration (no start)"
        echo "  --build, -b     Build image only (no start)"
        echo "  --help, -h      Show this help"
        echo ""
        echo "Feature shortcuts: python, node, go, rust, java, ruby, php, dotnet,"
        echo "                   aws, azure, gcloud, terraform, kubectl, docker, git, github"
        echo ""
        echo "Examples:"
        echo "  devcon claude                           # Start container"
        echo "  devcon claude ~/project-a -e            # Mount + exec"
        echo "  devcon claude -E API_KEY=xxx -e         # With env var"
        echo "  devcon claude -F python -F node         # Add Python + Node (rebuilds)"
        echo "  devcon claude --rebuild --fast          # Fresh, fast startup"
        echo "  devcon claude --gpu ~/ml-project        # GPU for ML work"
        echo "  devcon claude --config                  # Debug: show config"
        return 0
    end

    # Find container workspace path
    set -l workspace ""
    for c in $containers
        set -l name (string split ":" $c)[1]
        set -l path (string split ":" $c)[2]
        if test "$container_type" = "$name"
            set workspace $path
            break
        end
    end

    if test -z "$workspace"
        echo "Error: Unknown container type: $container_type"
        echo "Run 'devcon --help' for available types"
        return 1
    end

    # Features require rebuild - auto-enable if features specified
    if test (count $features) -gt 0
        if not $do_rebuild
            echo "Note: Features require container rebuild - enabling --rebuild automatically"
            set do_rebuild true
        end
    end

    # Handle config command (no container start)
    if $do_config
        echo "Showing configuration for $container_type..."
        devcontainer read-configuration --workspace-folder $workspace
        return $status
    end

    # Handle build command (no container start)
    if $do_build
        echo "Building $container_type image..."
        devcontainer build --workspace-folder $workspace
        return $status
    end

    # Handle down command
    if $do_down
        echo "Stopping $container_type devcontainer..."
        devcontainer down --workspace-folder $workspace
        return $status
    end

    # Build mount arguments
    set -l mount_args
    for dir in $dirs
        set -l dirname (basename $dir)
        set -l mount_spec "type=bind,source=$dir,target=/mounts/$dirname"
        set -a mount_args "--mount" "$mount_spec"
    end

    # Build env arguments
    set -l env_args
    for env_var in $env_vars
        set -a env_args "--remote-env" "$env_var"
    end

    # Build additional flags
    set -l extra_args
    if $do_rebuild
        set -a extra_args "--remove-existing-container"
    end
    if $do_fast
        set -a extra_args "--skip-post-create"
    end
    if $do_gpu
        set -a extra_args "--gpu-availability" "all"
    end

    # Build features JSON for --additional-features
    set -l feature_args
    if test (count $features) -gt 0
        # Build JSON object: {"feature1": {}, "feature2": {}, ...}
        set -l json_parts
        for feature in $features
            set -a json_parts "\"$feature\": {}"
        end
        set -l features_json "{" (string join ", " $json_parts) "}"
        set -a feature_args "--additional-features" "$features_json"
    end

    # Start container
    echo "Starting $container_type devcontainer..."
    if test (count $dirs) -gt 0
        echo "Additional mounts:"
        for dir in $dirs
            echo "  $dir -> /mounts/"(basename $dir)
        end
    end
    if test (count $env_vars) -gt 0
        echo "Environment variables:"
        for env_var in $env_vars
            # Only show key, not value for security
            set -l key (string split "=" $env_var)[1]
            echo "  $key=***"
        end
    end
    if $do_rebuild
        echo "Mode: Rebuild (removing existing container)"
    end
    if $do_fast
        echo "Mode: Fast (skipping lifecycle hooks)"
    end
    if $do_gpu
        echo "Mode: GPU enabled"
    end
    if test (count $features) -gt 0
        echo "Features to install:"
        for feature in $features
            echo "  $feature"
        end
    end

    devcontainer up $mount_args $env_args $extra_args $feature_args --workspace-folder $workspace

    # Exec into container if requested
    if $do_exec
        and devcontainer exec --workspace-folder $workspace zsh
    end
end
