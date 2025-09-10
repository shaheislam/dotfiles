function 1p-ssh-off --description "Disable 1Password SSH for current shell session"
    set -e SSH_AUTH_SOCK
    echo "✅ 1Password SSH disabled for this shell session"
    echo "   Git commands will no longer use 1Password SSH"
end