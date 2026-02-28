function brew-update --description "Update Homebrew and upgrade all packages"
    echo "Updating Homebrew..."
    brew update
    and echo ""
    and echo "Upgrading packages..."
    and brew upgrade
    and echo ""
    and echo "Cleaning up..."
    and brew cleanup --prune=30
    and echo ""
    and echo "Checking for issues..."
    and brew doctor 2>/dev/null
    or true
end
