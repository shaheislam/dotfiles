function gwt-setup --description "Run worktree setup scripts (Cursor-compatible)"
    # Usage: gwt-setup [worktree-path]
    #
    # Executes setup scripts for a worktree. Supports Cursor-compatible
    # .cursor/worktrees.json format or .devcontainer/setup.sh scripts.
    #
    # Configuration sources (checked in order):
    #   1. .cursor/worktrees.json - Cursor-compatible JSON config
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

    set -l setup_ran false

    # Check for .cursor/worktrees.json (Cursor-compatible)
    set -l cursor_config "$worktree_path/.cursor/worktrees.json"
    if test -f "$cursor_config"
        echo "📋 Found .cursor/worktrees.json"

        # Determine which key to use based on OS
        set -l setup_key "setup-worktree-unix"
        if test (uname) = "Darwin"; or test (uname) = "Linux"
            set setup_key "setup-worktree-unix"
        else
            set setup_key "setup-worktree"
        end

        # Try to extract setup commands using jq
        if command -q jq
            # Check if the key exists and what type it is
            set -l value_type (jq -r ".[\"$setup_key\"] | type" $cursor_config 2>/dev/null)

            if test "$value_type" = "array"
                # Array of commands - execute each
                echo "   Running setup commands..."
                set -l commands (jq -r ".[\"$setup_key\"][]" $cursor_config 2>/dev/null)
                pushd $worktree_path
                for cmd in $commands
                    echo "   → $cmd"
                    eval $cmd
                    if test $status -ne 0
                        echo "   ⚠️  Command failed: $cmd"
                    end
                end
                popd
                set setup_ran true

            else if test "$value_type" = "string"
                # Single script path
                set -l script_path (jq -r ".[\"$setup_key\"]" $cursor_config 2>/dev/null)
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
                        echo "   ⚠️  Script not found: $script_path"
                    end
                end
            end
        else
            echo "   ⚠️  jq not installed - cannot parse .cursor/worktrees.json"
        end
    end

    # Check for .devcontainer/setup.sh
    set -l devcontainer_setup "$worktree_path/.devcontainer/setup.sh"
    if not $setup_ran; and test -f "$devcontainer_setup"
        echo "📋 Found .devcontainer/setup.sh"
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
        echo "📋 Found scripts/setup-worktree.sh"
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
        echo "✅ Setup completed"
    end

    return 0
end
