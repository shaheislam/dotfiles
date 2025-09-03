# 1Password SSH Integration Setup Guide

This guide explains how to set up 1Password SSH agent integration to replace manual SSH key switching and provide better security for your SSH keys.

## Overview

The 1Password SSH integration allows you to:
- Store SSH keys securely in your 1Password vault
- Use biometric authentication (Touch ID) for SSH key access
- Automatically select the correct SSH key based on repository/host
- Sync SSH keys across all your devices
- Never expose private keys on your filesystem

## Prerequisites

1. **1Password app installed** (already at `/Applications/1Password.app`)
2. **1Password CLI installed** (now installed via `brew install --cask 1password-cli`)
3. **Existing SSH keys** to import into 1Password

## Setup Steps

### Step 1: Enable 1Password SSH Agent

1. Open 1Password app
2. Go to **Preferences** → **Developer**
3. Enable **"Use the SSH agent"**
4. Enable **"Display key names when authorizing connections"** (recommended)

### Step 2: Import Your SSH Keys to 1Password

1. In 1Password, create a new item using **SSH Key** type
2. For each key you want to import:
   - **Personal GitHub**: Import `~/.ssh/shaheislam-github`
   - **DFE GitHub**: Import or create `~/.ssh/shaheislamdfe` 
   - **Bitbucket PetLab**: Import `~/.ssh/bitbucket`
3. Name them clearly (e.g., "GitHub Personal", "GitHub DFE", "Bitbucket PetLab")
4. Store in appropriate vaults (Personal or Work)

### Step 3: Export Public Keys

After importing keys to 1Password:
1. For each SSH key in 1Password, click **"Save public key"**
2. Save to `~/.ssh/` with the same filename + `.pub`
   - `~/.ssh/shaheislam-github.pub`
   - `~/.ssh/shaheislamdfe.pub`
   - `~/.ssh/bitbucket.pub`

### Step 4: Configure 1Password SSH Agent

Create the configuration directory:
```bash
mkdir -p ~/.config/1Password/ssh/
```

Copy the agent configuration:
```bash
cp ~/dotfiles/examples/1password-ssh/agent.toml ~/.config/1Password/ssh/agent.toml
```

Edit the file to match your key names and vault names in 1Password.

### Step 5: Update SSH Config

Backup your current SSH config:
```bash
cp ~/.ssh/config ~/.ssh/config.backup
```

Replace with 1Password-compatible config:
```bash
cp ~/dotfiles/examples/1password-ssh/ssh-config ~/.ssh/config
```

### Step 6: Configure Git Directory-Based Identity

This setup allows automatic identity switching based on project directory.

#### Create directory structure:
```bash
mkdir -p ~/src/personal
mkdir -p ~/src/dfe
mkdir -p ~/src/petlab
```

#### Copy git configs to appropriate directories:
```bash
cp ~/dotfiles/examples/1password-ssh/personal-gitconfig ~/src/personal/.gitconfig
cp ~/dotfiles/examples/1password-ssh/dfe-gitconfig ~/src/dfe/.gitconfig
```

#### Update email addresses in the copied files:
- Edit `~/src/personal/.gitconfig` and set your personal email
- Edit `~/src/dfe/.gitconfig` and set your DFE work email

#### Add includeIf to your main git config:
```bash
cat ~/dotfiles/examples/1password-ssh/main-gitconfig-additions >> ~/.gitconfig
```

### Step 7: Configure Fish Shell

Add 1Password SSH agent socket to Fish config:
```fish
# Add to ~/.config/fish/config.fish
set -x SSH_AUTH_SOCK ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

## Usage

### Cloning Repositories

With the new setup, you don't need to switch SSH keys manually:

#### Personal repositories:
```bash
cd ~/src/personal
git clone git@github.com:shaheislam/your-repo.git
# Automatically uses personal SSH key and git identity
```

#### DFE repositories:
```bash
cd ~/src/dfe
git clone git@github.com:DFE-Digital/some-repo.git
# Automatically uses DFE SSH key and git identity
```

#### Bitbucket repositories:
```bash
cd ~/src/petlab
git clone git@bitbucket.org:petlab/some-repo.git
# Uses Bitbucket SSH key
```

### Existing Repositories

For existing repositories cloned with the old setup, update the remote URLs:

#### For personal repos:
```bash
cd ~/path/to/personal/repo
git remote set-url origin git@github.com-personal:shaheislam/repo-name.git
```

#### For DFE repos:
```bash
cd ~/path/to/dfe/repo
git remote set-url origin git@github.com-dfe:DFE-Digital/repo-name.git
```

## Migration from ssh-switch Function

### Migration Complete

The `ssh-switch` function has been removed from the dotfiles as 1Password SSH agent now handles all SSH key management automatically. The following changes have been made:

1. **Removed functions:**
   - `ssh-switch` - No longer needed as 1Password handles key selection
   - `ssh-auto` - Automatic switching now handled by 1Password

2. **Updated functions:**
   - `git-check-identity` - Now shows Git configuration instead of SSH keys
   - `git-smart` - Checks Git config (user.email) instead of SSH keys
   - `fish-help` - Updated to reflect 1Password SSH usage

### Quick Test

Test the setup with a simple SSH connection:
```bash
# Test personal GitHub
ssh -T git@github.com-personal

# Test DFE GitHub  
ssh -T git@github.com-dfe

# Test Bitbucket
ssh -T git@bitbucket.org
```

You should see Touch ID prompt (or password prompt) from 1Password when connecting.

## Advantages of 1Password SSH

| Feature | Old Method (ssh-switch) | 1Password SSH |
|---------|------------------------|---------------|
| Manual switching | Required | Automatic |
| Key storage | Filesystem | Encrypted vault |
| Authentication | None | Touch ID/Password |
| Cross-device sync | No | Yes |
| Private key exposure | On disk | Never exposed |
| Repository awareness | Warns after switch | Automatic selection |
| Security | Keys on disk | Keys in secure enclave |

## Troubleshooting

### SSH agent not working
1. Ensure 1Password SSH agent is enabled in app preferences
2. Check socket exists: `ls -la ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock`
3. Restart 1Password app

### Wrong SSH key being used
1. Check `~/.config/1Password/ssh/agent.toml` order
2. Verify SSH config host matching
3. Use `ssh -vvv` to debug which key is being offered

### Git using wrong identity
1. Verify you're in the correct directory structure
2. Check git config: `git config user.email`
3. Ensure includeIf paths match your directory structure

### Touch ID not prompting
1. Check 1Password preferences for SSH agent settings
2. Ensure key authorization is required in 1Password
3. Try locking and unlocking 1Password

## Security Benefits

1. **Private keys never on disk** - Keys stay encrypted in 1Password
2. **Biometric authentication** - Touch ID required for each use
3. **Audit trail** - 1Password logs all key usage
4. **Automatic locking** - Keys unavailable when 1Password locks
5. **Secure sync** - End-to-end encrypted sync across devices

## Additional Resources

- [1Password SSH Documentation](https://developer.1password.com/docs/ssh/)
- [1Password SSH Agent Config](https://developer.1password.com/docs/ssh/agent/config/)
- [Git SSH with 1Password](https://developer.1password.com/docs/ssh/git-commit-signing/)

## Notes

- The DFE SSH key (`shaheislamdfe`) appears to be missing from your system. You'll need to create it or recover it before importing to 1Password.
- Consider organizing your repositories into the suggested directory structure for automatic identity switching.
- The ssh-switch function can be kept as a fallback during the migration period.