#!/bin/bash
# Fix 1Password SSH agent permission prompts with tmux-resurrect

echo "=== Fixing 1Password SSH Agent with tmux-resurrect ==="
echo ""

# Solution 1: Configure 1Password to remember authorization longer
echo "Solution 1: Configure 1Password SSH Agent settings"
echo "----------------------------------------"
echo "1. Open 1Password 8 app"
echo "2. Go to Settings → Developer"
echo "3. Under 'SSH Agent' section:"
echo "   - Enable 'Use the SSH agent'"
echo "   - Set 'Ask for approval for' to 'New Connections' (not 'Every Connection')"
echo "   - Enable 'Remember key approval for' and set to '12 hours' or longer"
echo ""

# Solution 2: Use SSH ControlMaster to reduce connections
echo "Solution 2: Enable SSH ControlMaster (reduces connection prompts)"
echo "----------------------------------------"
echo "Adding ControlMaster configuration to SSH config..."

# Check if ControlMaster is already configured
if ! grep -q "ControlMaster" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << 'EOF'

# SSH ControlMaster - Reduces 1Password prompts
Host *
    ControlMaster auto
    ControlPath ~/.ssh/control-%C
    ControlPersist 10m
EOF
    echo "✅ Added ControlMaster configuration to ~/.ssh/config"
else
    echo "ℹ️  ControlMaster already configured in SSH config"
fi

# Create control socket directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "✅ SSH directory permissions set"

# Solution 3: Modify tmux-resurrect to not restore shell commands
echo ""
echo "Solution 3: Configure tmux-resurrect to minimize restores"
echo "----------------------------------------"
echo "Updating tmux configuration..."

# Create improved tmux resurrect config
cat > ~/dotfiles/.tmux-resurrect-1password.conf << 'EOF'
# Tmux Resurrect settings optimized for 1Password SSH Agent

# Don't restore shell history (reduces SSH reconnections)
set -g @resurrect-save-shell-history 'off'

# Don't capture pane contents (faster, less SSH activity)
set -g @resurrect-capture-pane-contents 'off'

# Only restore these programs (not shells)
set -g @resurrect-processes 'vi vim nvim emacs man less more tail top htop'

# Strategy for specific programs
set -g @resurrect-strategy-vim 'session'
set -g @resurrect-strategy-nvim 'session'

# Don't restore these pane commands (add any that trigger SSH)
set -g @resurrect-never-restore 'ssh mosh'
EOF

echo "✅ Created optimized resurrect configuration"
echo ""

# Solution 4: Create wrapper script for SSH connections
echo "Solution 4: Create SSH wrapper with agent caching"
echo "----------------------------------------"

cat > ~/dotfiles/scripts/ssh-cached.sh << 'EOF'
#!/bin/bash
# SSH wrapper that caches 1Password agent authorization

# Export SSH_AUTH_SOCK for 1Password if not set
if [ -z "$SSH_AUTH_SOCK" ]; then
    export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi

# Add all keys to agent with a longer timeout
ssh-add -t 12h 2>/dev/null || true

# Execute SSH with original arguments
exec ssh "$@"
EOF

chmod +x ~/dotfiles/scripts/ssh-cached.sh
echo "✅ Created ssh-cached wrapper script"
echo ""

# Solution 5: Disable automatic restore temporarily
echo "Solution 5: Control when tmux-continuum restores"
echo "----------------------------------------"
cat > ~/dotfiles/scripts/tmux-restore-control.sh << 'EOF'
#!/bin/bash
# Control tmux-continuum automatic restore

case "$1" in
    disable)
        tmux set -g @continuum-restore 'off'
        echo "✅ Automatic restore disabled"
        echo "   Restore manually with: tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
        ;;
    enable)
        tmux set -g @continuum-restore 'on'
        echo "✅ Automatic restore enabled"
        ;;
    status)
        STATUS=$(tmux show -gv @continuum-restore)
        echo "Automatic restore is: $STATUS"
        ;;
    *)
        echo "Usage: $0 {disable|enable|status}"
        echo ""
        echo "Disable automatic restore to prevent 1Password prompts on tmux start"
        echo "Then manually restore when ready to approve all connections at once"
        exit 1
        ;;
esac
EOF

chmod +x ~/dotfiles/scripts/tmux-restore-control.sh
echo "✅ Created restore control script"
echo ""

echo "=== Setup Complete! ==="
echo ""
echo "RECOMMENDED ACTIONS:"
echo "1. Configure 1Password settings (Solution 1) - Most important!"
echo "2. Add this to your .tmux.conf:"
echo "   source-file ~/.tmux-resurrect-1password.conf"
echo ""
echo "3. To disable auto-restore temporarily:"
echo "   ~/dotfiles/scripts/tmux-restore-control.sh disable"
echo ""
echo "4. For SSH connections in tmux, consider using:"
echo "   ~/dotfiles/scripts/ssh-cached.sh instead of ssh"
echo ""
echo "5. Restart tmux for changes to take effect:"
echo "   tmux kill-server && tmux"