#!/usr/bin/env bash

# Fix tmux-floax plugin initialization issues
# This script patches the floax.tmux file to add missing default variables

FLOAX_PLUGIN_FILE="$HOME/.tmux/plugins/tmux-floax/floax.tmux"

if [ ! -f "$FLOAX_PLUGIN_FILE" ]; then
    echo "❌ Floax plugin not found at: $FLOAX_PLUGIN_FILE"
    echo "Make sure you've installed the plugin with TPM first."
    exit 1
fi

# Check if already patched
if grep -q "DEFAULT_TITLE=" "$FLOAX_PLUGIN_FILE"; then
    echo "✅ Floax plugin already patched"
    exit 0
fi

echo "🔧 Patching Floax plugin..."

# Create backup
cp "$FLOAX_PLUGIN_FILE" "$FLOAX_PLUGIN_FILE.backup"

# Add the missing variables after the source line
sed -i '' '/source "\$CURRENT_DIR\/scripts\/utils.sh"/a\
\
# Set default values\
DEFAULT_TITLE='\''FloaX: C-M-s 󰘕   C-M-b 󰁌   C-M-f 󰊓   C-M-r 󰑓   C-M-e 󱂬   C-M-d '\''\
DEFAULT_SESSION_NAME='\''scratch'\''
' "$FLOAX_PLUGIN_FILE"

echo "✅ Floax plugin patched successfully"
echo "🔄 Reload your tmux config with: tmux source-file ~/.tmux.conf"