#!/bin/bash

# Get the current path from tmux or use PWD
if command -v tmux &> /dev/null && tmux info &> /dev/null 2>&1; then
    target_path=$(tmux display-message -p "#{pane_current_path}")
else
    target_path="$PWD"
fi

cd "$target_path" || exit 1

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get the remote URL
url=$(git remote get-url origin 2>/dev/null)

if [ -z "$url" ]; then
    echo "Error: No remote 'origin' found"
    exit 1
fi

# Convert SSH URLs to HTTPS
# git@github.com:user/repo.git -> https://github.com/user/repo
# git@github.com-personal:user/repo.git -> https://github.com/user/repo
url=$(echo "$url" | sed -E 's/git@github\.com(-[^:]+)?:/https:\/\/github.com\//' | sed 's/\.git$//')

# Open the URL
open "$url" || echo "Error: Failed to open $url"
