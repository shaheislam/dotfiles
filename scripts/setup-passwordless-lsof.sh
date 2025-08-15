#!/bin/bash

# Script to configure passwordless sudo for lsof command
# This allows network monitoring functions to work without password prompts

echo "This script will configure passwordless sudo for lsof command."
echo "You'll need to enter your password once to make this change."
echo ""

# Create a sudoers.d file for lsof
SUDOERS_FILE="/etc/sudoers.d/lsof-nopasswd"
LSOF_PATH=$(which lsof)

if [ -z "$LSOF_PATH" ]; then
    echo "Error: lsof not found in PATH"
    exit 1
fi

# Create the sudoers rule
SUDOERS_CONTENT="# Allow passwordless execution of lsof for network monitoring
%admin ALL=(ALL) NOPASSWD: $LSOF_PATH
%wheel ALL=(ALL) NOPASSWD: $LSOF_PATH"

echo "The following rule will be added to sudoers:"
echo "$SUDOERS_CONTENT"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Write the file using sudo tee (safer than direct write)
echo "$SUDOERS_CONTENT" | sudo tee "$SUDOERS_FILE" > /dev/null

# Set proper permissions
sudo chmod 440 "$SUDOERS_FILE"

# Validate the sudoers file
if sudo visudo -c -f "$SUDOERS_FILE"; then
    echo "✅ Sudoers file created successfully!"
    echo "You can now use port monitoring functions without a password."
else
    echo "❌ Error in sudoers file! Removing it for safety."
    sudo rm "$SUDOERS_FILE"
    exit 1
fi