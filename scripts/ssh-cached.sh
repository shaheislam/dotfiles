#!/bin/bash
# SSH wrapper that caches 1Password agent authorization

# Export SSH_AUTH_SOCK for 1Password if not set
if [ -z "$SSH_AUTH_SOCK" ]; then
    export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi

# Add all keys to agent with a longer timeout
ssh-add -t 12h 2>/dev/null || true

# Execute SSH with original arguments
exec ssh "$@"
