function git-with-1p --description "Run git commands with 1Password SSH agent"
    # Temporarily set SSH_AUTH_SOCK for this git command only
    SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" git $argv
end