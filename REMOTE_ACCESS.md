# Remote Terminal Access: Termux + Tailscale + Mosh + tmux

## Goal
Enable remote terminal access from phone (Termux) to laptop with:
- Mirrored display on both devices
- Resilient connection that survives network switches (WiFi ↔ cellular)
- Secure access via Tailscale private network

## Architecture Overview

```
┌─────────────────┐         ┌─────────────────┐
│   Phone         │         │   Laptop        │
│   (Termux)      │         │   (macOS)       │
│                 │         │                 │
│  mosh client ───┼── Tailscale VPN ──┼→ mosh-server  │
│                 │         │      │          │
│  tmux attach ◄──┼─────────┼──────┼→ tmux session   │
│                 │         │                 │
│  ◄── mirrored output ───► │                 │
└─────────────────┘         └─────────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| **Tailscale** | Secure mesh VPN - gives laptop stable IP accessible from anywhere |
| **Mosh** | Mobile shell - handles network roaming, reconnects automatically |
| **tmux** | Session multiplexer - shared session visible on both devices |

## Implementation Plan

### Phase 1: Install Dependencies on Laptop

**1.1 Add to Brewfile** (`~/dotfiles/homebrew/Brewfile`):
```ruby
# Remote Access
brew "mosh"
cask "tailscale"
```

**1.2 Update setup.sh** to enable SSH server and configure Tailscale

### Phase 2: Configure macOS

**2.1 Enable SSH Server (Remote Login)**
- System Settings → General → Sharing → Remote Login → Enable
- This enables the built-in sshd

**2.2 Configure Tailscale**
- Install and authenticate with Tailscale account
- Enable MagicDNS for easy hostname access
- Note your Tailscale IP (e.g., `100.x.y.z`) or hostname (e.g., `laptop.tailnet-name.ts.net`)

**2.3 Mosh firewall rules**
- Mosh uses UDP ports 60000-61000
- May need to allow in macOS firewall

### Phase 3: Configure Phone (Termux)

**3.1 Install packages in Termux**:
```bash
pkg update && pkg upgrade
pkg install mosh tmux openssh
```

**3.2 Install Tailscale on Android**
- Download Tailscale from Play Store
- Sign in with same account as laptop
- Both devices now on same private network

### Phase 4: Create Helper Scripts

**4.1 Laptop: Session host script** (`~/dotfiles/scripts/remote-session.sh`):
```bash
#!/bin/bash
# Creates or attaches to a shared tmux session
SESSION_NAME="remote"
tmux has-session -t $SESSION_NAME 2>/dev/null || tmux new-session -d -s $SESSION_NAME
tmux attach -t $SESSION_NAME
```

**4.2 Phone: Connection script** (run in Termux):
```bash
#!/bin/bash
# Connect to laptop via mosh, attach to shared tmux session
LAPTOP_HOST="laptop.tailnet-name.ts.net"  # Your Tailscale hostname
mosh $LAPTOP_HOST -- tmux attach -t remote
```

### Phase 5: Usage Workflow

**On Laptop:**
1. Start a tmux session: `tmux new -s remote`
2. Work normally - session is now shareable

**On Phone:**
1. Open Termux
2. Connect: `mosh laptop.tailnet-name.ts.net`
3. Attach to session: `tmux attach -t remote`

**Both devices now show the same terminal!**
- Type on phone → appears on laptop
- Output visible on both screens
- Network drops? Mosh auto-reconnects
- Close Termux? Session persists, reconnect anytime

## Files to Modify

| File | Changes |
|------|---------|
| `~/dotfiles/homebrew/Brewfile` | Add mosh and tailscale |
| `~/dotfiles/scripts/setup.sh` | Add full automation for SSH, Tailscale, firewall |
| `~/dotfiles/.config/fish/config.fish` | Add remote session aliases/functions |
| `~/dotfiles/scripts/remote-session.sh` | New helper script for session management |

## Fish Shell Functions

Add to `~/.config/fish/config.fish`:

```fish
# Remote Session Management
function remote-start --description "Start a shared tmux session for remote access"
    set -l session_name "remote"
    if tmux has-session -t $session_name 2>/dev/null
        echo "Session '$session_name' already exists. Attaching..."
        tmux attach -t $session_name
    else
        echo "Creating new session '$session_name'..."
        tmux new-session -s $session_name
    end
end

function remote-status --description "Show Tailscale and remote session status"
    echo "=== Tailscale Status ==="
    tailscale status
    echo ""
    echo "=== tmux Sessions ==="
    tmux ls 2>/dev/null || echo "No tmux sessions running"
end

# Alias for quick access
alias remote "remote-start"
```

## Setup Script Additions

Add to `~/dotfiles/scripts/setup.sh`:

```bash
# ============================================
# Phase X: Remote Access Setup (Mosh + Tailscale)
# ============================================

echo "Setting up remote access tools..."

# Check and enable SSH (Remote Login)
if ! systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
    echo "Enabling Remote Login (SSH)..."
    sudo systemsetup -setremotelogin on
else
    echo "✓ Remote Login already enabled"
fi

# Configure Tailscale
if command -v tailscale &>/dev/null; then
    echo "Tailscale installed. Checking status..."
    if ! tailscale status &>/dev/null; then
        echo "Opening Tailscale for authentication..."
        open -a Tailscale
        echo "Please complete Tailscale authentication in the app."
        echo "Once authenticated, your Tailscale hostname will be shown with: tailscale status"
    else
        echo "✓ Tailscale is connected"
        tailscale status | head -5
    fi
else
    echo "Tailscale not found. Run: brew install --cask tailscale"
fi

# Configure firewall for Mosh (UDP 60000-61000)
echo "Configuring firewall for Mosh..."
if command -v mosh-server &>/dev/null; then
    # Add mosh-server to firewall exceptions
    MOSH_PATH=$(which mosh-server)
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$MOSH_PATH" 2>/dev/null
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$MOSH_PATH" 2>/dev/null
    echo "✓ Mosh firewall rules configured"
fi

echo ""
echo "=== Remote Access Setup Complete ==="
echo "Next steps:"
echo "1. Create Tailscale account at https://tailscale.com"
echo "2. Install Tailscale on your phone"
echo "3. Install Termux on Android: pkg install mosh tmux"
echo "4. Connect: mosh $(tailscale status --self --json 2>/dev/null | jq -r '.DNSName' | sed 's/\.$//' || echo 'YOUR_TAILSCALE_HOSTNAME')"
```

## Security Model

### Why This Setup is Safe

| Layer | Protection |
|-------|------------|
| **Tailscale** | WireGuard encryption, devices only visible to YOUR account |
| **No public exposure** | SSH is NOT exposed to internet, only to Tailscale network |
| **Authentication** | SSH key-based auth (no passwords) |
| **Identity** | Tailscale requires your identity provider (Google/GitHub/etc) |

### Attack Surface Analysis

- **Public internet**: Cannot reach your laptop (Tailscale is a private mesh)
- **Local network**: Can see SSH port, but need your SSH key to connect
- **Tailscale network**: Only your authenticated devices can connect

### What an Attacker Would Need

1. Compromise your Tailscale account (protected by your identity provider's 2FA)
2. AND have your SSH private key
3. AND know your laptop's Tailscale hostname

This is significantly more secure than exposing SSH to the public internet.

## Verification Steps

1. `tailscale status` - confirm both devices connected
2. `ping laptop.tailnet-name.ts.net` from phone - confirm connectivity
3. `mosh laptop.tailnet-name.ts.net` - test mosh connection
4. `tmux ls` - verify session exists on laptop
5. Attach from both devices simultaneously - confirm mirroring works

## Termux Setup (Phone Side)

**One-time setup in Termux:**
```bash
# Update packages
pkg update && pkg upgrade -y

# Install required tools
pkg install mosh tmux openssh -y

# Optional: Set up SSH key for passwordless auth
ssh-keygen -t ed25519 -C "termux-phone"
# Copy public key to laptop:
cat ~/.ssh/id_ed25519.pub
# Add to laptop's ~/.ssh/authorized_keys
```

**Install Tailscale on Android:**
1. Download from Play Store: "Tailscale"
2. Sign in with same account as laptop
3. Both devices now on same private network

**Quick connect from Termux:**
```bash
# Replace with your Tailscale hostname
mosh your-laptop.tailnet-name.ts.net -- tmux attach -t remote
```

## Quick Start Summary

**After implementation, your workflow will be:**

| Step | Laptop | Phone |
|------|--------|-------|
| 1 | `remote` (starts tmux session) | - |
| 2 | - | `mosh laptop -- tmux attach -t remote` |
| 3 | Both screens show same terminal | Type on either device |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" | Check SSH is enabled: `sudo systemsetup -getremotelogin` |
| "mosh-server not found" | Install mosh on laptop: `brew install mosh` |
| Tailscale not connecting | Check both devices on same Tailscale account |
| tmux session not found | Create first: `tmux new -s remote` |
| Firewall blocking mosh | Run firewall config commands from setup script |

## tmux Control from Phone

You have **full tmux control** from your phone. Your prefix is `Ctrl-s`:

### Pane Operations
| Action | Keys |
|--------|------|
| Split horizontal | `Ctrl-s "` |
| Split vertical | `Ctrl-s %` |
| Resize pane | `Ctrl-s H/J/K/L` |
| Navigate panes | `Ctrl-s h/j/k/l` |
| Close pane | `Ctrl-s x` |
| Zoom pane (fullscreen) | `Ctrl-s z` |

### Window Operations
| Action | Keys |
|--------|------|
| New window | `Ctrl-s c` |
| Next/prev window | `Ctrl-s n/p` |
| Rename window | `Ctrl-s ,` |

### Session Operations
| Action | Keys |
|--------|------|
| Detach | `Ctrl-s d` |
| List sessions | `Ctrl-s s` |

### Phone Keyboard Tips
- Termux shows Ctrl/Alt in an extra row at top of keyboard
- Consider installing "Hacker's Keyboard" for better modifier key support

## Screen Size Handling

When both devices attach, tmux uses the **smallest** client's dimensions by default.

**Options:**

1. **Accept phone size** - Laptop shrinks to match phone (true mirroring)

2. **Independent sizes** - Add to `.tmux.conf`:
   ```
   setw -g aggressive-resize on
   ```

3. **Phone read-only** - Doesn't affect laptop size:
   ```bash
   tmux attach -t remote -r
   ```

## What is Mosh? (Reference)

Mosh (Mobile Shell) is an SSH replacement for unreliable networks:

| Feature | SSH | Mosh |
|---------|-----|------|
| Network change (WiFi→cellular) | Disconnects | Continues |
| Phone sleep/wake | Often dies | Reconnects instantly |
| High latency | Feels sluggish | Local echo (fast) |
| Protocol | TCP | UDP |

Mosh uses "local echo" - keystrokes appear immediately before server confirms, making it feel instant even on slow connections.

## Optional Enhancements

- **Auto-start session**: Add `tmux new -d -s remote` to login items
- **Notification on connect**: Add webhook to notify when phone connects
- **Read-only mode**: `tmux attach -t remote -r` for view-only from second device

## Implementation Checklist

When you're ready to implement, follow these steps in order:

- [ ] Create Tailscale account at https://tailscale.com
- [ ] Add `mosh` and `tailscale` to Brewfile
- [ ] Run `brew bundle` to install
- [ ] Open Tailscale app, authenticate
- [ ] Enable Remote Login (SSH) in System Settings
- [ ] Add Fish functions to config.fish
- [ ] Add setup script automation to setup.sh
- [ ] Note your Tailscale hostname: `tailscale status`
- [ ] Install Termux on Android phone
- [ ] Install Tailscale app on phone, sign in
- [ ] In Termux: `pkg install mosh tmux openssh`
- [ ] Generate SSH key in Termux, add to laptop's authorized_keys
- [ ] Test: `mosh YOUR_HOSTNAME -- tmux new -s remote`
- [ ] From laptop: `tmux attach -t remote` (both now mirrored!)
