# Legacy distant.nvim with AWS SSM

## Overview
This is a legacy optional workflow for editing EC2 files through AWS SSM Session Manager with distant.nvim. The current `~/neovim` configuration no longer enables distant.nvim by default, so this document is retained as recovery/reference material rather than an active health requirement.

## Prerequisites
1. AWS CLI configured with appropriate credentials
2. Session Manager Plugin installed
3. distant.nvim plugin re-enabled in `~/neovim`
4. SSH keys distributed to EC2 instances

## Legacy Setup Notes

### 1. SSH Key Distribution
- Generated SSH key pair: `~/.ssh/shahe-distant-nvim`
- Distributed public key to all EC2 instances via SSM
- Script: `~/dotfiles/scripts/setup/setup-ec2-ssh-keys.sh`

### 2. distant.nvim Configuration
- Legacy plugin location: `~/.config/nvim/lua/plugins/distant.lua`
- Legacy binary path: `~/.local/share/nvim/distant/distant.bin`
- Current default: plugin absent from `~/neovim`; re-enable it there before relying on these commands.

### 3. SSM Tunnel Script
- Created helper script: `~/dotfiles/scripts/aws/distant-ssm-tunnel.sh`
- Creates port forwarding through SSM (port 2222 by default)

## Usage When Re-Enabled

### Step 1: Start the SSM Tunnel
```bash
# Interactive instance selection
~/dotfiles/scripts/aws/distant-ssm-tunnel.sh

# Or specify instance and profile
~/dotfiles/scripts/aws/distant-ssm-tunnel.sh i-xxxxx labs
```

Keep this terminal open or run in tmux/screen.

### Step 2: Connect in Neovim
```vim
:DistantConnect ssh://ubuntu@localhost:2222
```

### Step 3: Browse Remote Files
```vim
:DistantOpen /home/ubuntu/
```

## Key Commands
- `<leader>dc` - Connect to remote server
- `<leader>do` - Open remote file/directory
- `<leader>ds` - Open remote shell
- `<leader>dS` - Search remote files
- `<leader>di` - Show session info

## Files Created
- `~/dotfiles/scripts/setup/setup-ec2-ssh-keys.sh` - SSH key distribution script
- `~/dotfiles/scripts/aws/distant-ssm-tunnel.sh` - SSM tunnel helper
- `~/.ssh/shahe-distant-nvim` - SSH key pair for distant.nvim
- `~/.ssh/config.d/ec2-instances.conf` - SSH config for EC2 instances

## How It Works
1. SSM creates a port forwarding tunnel from localhost:2222 to EC2:22
2. distant.nvim connects via SSH to localhost:2222
3. SSH authentication uses the distributed keys
4. Files are edited through the distant protocol over SSH

## Troubleshooting
- Ensure AWS credentials are valid (`aws sts get-caller-identity`)
- Check instance has SSM agent running
- Verify SSH key is on the instance
- Try different users (ubuntu, ec2-user, admin)
- Run `ENABLE_DISTANT_LEGACY_TEST=true scripts/test-distant.sh` only after re-enabling the Neovim plugin and binary.
