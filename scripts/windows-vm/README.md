# Windows VM Setup for macOS

Automated Windows 11 ARM VM setup using VMware Fusion for running poker software (PioSolver, PokerTracker 4) with WSL2 integration for terminal-first workflows.

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3)
- At least 16GB RAM (8GB allocated to VM)
- 100GB+ free disk space
- VMware Fusion (installed via Brewfile)

## Quick Start

```bash
# Option 1: Via main setup script
ENABLE_WINDOWS_VM=true ./scripts/setup.sh

# Option 2: Standalone
cd ~/dotfiles/scripts/windows-vm
./setup-vmware.sh
./download-windows-iso.sh  # or download manually
./create-vm.sh
```

## Files

| File | Purpose |
|------|---------|
| `setup-vmware.sh` | Installs VMware Fusion and creates directory structure |
| `download-windows-iso.sh` | Downloads Windows 11 ARM via UUPDump |
| `create-vm.sh` | Creates and configures the VM |
| `vm-template.vmx` | VM hardware configuration template |

## Windows License Options

1. **Unactivated** (Recommended for poker tools)
   - Free, fully functional
   - "Activate Windows" watermark only
   - Cannot personalize (wallpaper, colors)

2. **Windows Insider Program** (Free)
   - Join at https://insider.windows.com
   - Download ARM builds directly

3. **Purchase License** (~$139)
   - Full activation, no watermark

## Post-Installation

After Windows is installed:

```powershell
# In Windows PowerShell (Admin)
powershell -ExecutionPolicy Bypass -File C:\Users\<user>\dotfiles\scripts\windows\setup.ps1 -InstallWSL -ConfigureTerminal
```

This will:
1. Install Scoop package manager
2. Install WSL2 with Ubuntu
3. Configure Windows Terminal with Tokyo Night theme

## WSL2 Dotfiles Setup

After WSL2 is installed:

```bash
# In WSL2 Ubuntu terminal
cd ~
git clone <your-dotfiles-repo> dotfiles
cd dotfiles
./scripts/setup.sh
```

## Shared Folders

The VM is configured to share folders between macOS and Windows:

| macOS | Windows | Purpose |
|-------|---------|---------|
| `~/Documents/PokerData` | `Z:\PokerData` | Hand histories, solver outputs |
| `~/Documents/Obsidian` | `Z:\Obsidian` | Note-taking vault |

## Performance Notes

- PioSolver runs at ~70-80% native speed due to x86 emulation
- PokerTracker 4 runs at ~90-95% native speed
- For intensive solver work, consider running overnight
- Alternative: Parallels Desktop ($99/year) offers ~10-15% better performance

## Troubleshooting

### VM won't start
```bash
# Check VMware services
vmrun list
# Restart VMware
killall -9 vmware-vmx
```

### Windows ARM ISO issues
```bash
# Re-download ISO
rm ~/VMs/ISOs/Win11_ARM64.iso
./download-windows-iso.sh
```

### Performance issues
- Increase CPU cores in VM settings (6-8 recommended)
- Increase RAM allocation (8GB minimum)
- Disable Windows visual effects
- Set power plan to "High Performance"
