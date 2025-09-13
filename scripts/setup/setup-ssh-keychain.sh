#!/bin/bash

# Setup SSH keys with macOS Keychain integration
# This allows passphrases to be stored in the macOS keychain

echo "Setting up SSH keys with macOS Keychain integration..."

# Update SSH config to use keychain
SSH_CONFIG="$HOME/.ssh/config"

# Backup existing config
if [ -f "$SSH_CONFIG" ]; then
    cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backed up existing SSH config"
fi

# Add UseKeychain and AddKeysToAgent options to each host
cat > "$HOME/.ssh/config.tmp" << 'EOF'
# macOS Keychain integration for SSH keys
Host *
    UseKeychain yes
    AddKeysToAgent yes

# Personal GitHub account  
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/shaheislam-github
    IdentitiesOnly yes
    PreferredAuthentications publickey

# DFE GitHub account
Host github.com-dfe
    HostName github.com
    User git
    IdentityFile ~/.ssh/shaheislamdfe
    IdentitiesOnly yes
    PreferredAuthentications publickey

# Bitbucket (Home Office)
Host bitbucket.bics-collaboration.homeoffice.gov.uk
    HostName bitbucket.bics-collaboration.homeoffice.gov.uk
    User git
    IdentityFile ~/.ssh/bitbucket
    IdentitiesOnly yes
    PreferredAuthentications publickey

# Default github.com
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/shaheislam-github
    IdentitiesOnly yes
    PreferredAuthentications publickey
EOF

# Move the new config into place
mv "$HOME/.ssh/config.tmp" "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

echo "SSH config updated with keychain integration"

# Add keys to SSH agent with keychain storage
echo ""
echo "Adding SSH keys to agent and keychain..."
echo "You will be prompted for passphrases. They will be saved in macOS keychain."
echo ""

# Add each key with --apple-use-keychain flag
if [ -f "$HOME/.ssh/shaheislam-github" ]; then
    echo "Adding personal GitHub key..."
    ssh-add --apple-use-keychain "$HOME/.ssh/shaheislam-github"
fi

if [ -f "$HOME/.ssh/shaheislamdfe" ]; then
    echo "Adding DFE GitHub key..."
    ssh-add --apple-use-keychain "$HOME/.ssh/shaheislamdfe"
fi

if [ -f "$HOME/.ssh/bitbucket" ]; then
    echo "Adding Bitbucket key..."
    ssh-add --apple-use-keychain "$HOME/.ssh/bitbucket"
fi

echo ""
echo "SSH keys setup complete!"
echo ""
echo "Current loaded keys:"
ssh-add -l

echo ""
echo "To test your connections:"
echo "  ssh -T github.com-personal"
echo "  ssh -T github.com-dfe"
echo ""
echo "Your passphrases are now stored in macOS keychain and will be automatically loaded."