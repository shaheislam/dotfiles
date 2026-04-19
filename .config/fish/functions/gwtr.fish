function gwtr --description "Remove git worktree with fzf selection (includes devcontainer cleanup)"
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "Not in a git repository"
        return 1
    end

    set -l repo (basename (git rev-parse --show-toplevel))
    set -l repo_root (git rev-parse --show-toplevel)
    set -l selected_list

    # If arguments provided, use them directly (branch names)
    if test (count $argv) -gt 0
        for branch in $argv
            set -l worktree_name "$repo-$branch"
            set -l worktree_path "$repo_root/../$worktree_name"
            if test -d "$worktree_path"
                set -a selected_list (realpath "$worktree_path")
            else
                echo "Worktree not found: $worktree_path"
            end
        end
    else
        # No argument - use fzf selection (multi-select enabled)
        set -l worktrees (git worktree list 2>/dev/null | grep -v '(bare)')

        if test (count $worktrees) -eq 0
            echo "No git worktrees to remove"
            return 1
        end

        # Use string join for fzf input, split output by newlines into array
        set selected_list (string join \n $worktrees | fzf --height=40% --reverse --prompt="Remove worktree(s): " --header="TAB to multi-select, ENTER to confirm" | while read -l line; echo (string split ' ' -- $line)[1]; end)
    end

    if test (count $selected_list) -eq 0
        echo "No worktrees selected"
        return 0
    end

    # Process each selected worktree
    set -l instance_base "$HOME/.devcontainer/instances"
    set -l workspace_base "$HOME/.devcontainer/workspaces"
    set -l has_devcontainers false

    # Check if any have devcontainer instances
    for selected in $selected_list
        set -l worktree_name (basename $selected)
        set -l instance_name (string replace -a "/" "-" $worktree_name)
        if test -d "$instance_base/$instance_name"; or test -d "$workspace_base/$instance_name"
            set has_devcontainers true
            break
        end
    end

    # Prompt once for all devcontainer cleanup
    set -l cleanup_devcontainers false
    if $has_devcontainers
        read -P "Also remove associated devcontainer instances? [y/N] " response
        if test "$response" = y; or test "$response" = Y
            set cleanup_devcontainers true
        end
    end

    # Prompt for branch cleanup (inspired by DHH's gd)
    read -P "Also delete associated local branches? [y/N] " branch_response
    set -l cleanup_branches false
    if test "$branch_response" = y; or test "$branch_response" = Y
        set cleanup_branches true
    end

    # Collect branch names before removing worktrees
    set -l branches_to_delete
    for selected in $selected_list
        # Get branch name from git worktree list
        set -l wt_branch (git worktree list --porcelain 2>/dev/null | grep -A2 "worktree $selected" | grep "^branch " | sed 's|^branch refs/heads/||')
        if test -n "$wt_branch"
            set -a branches_to_delete $wt_branch
        end
    end

    # Remove each worktree
    for selected in $selected_list
        set -l worktree_name (basename $selected)
        set -l instance_name (string replace -a "/" "-" $worktree_name)

        echo "Removing worktree: $selected"
        git worktree remove --force "$selected"

        if $cleanup_devcontainers
            if test -d "$instance_base/$instance_name"; or test -d "$workspace_base/$instance_name"
                # Stop any running container
                if command -q docker
                    docker stop (docker ps -q --filter "name=$instance_name") 2>/dev/null
                end
                rm -rf "$instance_base/$instance_name" 2>/dev/null
                rm -rf "$workspace_base/$instance_name" 2>/dev/null
                echo "   Devcontainer instance removed: $instance_name"
            end
        end
    end

    # Delete branches after worktrees are removed
    set -l deleted_branches
    if $cleanup_branches; and test (count $branches_to_delete) -gt 0
        for branch_name in $branches_to_delete
            # Don't delete main/master/develop
            switch $branch_name
                case main master develop
                    echo "   Skipping protected branch: $branch_name"
                    continue
            end
            git branch -D $branch_name 2>/dev/null
            if test $status -eq 0
                set -a deleted_branches $branch_name
                echo "   Branch deleted: $branch_name"
            else
                echo "   Failed to delete branch: $branch_name"
            end
        end
    end

    echo ""
    echo "Removed "(count $selected_list)" worktree(s)"
    if test (count $deleted_branches) -gt 0
        echo "Deleted "(count $deleted_branches)" branch(es)"
    end
end
