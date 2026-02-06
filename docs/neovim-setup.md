# Neovim Setup Guide

Reference documentation for setting up Neovim configuration (extracted from CLAUDE.md for performance).

## Automatic Setup

Using setup script with `NVIM_REPO` environment variable:
```bash
NVIM_REPO=git@github.com:user/neovim.git ./scripts/setup.sh
```
The setup script will automatically:
- Clone the neovim repository to `~/neovim`
- Create the symlink `~/.config/nvim` → `~/neovim`
- Trust the mise configuration (`mise trust ~/neovim/mise.toml`)

## Manual Setup

### 1. Retrieve SSH Keys from 1Password

**Option A - Automated** (if 1Password CLI is configured):
```bash
./scripts/setup/setup-1password-ssh-keys.sh
```

**Option B - Manual**:
```bash
chmod 600 ~/.ssh/shaheislam-github
chmod 644 ~/.ssh/shaheislam-github.pub
ssh-add ~/.ssh/shaheislam-github
```

### 2. Clone Neovim Configuration
```bash
git clone git@github.com:user/neovim.git ~/neovim
ln -sf ~/neovim ~/.config/nvim
```

### 3. Trust mise Configuration
```bash
mise trust ~/neovim/mise.toml
mise install
```

### 4. Bootstrap LazyVim Plugins
```bash
nvim
# Wait for lazy.nvim to clone itself and install all 70 plugins from lazy-lock.json
```

## Common Issues
- **"Permission denied (publickey)"**: SSH key permissions are wrong or key not added to ssh-agent
- **"E492: Not an editor command: Lazy"**: Symlink is incorrect or bootstrap didn't run
- **"mise ERROR: not trusted"**: Run `mise trust ~/neovim/mise.toml`
- **Neovim loads empty config**: Verify symlink with `readlink ~/.config/nvim` (should point to `/Users/[user]/neovim`)
