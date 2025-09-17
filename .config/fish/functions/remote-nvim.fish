# Remote Neovim SSHFS functions for Fish shell

# Main remote-nvim function that wraps the script
function remote-nvim --description "Remote Neovim SSHFS workflow helper"
    ~/dotfiles/scripts/remote-nvim.sh $argv
end

# Short aliases for remote-nvim
function rnvim --description "Alias for remote-nvim"
    remote-nvim $argv
end

function rn --description "Short alias for remote-nvim"
    remote-nvim $argv
end

# Start Neovim server
function rnvim-start --description "Start Neovim server with socket"
    remote-nvim start
end

# Connect to remote host
function rnvim-connect --description "Connect to remote host via SSHFS"
    if test (count $argv) -eq 0
        echo "Usage: rnvim-connect <host>"
        return 1
    end
    remote-nvim connect $argv[1]
end

# Open file in remote Neovim
function rnvim-open --description "Open file/directory in remote Neovim"
    if test (count $argv) -eq 0
        echo "Usage: rnvim-open <path>"
        return 1
    end
    remote-nvim open $argv[1]
end

# Disconnect from remote
function rnvim-disconnect --description "Disconnect from remote host(s)"
    remote-nvim disconnect $argv
end

# Show status
function rnvim-status --description "Show remote Neovim connection status"
    remote-nvim status
end

# SSH with Neovim socket forwarding
function ssh-nvim --description "SSH with automatic Neovim socket forwarding"
    ~/dotfiles/scripts/ssh-with-nvim.sh $argv
end

# Auto-mount SSH
function ssh-mount --description "SSH with auto-mount SSHFS"
    ~/dotfiles/scripts/ssh-with-nvim.sh --auto-mount $argv
end

# Quick workflow function
function remote-edit --description "Quick remote editing workflow"
    set -l host $argv[1]
    set -l path $argv[2]

    if test (count $argv) -lt 1
        echo "Usage: remote-edit <host> [path]"
        echo "Example: remote-edit myserver projects/myapp"
        return 1
    end

    # Ensure Neovim server is running
    if not remote-nvim status | grep -q "running"
        echo "Starting Neovim server..."
        remote-nvim start
    end

    # SSH with socket forwarding
    echo "Connecting to $host..."
    ssh -R /tmp/nvim.socket:/tmp/nvim.socket $host -t "
        echo 'Mounting SSHFS...';
        nvim --server /tmp/nvim.socket --remote-send ':RemoteSSHFSConnect $host<CR>' 2>/dev/null;
        if test -n '$path'; then
            echo 'Opening $path...';
            nvim --server /tmp/nvim.socket --remote-tab '$path' 2>/dev/null;
        fi;
        exec \$SHELL
    "
end

# Completions for remote-nvim commands
complete -c remote-nvim -f
complete -c remote-nvim -n "__fish_use_subcommand" -a "start" -d "Start Neovim server"
complete -c remote-nvim -n "__fish_use_subcommand" -a "connect" -d "Connect to remote host"
complete -c remote-nvim -n "__fish_use_subcommand" -a "open" -d "Open file/directory"
complete -c remote-nvim -n "__fish_use_subcommand" -a "disconnect" -d "Disconnect from host"
complete -c remote-nvim -n "__fish_use_subcommand" -a "status" -d "Show connection status"
complete -c remote-nvim -n "__fish_use_subcommand" -a "cleanup" -d "Clean up resources"

# Complete hosts for connect command
complete -c remote-nvim -n "__fish_seen_subcommand_from connect" -a "(__fish_complete_ssh_hosts)"
complete -c rnvim-connect -a "(__fish_complete_ssh_hosts)"
complete -c ssh-nvim -a "(__fish_complete_ssh_hosts)"
complete -c ssh-mount -a "(__fish_complete_ssh_hosts)"
complete -c remote-edit -a "(__fish_complete_ssh_hosts)"

# Helper function to complete SSH hosts
function __fish_complete_ssh_hosts --description "Complete SSH hosts from config"
    # Parse ~/.ssh/config for host entries
    if test -f ~/.ssh/config
        grep -E "^Host " ~/.ssh/config | cut -d' ' -f2 | grep -v "\*"
    end
end