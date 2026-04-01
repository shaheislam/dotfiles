#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 ARM Setup Script for Dotfiles Parity

.DESCRIPTION
    Bootstraps a Windows environment with:
    - Scoop package manager
    - WSL2 with Ubuntu
    - Windows Terminal with Tokyo Night theme
    - Claude Code CLI prerequisites

.PARAMETER InstallWSL
    Install WSL2 with Ubuntu

.PARAMETER ConfigureTerminal
    Configure Windows Terminal with Tokyo Night theme

.PARAMETER InstallPokerTools
    Open browser to download poker software

.PARAMETER All
    Run all setup phases

.EXAMPLE
    .\setup.ps1 -All
    .\setup.ps1 -InstallWSL -ConfigureTerminal
#>

param(
    [switch]$InstallWSL,
    [switch]$ConfigureTerminal,
    [switch]$InstallPokerTools,
    [switch]$All
)

# Colors for output
function Write-Header {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[X] $Message" -ForegroundColor Red
}

# ============================================
# Phase W1: Package Managers
# ============================================
function Install-PackageManagers {
    Write-Header "Installing Package Managers"

    # Check if Scoop is installed
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Success "Scoop is already installed"
    } else {
        Write-Host "Installing Scoop..."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        Write-Success "Scoop installed"
    }

    # Add Scoop buckets
    Write-Host "Adding Scoop buckets..."
    scoop bucket add extras 2>$null
    scoop bucket add nerd-fonts 2>$null
    scoop bucket add versions 2>$null

    # Install essential tools via Scoop
    Write-Host "Installing essential tools..."
    scoop install git 2>$null
    scoop install 7zip 2>$null

    Write-Success "Package managers configured"
}

# ============================================
# Phase W2: WSL2 Installation
# ============================================
function Install-WSL2 {
    Write-Header "Installing WSL2"

    # Check if WSL is already installed
    $wslStatus = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "WSL is already installed"

        # List installed distributions
        Write-Host "Installed distributions:"
        wsl --list --verbose
    } else {
        Write-Host "Installing WSL2 with Ubuntu..."

        # Install WSL with Ubuntu
        wsl --install -d Ubuntu

        Write-Warning "A restart may be required to complete WSL installation"
        Write-Host "After restart, run 'wsl' to complete Ubuntu setup"
    }

    # Ensure WSL2 is the default version
    wsl --set-default-version 2 2>$null

    Write-Success "WSL2 configured"
}

# ============================================
# Phase W3: Windows Terminal Configuration
# ============================================
function Install-WindowsTerminal {
    Write-Header "Configuring Windows Terminal"

    # Install Windows Terminal if not present
    $wtPackage = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
    if (-not $wtPackage) {
        Write-Host "Installing Windows Terminal via winget..."
        winget install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements
    } else {
        Write-Success "Windows Terminal is already installed"
    }

    # Install Nerd Font
    Write-Host "Installing JetBrainsMono Nerd Font..."
    scoop install JetBrainsMono-NF 2>$null

    # Copy settings
    $settingsSource = Join-Path $PSScriptRoot "windows-terminal\settings.json"
    $settingsTarget = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (Test-Path $settingsSource) {
        # Backup existing settings
        if (Test-Path $settingsTarget) {
            $backupPath = "$settingsTarget.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item $settingsTarget $backupPath
            Write-Host "Backed up existing settings to: $backupPath"
        }

        # Copy new settings
        Copy-Item $settingsSource $settingsTarget -Force
        Write-Success "Windows Terminal configured with Tokyo Night theme"
    } else {
        Write-Warning "Settings file not found: $settingsSource"
        Write-Host "Manually copy windows-terminal/settings.json to:"
        Write-Host "  $settingsTarget"
    }
}

# ============================================
# Phase W4: Poker Software
# ============================================
function Install-PokerTools {
    Write-Header "Poker Software Installation"

    Write-Host @"

The following poker software needs to be installed manually:

1. PioSolver
   Download: https://piosolver.com/download
   - Download PioSOLVER 2 Edge (recommended for ARM compatibility)
   - Install to default location

2. PokerTracker 4
   Download: https://pokertracker.com/download
   - Download PokerTracker 4
   - Install with bundled PostgreSQL

Opening download pages in browser...
"@

    Start-Process "https://piosolver.com"
    Start-Process "https://pokertracker.com"

    Write-Success "Poker software download pages opened"
}

# ============================================
# Phase W5: WSL Dotfiles Setup Guide
# ============================================
function Show-WSLSetupGuide {
    Write-Header "WSL Dotfiles Setup Guide"

    Write-Host @"

After WSL Ubuntu is installed, run these commands in WSL terminal:

1. Update system:
   sudo apt update && sudo apt upgrade -y

2. Install prerequisites:
   sudo apt install -y git curl build-essential

3. Clone dotfiles:
   cd ~
   git clone <your-dotfiles-repo> dotfiles

4. Run setup:
   cd dotfiles
   ./scripts/setup.sh

5. Set Fish as default shell:
   chsh -s /usr/bin/fish

6. Create symlinks to Windows folders:
   ln -s /mnt/c/Users/$env:USERNAME/Documents/Obsidian ~/obsidian
   ln -s /mnt/c/Users/$env:USERNAME/Documents/PokerData ~/poker-data

7. Install Claude Code CLI:
   claude install

Your terminal-first workflow will then be ready!
"@
}

# ============================================
# Main
# ============================================
function Main {
    Write-Host @"
==========================================
  Windows 11 ARM Setup for Dotfiles
==========================================
"@

    # If -All is specified, run everything
    if ($All) {
        $InstallWSL = $true
        $ConfigureTerminal = $true
        $InstallPokerTools = $true
    }

    # Phase W1: Package Managers (always run)
    Install-PackageManagers

    # Phase W2: WSL2
    if ($InstallWSL) {
        Install-WSL2
    }

    # Phase W3: Windows Terminal
    if ($ConfigureTerminal) {
        Install-WindowsTerminal
    }

    # Phase W4: Poker Software
    if ($InstallPokerTools) {
        Install-PokerTools
    }

    # Always show WSL setup guide
    Show-WSLSetupGuide

    Write-Host "`n"
    Write-Success "Windows setup complete!"
    Write-Host @"

Next steps:
1. Restart if prompted for WSL
2. Open Windows Terminal
3. Run 'wsl' to set up Ubuntu
4. Follow the WSL Dotfiles Setup Guide above
"@
}

# Run main
Main
