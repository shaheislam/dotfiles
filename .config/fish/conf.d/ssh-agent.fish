# SSH Agent Configuration - Local SSH keys only
# This replaces the 1Password SSH agent with local SSH agent

# Start SSH agent if not running
if not set -q SSH_AGENT_PID
    eval (ssh-agent -c) >/dev/null
end

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
    else
        echo "  Not running"
    end
    
    echo ""
    echo "Loaded Keys:"
    ssh-add -l 2>/dev/null || echo "  No keys loaded"
end

# Auto-load keys on shell start (optional - comment out if you prefer manual loading)
# ssh-add-keys 2>/dev/null