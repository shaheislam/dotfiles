#!/bin/bash

# Fix tmux-continuum debug output issue
# This script comments out the debug line that causes CLI output issues

CONTINUUM_FILE="$HOME/.tmux/plugins/tmux-continuum/continuum.tmux"

if [ -f "$CONTINUUM_FILE" ]; then
    echo "Fixing tmux-continuum debug output..."

    # Check if the set -x line exists and is not commented
    if grep -q "^set -x" "$CONTINUUM_FILE"; then
        # Comment out the debug line
        sed -i '' 's/^set -x/# set -x/' "$CONTINUUM_FILE"
        echo "✓ Fixed tmux-continuum debug output in $CONTINUUM_FILE"
    else
        echo "✓ tmux-continuum debug line already fixed or not found"
    fi
else
    echo "Warning: tmux-continuum plugin not found at $CONTINUUM_FILE"
    echo "Make sure tmux plugins are installed first"
fi
