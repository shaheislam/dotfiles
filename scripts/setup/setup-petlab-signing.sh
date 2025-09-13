#!/bin/bash

# Script to configure Bitbucket/Petlab repo-specific signing key and author info

PETLAB_SIGNING_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHJML+XnLxiQkwX0c2ZfAyresZQIqHxBS1kKiEFvhWPS"
PETLAB_USER_NAME="Shahe Islam"
PETLAB_USER_EMAIL="shahe.islam@thepetlabco.com"

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Check if remote is Bitbucket/altitudeadsdev
if git remote -v | grep -q "bitbucket.org:altitudeadsdev"; then
    echo "Configuring Petlab/Bitbucket settings for this repository..."
    git config user.signingkey "$PETLAB_SIGNING_KEY"
    git config user.name "$PETLAB_USER_NAME"
    git config user.email "$PETLAB_USER_EMAIL"
    echo "✅ Configured for $(basename $(pwd)):"
    echo "   Name: $PETLAB_USER_NAME"
    echo "   Email: $PETLAB_USER_EMAIL"
    echo "   Signing: Bitbucket SSH key"
else
    echo "This doesn't appear to be a Petlab repository (no bitbucket.org:altitudeadsdev remote found)"
    exit 1
fi