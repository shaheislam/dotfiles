function dotsetup-fast --description "Run dotfiles setup without package/font/app updates"
    "$HOME/dotfiles/scripts/setup.sh" --skip-packages --skip-fonts-apps $argv
end
