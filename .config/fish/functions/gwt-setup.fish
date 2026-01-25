function gwt-setup --description "Run worktree setup scripts"
    # Usage: gwt-setup [worktree-path]
    #
    # Executes setup scripts for a worktree.
    #
    # Environment variables available in scripts:
    #   $ROOT_WORKTREE_PATH - Path to the main/root worktree
    #
    # Configuration sources (checked in order):
    #   1. .worktree.json - JSON config with setup commands
    #   2. .devcontainer/setup.sh - Shell script
    #   3. scripts/setup-worktree.sh - Common location

    set -l worktree_path $argv[1]
    if test -z "$worktree_path"
        set worktree_path (pwd)
    end

    # Normalize path
    set worktree_path (realpath $worktree_path 2>/dev/null; or echo $worktree_path)

    if not test -d "$worktree_path"
        echo "Error: Directory not found: $worktree_path"
        return 1
    end

    # Detect the root/main worktree path
    # The main worktree has .git as a directory, linked worktrees have .git as a file
    set -l root_worktree_path ""
    if test -d "$worktree_path/.git"
        # This IS the main worktree
        set root_worktree_path $worktree_path
    else if test -f "$worktree_path/.git"
        # This is a linked worktree - find the main one
        # .git file contains: "gitdir: /path/to/main/.git/worktrees/branch-name"
        set -l git_common_dir (git -C $worktree_path rev-parse --git-common-dir 2>/dev/null)
        if test -n "$git_common_dir"
            # git-common-dir is the main .git directory, parent is the main worktree
            set root_worktree_path (realpath "$git_common_dir/..")
        end
    end

    # Export for use in setup scripts
    set -gx ROOT_WORKTREE_PATH $root_worktree_path

    set -l setup_ran false

    # Check for .worktree.json
    set -l worktree_config "$worktree_path/.worktree.json"
    if test -f "$worktree_config"
        echo "Found .worktree.json"
        if test -n "$root_worktree_path"
            echo "   ROOT_WORKTREE_PATH=$root_worktree_path"
        end

        # Determine which key to use based on OS
        set -l setup_key "setup-unix"
        if test (uname) = "Darwin"; or test (uname) = "Linux"
            set setup_key "setup-unix"
        else
            set setup_key "setup"
        end

        # Try to extract setup commands using jq
        if command -q jq
            # Check if the key exists and what type it is
            set -l value_type (jq -r ".[\"$setup_key\"] | type" $worktree_config 2>/dev/null)

            if test "$value_type" = "array"
                # Array of commands - execute each
                echo "   Running setup commands..."
                set -l commands (jq -r ".[\"$setup_key\"][]" $worktree_config 2>/dev/null)
                pushd $worktree_path
                for cmd in $commands
                    echo "   > $cmd"
                    eval $cmd
                    if test $status -ne 0
                        echo "   Command failed: $cmd"
                    end
                end
                popd
                set setup_ran true

            else if test "$value_type" = "string"
                # Single script path
                set -l script_path (jq -r ".[\"$setup_key\"]" $worktree_config 2>/dev/null)
                if test -n "$script_path"; and test "$script_path" != "null"
                    set -l full_script_path "$worktree_path/$script_path"
                    if test -f "$full_script_path"
                        echo "   Running: $script_path"
                        pushd $worktree_path
                        if test -x "$full_script_path"
                            $full_script_path
                        else
                            sh $full_script_path
                        end
                        popd
                        set setup_ran true
                    else
                        echo "   Script not found: $script_path"
                    end
                end
            end
        else
            echo "   jq not installed - cannot parse .worktree.json"
        end
    end

    # Check for .devcontainer/setup.sh
    set -l devcontainer_setup "$worktree_path/.devcontainer/setup.sh"
    if not $setup_ran; and test -f "$devcontainer_setup"
        echo "Found .devcontainer/setup.sh"
        pushd $worktree_path
        if test -x "$devcontainer_setup"
            $devcontainer_setup
        else
            sh $devcontainer_setup
        end
        popd
        set setup_ran true
    end

    # Check for scripts/setup-worktree.sh
    set -l scripts_setup "$worktree_path/scripts/setup-worktree.sh"
    if not $setup_ran; and test -f "$scripts_setup"
        echo "Found scripts/setup-worktree.sh"
        pushd $worktree_path
        if test -x "$scripts_setup"
            $scripts_setup
        else
            sh $scripts_setup
        end
        popd
        set setup_ran true
    end

    if $setup_ran
        echo "Setup completed"
    end

    return 0
end
