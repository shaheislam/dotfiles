# SSH Agent Configuration - Local SSH keys only
# This replaces the 1Password SSH agent with local SSH agent

# Reuse one SSH agent across Fish shells instead of spawning a new agent in
# every tmux pane, OpenCode wrapper, or short-lived subshell.
set -l ssh_agent_state_dir "$HOME/.local/state"
set -l ssh_agent_env "$ssh_agent_state_dir/ssh-agent.fish"

function __dotfiles_ssh_agent_alive --description "Return success when current SSH agent env is usable"
    if not set -q SSH_AUTH_SOCK
        return 1
    end

    if not test -S "$SSH_AUTH_SOCK"
        return 1
    end

    if set -q SSH_AGENT_PID
        kill -0 "$SSH_AGENT_PID" 2>/dev/null
        return $status
    end

    return 0
end

if not __dotfiles_ssh_agent_alive
    set -l launchd_sock (launchctl getenv SSH_AUTH_SOCK 2>/dev/null)
    if test -n "$launchd_sock"; and test -S "$launchd_sock"
        set -gx SSH_AUTH_SOCK "$launchd_sock"
        set -e SSH_AGENT_PID
    end
end

if not __dotfiles_ssh_agent_alive
    if test -f "$ssh_agent_env"
        source "$ssh_agent_env" 2>/dev/null
    end
end

if not __dotfiles_ssh_agent_alive
    mkdir -p "$ssh_agent_state_dir"

    set -l agent_output (ssh-agent -c)
    set -l agent_sock
    set -l agent_pid

    for line in $agent_output
        if string match -q 'setenv SSH_AUTH_SOCK *;' -- $line
            set agent_sock (string replace -r '^setenv SSH_AUTH_SOCK ([^;]+);$' '$1' -- $line)
        else if string match -q 'setenv SSH_AGENT_PID *;' -- $line
            set agent_pid (string replace -r '^setenv SSH_AGENT_PID ([^;]+);$' '$1' -- $line)
        end
    end

    if test -n "$agent_sock"; and test -n "$agent_pid"
        set -gx SSH_AUTH_SOCK "$agent_sock"
        set -gx SSH_AGENT_PID "$agent_pid"

        printf 'set -gx SSH_AUTH_SOCK %s\nset -gx SSH_AGENT_PID %s\n' \
            (string escape -- "$SSH_AUTH_SOCK") \
            (string escape -- "$SSH_AGENT_PID") >"$ssh_agent_env"
        chmod 600 "$ssh_agent_env"
    end
end

functions -e __dotfiles_ssh_agent_alive

# Function to add SSH keys with passphrase caching
function ssh-add-keys --description "Add all SSH keys to agent"
    # Add personal GitHub key
    if test -f ~/.ssh/shaheislam-github
        ssh-add ~/.ssh/shaheislam-github 2>/dev/null
    end

    # Add DFE GitHub key
    if test -f ~/.ssh/shaheislamdfe
        ssh-add ~/.ssh/shaheislamdfe 2>/dev/null
    end

    # Add Bitbucket key
    if test -f ~/.ssh/bitbucket
        ssh-add ~/.ssh/bitbucket 2>/dev/null
    end

    # List loaded keys
    ssh-add -l
end

# Function to check SSH agent status
function ssh-agent-status --description "Check SSH agent and loaded keys"
    echo "SSH Agent Status:"
    if set -q SSH_AGENT_PID
        echo "  PID: $SSH_AGENT_PID"
        echo "  Socket: $SSH_AUTH_SOCK"
    else if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"
        echo "  PID: launchd-managed"
        echo "  Socket: $SSH_AUTH_SOCK"
    else
        echo "  Not running"
    end

    echo ""
    echo "Loaded Keys:"
    ssh-add -l 2>/dev/null || echo "  No keys loaded"
end

# Auto-load keys on shell start (optional - comment out if you prefer manual loading)
# ssh-add-keys 2>/dev/null
