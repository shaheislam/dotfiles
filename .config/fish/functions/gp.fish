function gp --description "Git push with 1Password SSH"
    SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" git push $argv
end