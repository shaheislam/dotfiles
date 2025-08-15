#!/bin/bash

# Build tmux-fingers plugin (requires Crystal)
# This script compiles the tmux-fingers plugin which is written in Crystal

FINGERS_DIR="$HOME/.tmux/plugins/tmux-fingers"

if [ ! -d "$FINGERS_DIR" ]; then
    echo "Error: tmux-fingers plugin not found at $FINGERS_DIR"
    echo "Make sure to install tmux plugins first"
    exit 1
fi

if ! command -v crystal &> /dev/null; then
    echo "Error: Crystal programming language not found"
    echo "Install Crystal with: brew install crystal"
    exit 1
fi

echo "Building tmux-fingers plugin..."
cd "$FINGERS_DIR"

# Build the plugin
if make; then
    echo "✓ tmux-fingers built successfully!"
    echo "✓ Plugin is ready to use with prefix + F"
else
    echo "✗ Failed to build tmux-fingers"
    echo "Try running: cd $FINGERS_DIR && make clean && make"
    exit 1
fi
