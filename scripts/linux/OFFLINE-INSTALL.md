# Offline Installation Guide for AWS Workspaces

Complete guide for installing dotfiles on air-gapped AWS workspaces without public internet access.

## Overview

This guide covers multiple methods for transferring and installing your dotfiles on AWS workspaces that don't have public internet access.

**What You'll Need:**
- Access to a machine with internet (to create the package)
- A way to transfer files to your AWS workspace
- Basic command line knowledge

## Quick Start

### Step 1: Create Offline Package (On Internet-Connected Machine)

```bash
cd ~/dotfiles/scripts/linux
./package-offline.sh
```

This creates `~/dotfiles-offline.tar.gz` (50-100MB) containing:
- Complete dotfiles repository
- Pre-downloaded binaries (starship, eza, zoxide, bat, ripgrep, fd)
- Offline installer script
- Documentation

### Step 2: Transfer to AWS Workspace

Choose one of the transfer methods below based on your setup.

### Step 3: Install on AWS Workspace

```bash
# Extract the package
tar xzf dotfiles-offline.tar.gz
cd dotfiles-offline

# Run the installer
./install.sh

# Reload shell to use new tools
source ~/.bashrc
```

---

## Transfer Methods

### Method 1: Local Drive Mapping (Recommended)

AWS WorkSpaces can map your local computer's drives, making file transfer easy.

**Setup:**

1. **Enable drive mapping** (if not already enabled):
   - Windows: In WorkSpaces client settings, enable drive redirection
   - Mac: In WorkSpaces client preferences, enable drive redirection

2. **On your local machine:**
   ```bash
   cd ~/dotfiles/scripts/linux
   ./package-offline.sh
   # Creates ~/dotfiles-offline.tar.gz
   ```

3. **Transfer the file:**
   - Windows: Copy to `C:\Users\YourName\Downloads\`
   - Mac: Copy to `~/Downloads/`

4. **On AWS workspace:**
   ```bash
   # Drives typically mounted at /media/ or /mnt/
   # Windows example:
   cp /media/c/Users/YourName/Downloads/dotfiles-offline.tar.gz ~/

   # Mac example:
   cp /media/your-computer-name/Users/YourName/Downloads/dotfiles-offline.tar.gz ~/

   # Extract and install
   tar xzf dotfiles-offline.tar.gz
   cd dotfiles-offline
   ./install.sh
   ```

**Troubleshooting:**
- If drives not visible: Check WorkSpaces client settings
- If permission denied: Ensure drive redirection is enabled
- List available mounts: `ls /media/` or `mount | grep media`

---

### Method 2: Copy/Paste via Clipboard

For smaller files or when drive mapping is unavailable.

**Small Files (< 1MB):**

1. **On your local machine:**
   ```bash
   # Create smaller package with just configs
   cd ~/dotfiles
   tar czf - .config .zshrc .bashrc .tmux.conf | base64 > dotfiles-small.txt
   ```

2. **Copy the text content** of `dotfiles-small.txt`

3. **On AWS workspace:**
   ```bash
   # Paste the content into a file
   cat > dotfiles-small.txt
   # (paste content, then press Ctrl+D)

   # Decode and extract
   base64 -d dotfiles-small.txt | tar xz
   ```

**Large Files (Split Method):**

1. **On your local machine:**
   ```bash
   # Split into 1MB chunks
   split -b 1M ~/dotfiles-offline.tar.gz dotfiles-part-

   # Base64 encode each chunk
   for file in dotfiles-part-*; do
       base64 "$file" > "${file}.txt"
   done
   ```

2. **Transfer each part** via copy/paste

3. **On AWS workspace:**
   ```bash
   # Decode each part
   for file in dotfiles-part-*.txt; do
       base64 -d "$file" > "${file%.txt}"
   done

   # Reassemble
   cat dotfiles-part-* > dotfiles-offline.tar.gz

   # Extract and install
   tar xzf dotfiles-offline.tar.gz
   cd dotfiles-offline
   ./install.sh
   ```

---

### Method 3: S3 Bucket Intermediary

If your workspace can access internal S3 buckets (but not internet).

**Prerequisites:**
- AWS CLI configured on workspace
- Access to an S3 bucket visible from workspace
- Internet-connected machine with AWS access

**Transfer Steps:**

1. **On internet-connected machine:**
   ```bash
   cd ~/dotfiles/scripts/linux
   ./package-offline.sh

   # Upload to S3
   aws s3 cp ~/dotfiles-offline.tar.gz s3://your-internal-bucket/
   ```

2. **On AWS workspace:**
   ```bash
   # Download from S3
   aws s3 cp s3://your-internal-bucket/dotfiles-offline.tar.gz ~/

   # Extract and install
   tar xzf dotfiles-offline.tar.gz
   cd dotfiles-offline
   ./install.sh
   ```

**Alternative: Pre-signed URL** (if internet-connected machine has temporary workspace access):
```bash
# Generate pre-signed URL (valid for 7 days)
aws s3 presign s3://your-internal-bucket/dotfiles-offline.tar.gz --expires-in 604800

# On workspace, download using the URL
curl -o dotfiles-offline.tar.gz "PRESIGNED_URL_HERE"
```

---

### Method 4: SCP/SFTP via Internal Network

If your workspace is accessible via internal network.

**Prerequisites:**
- SSH access to workspace from another internal machine
- Network connectivity between machines
- SCP/SFTP client installed

**Transfer Steps:**

1. **On internet-connected machine:**
   ```bash
   cd ~/dotfiles/scripts/linux
   ./package-offline.sh
   ```

2. **Transfer via SCP:**
   ```bash
   # Direct transfer to workspace
   scp ~/dotfiles-offline.tar.gz your-user@workspace-hostname:~/

   # Or via bastion/jump host
   scp -J bastion-host ~/dotfiles-offline.tar.gz your-user@workspace-hostname:~/
   ```

3. **On AWS workspace:**
   ```bash
   # Extract and install
   tar xzf dotfiles-offline.tar.gz
   cd dotfiles-offline
   ./install.sh
   ```

**Using SFTP:**
```bash
sftp your-user@workspace-hostname
put ~/dotfiles-offline.tar.gz
exit
```

---

### Method 5: USB Drive (If Supported)

Some AWS WorkSpace configurations allow USB devices.

**Transfer Steps:**

1. **Check USB support:**
   ```bash
   # On workspace
   lsusb
   dmesg | grep -i usb
   ```

2. **On local machine:**
   - Copy `dotfiles-offline.tar.gz` to USB drive

3. **On workspace:**
   ```bash
   # Mount USB (may be auto-mounted)
   # Check available devices
   lsblk

   # If not auto-mounted
   sudo mount /dev/sdb1 /mnt/usb

   # Copy from USB
   cp /mnt/usb/dotfiles-offline.tar.gz ~/

   # Extract and install
   tar xzf dotfiles-offline.tar.gz
   cd dotfiles-offline
   ./install.sh
   ```

**Note:** USB support varies by WorkSpace configuration and organizational policies.

---

## Installation Options

### Full Installation

```bash
./install.sh
```

Installs everything: binaries + dotfiles

### Partial Installation

```bash
# Only install dotfiles (skip binaries)
./install.sh --skip-binaries

# Only install binaries (skip dotfiles)
./install.sh --skip-dotfiles

# Preview what would be installed
./install.sh --dry-run
```

### Manual Installation

If the installer doesn't work:

```bash
# Install binaries manually
mkdir -p ~/.local/bin
cp binaries/* ~/.local/bin/
chmod +x ~/.local/bin/*

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install dotfiles manually
cd dotfiles

# If stow is available
stow . --adopt --verbose

# If stow not available
for file in .??*; do
    ln -sf "$(pwd)/$file" ~/
done
```

---

## What Works Offline

### ✅ Works Completely Offline

- Dotfile symlinking (Fish, Zsh, tmux, git, Neovim configs)
- Pre-downloaded binaries (starship, eza, zoxide, bat, ripgrep, fd)
- Shell configuration
- Tmux configuration (plugins need internet for updates)
- Neovim configuration (plugins need internet for installation)

### ⚠️ Requires System Packages

These need to be installed from system repos (may require internal mirrors):

- git, curl, wget
- fish, zsh, bash
- tmux
- neovim
- stow (recommended but optional)
- gcc, make (if building from source)

### ❌ Requires Internet (for full features)

- Fish/Zsh plugin installation (Fisher, Oh My Zsh plugins)
- Tmux plugin installation (TPM plugins)
- Neovim plugin installation (Lazy.nvim plugins)
- LSP server installation
- Node.js/Python/Go/Rust installation (unless from system repos)

---

## Troubleshooting

### Transfer Issues

**Large file size:**
```bash
# Create minimal package (configs only, ~5MB)
cd ~/dotfiles
tar czf dotfiles-minimal.tar.gz .config .zshrc .bashrc .tmux.conf .gitconfig

# Transfer and extract on workspace
tar xzf dotfiles-minimal.tar.gz -C ~/
```

**Permission denied on transfer:**
- Check workspace security policies
- Try alternative transfer method
- Contact IT support for approved transfer methods

**Corrupt transfer:**
```bash
# Verify integrity using checksum
# On local machine:
md5sum dotfiles-offline.tar.gz > checksum.txt

# On workspace:
md5sum dotfiles-offline.tar.gz
# Compare with checksum.txt
```

### Installation Issues

**Stow not found:**
- Installer will use manual symlinking fallback
- Works fine, just different method

**Permission denied during install:**
```bash
# Ensure you own the target directories
ls -la ~/.local
ls -la ~/.config

# Fix permissions if needed
chmod 755 ~/.local ~/.local/bin
```

**Binaries don't work:**
```bash
# Check binary format
file ~/.local/bin/starship

# Should show: x86-64, dynamically linked
# If not, may need different architecture

# Try running directly
~/.local/bin/starship --version
```

**PATH not updated:**
```bash
# Manually add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
echo $PATH | grep .local/bin
```

---

## System-Specific Notes

### Amazon Linux 2/2023

```bash
# Check available packages
sudo yum list available | grep -E 'fish|zsh|tmux|neovim|stow'

# Install from system repos
sudo yum install -y fish zsh tmux stow

# Neovim may need EPEL or build from source
sudo yum install -y epel-release
sudo yum install -y neovim
```

### Ubuntu 20.04/22.04/24.04

```bash
# Check available packages
apt-cache search fish zsh tmux neovim stow

# Install from system repos
sudo apt-get update
sudo apt-get install -y fish zsh tmux neovim stow

# Ubuntu 24.04 has eza in repos
sudo apt-get install -y eza
```

### RHEL/CentOS

```bash
# May need EPEL and PowerTools
sudo dnf install -y epel-release
sudo dnf config-manager --set-enabled powertools

# Install packages
sudo dnf install -y fish zsh tmux neovim stow
```

---

## Advanced: Creating Minimal Packages

### Config-Only Package (Smallest)

```bash
# On local machine - just configs, no binaries (~5MB)
cd ~/dotfiles
tar czf ~/dotfiles-minimal.tar.gz \
    .config \
    .zshrc \
    .bashrc \
    .tmux.conf \
    .gitconfig \
    scripts/linux/install-offline.sh

# Transfer and extract
# On workspace:
tar xzf dotfiles-minimal.tar.gz
./scripts/linux/install-offline.sh --skip-binaries
```

### Custom Binary Selection

Edit `package-offline.sh` to download only specific binaries:

```bash
# Comment out binaries you don't need
# download_eza          # Skip if not needed
# download_bat          # Skip if not needed
download_starship      # Always useful
download_ripgrep       # Very useful
```

---

## Security Considerations

### Verify Package Integrity

```bash
# Create checksum on local machine
sha256sum dotfiles-offline.tar.gz > dotfiles.sha256

# Verify on workspace
sha256sum -c dotfiles.sha256
```

### Scan for Issues

```bash
# Check package contents before extracting
tar tzf dotfiles-offline.tar.gz | less

# Extract to temporary location first
mkdir /tmp/dotfiles-test
tar xzf dotfiles-offline.tar.gz -C /tmp/dotfiles-test

# Review before installing
ls -la /tmp/dotfiles-test/dotfiles-offline/
```

---

## FAQ

**Q: How large is the offline package?**
A: 50-100MB with all binaries, ~5MB for configs only

**Q: Can I use this on other Linux systems?**
A: Yes! Works on any x86-64 Linux system

**Q: Do I need sudo access?**
A: No, everything installs to `~/.local` (user space)

**Q: What if binaries don't work?**
A: They're x86-64 Linux binaries. Check with `file binary-name` and `ldd binary-name`

**Q: Can I update the package later?**
A: Yes, recreate with `./package-offline.sh` and transfer new version

**Q: How do I remove the installation?**
A: Remove `~/.local/bin` binaries and unlink dotfiles with `stow -D`

---

## Getting Help

1. Check this documentation first
2. Review the included README.txt in the package
3. Check workspace system logs: `/var/log/messages` or `dmesg`
4. Contact IT support for transfer method questions

For more information: https://github.com/shaheislam/dotfiles
