function gwt-dev --description "Create worktree with isolated devcontainer"
    # Usage: gwt-dev <branch> [--exec] [--new] [--features python,node] [--mount <dir>] [--no-devcon]
    #
    # Creates a git worktree in ../repo-branch format and optionally launches
    # a devcontainer with isolated storage using the worktree name as instance.
    #
    # Options:
    #   --exec, -e      Enter container shell after starting
    #   --new, -n       Create new branch (like gwtabf instead of gwtaf)
    #   --features, -F  Add devcontainer features (comma-separated or multiple -F)
    #   --mount, -m     Add additional directory mount (repeatable)
    #   --no-devcon     Create worktree only, skip devcontainer
    #   --rebuild, -r   Rebuild devcontainer (remove existing)
    #   --fast, -f      Skip lifecycle hooks in devcontainer
    #   --no-cd         Don't cd into the worktree (useful when called from other functions)
    #   --help, -h      Show this help

    # Parse arguments
    set -l branch ""
    set -l do_exec false
    set -l do_new false
    set -l do_no_devcon false
    set -l do_no_cd false
    set -l do_rebuild false
    set -l do_fast false
    set -l show_help false
    set -l features
    set -l mounts
    set -l skip_next false

    for i in (seq (count $argv))
        if $skip_next
            set skip_next false
            continue
        end

        set -l arg $argv[$i]

        switch $arg
            case --exec -e
                set do_exec true
            case --new -n
                set do_new true
            case --no-devcon
                set do_no_devcon true
            case --no-cd
                set do_no_cd true
            case --rebuild -r
                set do_rebuild true
            case --fast -f
                set do_fast true
            case --help -h
                set show_help true
            case --features -F
                # Next arg is features (comma-separated)
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    # Split by comma and add each feature
                    for feature in (string split "," $argv[$next_i])
                        set -a features $feature
                    end
                    set skip_next true
                else
                    echo "Error: --features requires a value"
                    return 1
                end
            case --mount -m
                # Next arg is directory to mount
                set -l next_i (math $i + 1)
                if test $next_i -le (count $argv)
                    set -l mount_path $argv[$next_i]
                    # Expand path and validate
                    set -l expanded_path (string replace -r '^\~' "$HOME" $mount_path)
                    if test -d "$expanded_path"
                        set -a mounts (realpath $expanded_path)
                    else
                        echo "Error: Mount directory not found: $mount_path"
                        return 1
                    end
                    set skip_next true
                else
                    echo "Error: --mount requires a directory path"
                    return 1
                end
            case '-*'
                echo "Error: Unknown option: $arg"
                return 1
            case '*'
                if test -z "$branch"
                    set branch $arg
                else
                    echo "Error: Multiple branches specified"
                    return 1
                end
        end
    end

    # Show help
    if $show_help
        echo "Usage: gwt-dev <branch> [options]"
        echo ""
        echo "Create a git worktree with isolated devcontainer environment."
        echo ""
        echo "Options:"
        echo "  --exec, -e      Enter container shell after starting"
        echo "  --new, -n       Create new branch (instead of checking out existing)"
        echo "  --features, -F  Add devcontainer features (comma-separated)"
        echo "  --mount, -m     Add additional directory mount (repeatable)"
        echo "  --no-devcon     Create worktree only, skip devcontainer"
        echo "  --no-cd         Don't cd into the worktree after creation"
        echo "  --rebuild, -r   Rebuild devcontainer (remove existing container)"
        echo "  --fast, -f      Skip devcontainer lifecycle hooks"
        echo "  --help, -h      Show this help"
        echo ""
        echo "Feature shortcuts: python, node, go, rust, java, ruby, php, dotnet,"
        echo "                   aws, azure, gcloud, terraform, kubectl, docker"
        echo ""
        echo "Examples:"
        echo "  gwt-dev feature/auth               # Worktree + detect devcontainer"
        echo "  gwt-dev feature/auth --exec        # + enter container"
        echo "  gwt-dev feature/new --new --exec   # Create new branch + enter"
        echo "  gwt-dev hotfix/123 --no-devcon     # Worktree only"
        echo "  gwt-dev feat -F python,node -e     # With extra features"
        echo "  gwt-dev feat -m ../repo-main -e    # Mount another worktree for context"
        echo "  gwt-dev feat -m ~/ref -m ~/docs    # Multiple additional mounts"
        echo ""
        echo "The worktree is created at ../repo-branch and the devcontainer"
        echo "instance uses the same name for volume isolation."
        echo ""
        echo "Additional mounts are available at /mounts/<dirname> inside the container."
        return 0
    end

    # Validate branch argument
    if test -z "$branch"
        echo "Error: Branch name required"
        echo "Usage: gwt-dev <branch> [--exec] [--new] [--features ...] [--no-devcon]"
        return 1
    end

    # Get repository name and construct worktree path (resolve to main repo, not worktree)
    # Also serves as git-repo validation (replaces removed guard at top)
    set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)
    or begin
        echo "Error: Not in a git repository"
        return 1
    end
    set -l repo_root (realpath "$git_common_dir/..")
    set -l repo (basename $repo_root)
    set -l worktree_name "$repo-$branch"
    set -l worktree_path "$repo_root/../$worktree_name"

    # Clean up branch name for instance naming (replace / with -)
    set -l instance_name (string replace -a "/" "-" $worktree_name)

    # Check if worktree already exists
    if test -d "$worktree_path"
        echo "Worktree already exists: $worktree_path"
        echo "Switching to existing worktree..."
    else
        # Create worktree
        echo "Creating worktree: $worktree_path"
        if $do_new
            # Create new branch + worktree
            if not git worktree add -b $branch $worktree_path
                echo "Error: Failed to create worktree with new branch"
                return 1
            end
        else
            # Add worktree for existing branch
            if not git worktree add $worktree_path $branch
                echo "Error: Failed to create worktree"
                echo "Tip: Use --new (-n) to create a new branch"
                return 1
            end
        end
    end

    # Cache realpath once for reuse below
    set -l abs_wt (realpath $worktree_path)

    # Trust mise config if present — must run before any early return
    # so worktrees created with --no-devcon (e.g. gwt-ticket) are also trusted
    if command -q mise
        if test -f "$abs_wt/mise.toml"; or test -f "$abs_wt/.mise.toml"
            mise trust "$abs_wt" 2>/dev/null
            echo "   mise trusted: $abs_wt"
        end
    end

    # Skip devcontainer if requested
    if $do_no_devcon
        echo "Worktree created: $worktree_path"
        if not $do_no_cd
            cd $abs_wt
            echo "   Switched to: "(pwd)
        end
        return 0
    end

    # Always use the built-in devcon claude sandbox for isolation.
    # The devcon function uses ~/dotfiles/devcontainer/claude-code-plugins/
    # so the project does NOT need its own .devcontainer/ directory.
    echo "Launching devcontainer sandbox with instance: $instance_name"

    # Allocate port range for this worktree (prevents port conflicts across worktrees)
    set -l port_base ""
    set -l port_allocator "$HOME/dotfiles/scripts/port-allocator.sh"
    if test -x "$port_allocator"
        set port_base (bash "$port_allocator" allocate $instance_name 2>/dev/null)
        if test -n "$port_base"
            echo "   Ports: $port_base-"(math $port_base + 19)" (gwt-ports env $instance_name for details)"
        end
    end

    # Run setup scripts if present
    gwt-setup $worktree_path

    # Build devcon arguments
    set -l devcon_args claude -i $instance_name

    # Add features
    for feature in $features
        set -a devcon_args -F $feature
    end

    # Add flags
    if $do_rebuild
        set -a devcon_args --rebuild
    end
    if $do_fast
        set -a devcon_args --fast
    end
    if $do_exec
        set -a devcon_args --exec
    end

    # Mount the worktree as additional mount (reuse cached realpath)
    set -a devcon_args $abs_wt

    # Add additional mounts
    for mount in $mounts
        set -a devcon_args $mount
    end

    # Launch devcontainer
    echo "Running: devcon $devcon_args"
    devcon $devcon_args

    echo ""
    echo "Worktree + Devcontainer ready:"
    echo "   Worktree: $worktree_path"
    echo "   Instance: $instance_name"
    echo "   Mount:    /mounts/$worktree_name"
    if test (count $mounts) -gt 0
        echo "   Additional mounts:"
        for mount in $mounts
            echo "             /mounts/"(basename $mount)
        end
    end
end
