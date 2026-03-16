function gwt-setup --description "Run worktree setup scripts"
    # Usage: gwt-setup [worktree-path]
    #
    # Executes setup scripts for a worktree.
    #
    # Environment variables available in scripts:
    #   $ROOT_WORKTREE_PATH - Path to the main/root worktree
    #
    # Setup script locations (checked in order):
    #   1. .devcontainer/setup.sh
    #   2. scripts/setup-worktree.sh

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
        set -l git_common_dir (git -C $worktree_path rev-parse --git-common-dir 2>/dev/null)
        if test -n "$git_common_dir"
            set root_worktree_path (realpath "$git_common_dir/..")
        end
    end

    # Export for use in setup scripts
    set -gx ROOT_WORKTREE_PATH $root_worktree_path

    set -l setup_ran false

    # Check for .devcontainer/setup.sh
    set -l devcontainer_setup "$worktree_path/.devcontainer/setup.sh"
    if test -f "$devcontainer_setup"
        echo "Running .devcontainer/setup.sh"
        if test -n "$root_worktree_path"
            echo "   ROOT_WORKTREE_PATH=$root_worktree_path"
        end
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
        echo "Running scripts/setup-worktree.sh"
        if test -n "$root_worktree_path"
            echo "   ROOT_WORKTREE_PATH=$root_worktree_path"
        end
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

    # Sync shared agent commands (.agents/commands/ → .claude/commands/, .cursor/commands/, etc.)
    set -l sync_script "$HOME/dotfiles/scripts/sync-agent-commands.sh"
    if test -x "$sync_script"; and test -d "$worktree_path/.agents/commands"
        bash "$sync_script" "$worktree_path" 2>/dev/null
    end

    # Sync MCP config to agent-specific formats (.mcp.json → .cursor/mcp.json, .codex/config.toml, etc.)
    set -l mcp_sync "$HOME/dotfiles/scripts/sync-mcp-config.sh"
    if test -x "$mcp_sync"; and test -f "$worktree_path/.mcp.json"
        bash "$mcp_sync" "$worktree_path" 2>/dev/null
    end

    return 0
end
