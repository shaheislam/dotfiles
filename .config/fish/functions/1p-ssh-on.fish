function 1p-ssh-on --description "Enable 1Password SSH for current shell session"
    set -gx SSH_AUTH_SOCK "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    echo "✅ 1Password SSH enabled for this shell session"
    echo "   You can now use regular git commands with SSH"
    echo "   This will trigger 1Password authentication when needed"
end