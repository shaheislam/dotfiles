function ssh-test --description "Test current GitHub SSH authentication"
    ssh -T git@github.com 2>&1 | grep "Hi"
end