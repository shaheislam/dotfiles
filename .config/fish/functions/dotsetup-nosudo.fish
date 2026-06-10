function dotsetup-nosudo --description "Run dotfiles setup without sudo (locked-down/managed laptops)"
    "$HOME/dotfiles/scripts/setup.sh" --no-sudo $argv
end
