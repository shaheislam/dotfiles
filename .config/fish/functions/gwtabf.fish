function gwtabf --description "Create new branch + worktree in ../repo-branch format"
    # Create branch + worktree in ../repo-name-branch format
    if test -z "$argv[1]"
        echo "Usage: gwtabf <new-branch>"
        return 1
    end
    set branch $argv[1]
    set repo (basename (git rev-parse --show-toplevel))
    set -l worktree_path (git rev-parse --show-toplevel)/../$repo-$branch

    git worktree add -b $branch $worktree_path
    if test $status -ne 0
        return 1
    end

    set -l abs_worktree_path (realpath $worktree_path)

    # Trust mise config if present
    if command -q mise
        if test -f "$abs_worktree_path/mise.toml"; or test -f "$abs_worktree_path/.mise.toml"
            mise trust "$abs_worktree_path" 2>/dev/null
            echo "   mise trusted"
        end
    end

    # Check for devcontainer and prompt
    if test -d "$abs_worktree_path/.devcontainer"; or test -f "$abs_worktree_path/devcontainer.json"
        read -P "Devcontainer detected. Launch? [y/N] " response
        if test "$response" = y; or test "$response" = Y
            set -l instance_name (string replace -a "/" "-" "$repo-$branch")
            devcon claude -i $instance_name $abs_worktree_path -e
        else
            cd $abs_worktree_path
            echo "   Switched to: $abs_worktree_path"
        end
    else
        cd $abs_worktree_path
        echo "   Switched to: $abs_worktree_path"
    end
end
