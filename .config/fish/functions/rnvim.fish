function rnvim --description "Open file in remote Neovim server"
    if test (count $argv) -eq 0
        echo "Usage: rnvim <file>"
        echo "Opens file in Neovim server listening on /tmp/nvim.socket"
        return 1
    end

    nvim --server /tmp/nvim.socket --remote-tab $argv
end

# Alias for even quicker access
alias rn='rnvim'