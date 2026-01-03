function devnvim --description "Launch Neovim in project devcontainer"
    set -l workspace (pwd)
    set -l cmd $argv[1]

    # Auto-detect remoteUser from devcontainer.json (default: vscode)
    set -l devcontainer_json "$workspace/.devcontainer/devcontainer.json"
    set -l remote_user "vscode"

    if test -f $devcontainer_json
        set -l detected_user (jq -r '.remoteUser // "vscode"' $devcontainer_json 2>/dev/null)
        if test -n "$detected_user" -a "$detected_user" != "null"
            set remote_user $detected_user
        end
    end

    set -l target_home "/home/$remote_user"

    # Mounts for neovim config and plugin persistence
    set -l nvim_mount "type=bind,source=$HOME/neovim,target=$target_home/.config/nvim"
    set -l local_mount "type=bind,source=$HOME/.devcontainer/env/.local,target=$target_home/.local"

    switch "$cmd"
        case up
            echo "Starting devcontainer (user: $remote_user)..."
            devcontainer up --mount "$nvim_mount" --mount "$local_mount" --workspace-folder $workspace
        case exec
            devcontainer exec --workspace-folder $workspace nvim $argv[2..-1]
        case down
            devcontainer down --workspace-folder $workspace
        case '*'
            # Default: up + exec
            echo "Starting devcontainer (user: $remote_user)..."
            devcontainer up --mount "$nvim_mount" --mount "$local_mount" --workspace-folder $workspace
            and devcontainer exec --workspace-folder $workspace nvim $argv
    end
end
