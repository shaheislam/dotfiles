# Home Manager Multi-Device Configuration

Device-agnostic Home Manager configuration that works across multiple machines and user accounts.

## Features

✅ **Fully automatic for setup scripts** - detects current user dynamically
✅ **Auto-detects system architecture** (Apple Silicon, Intel Mac, Linux ARM, Linux x86)
✅ **Two modes**: Dynamic (for automation) and Explicit (for reproducibility)
✅ **Works on multiple devices** without modification
✅ **Easy to add new users** - single line per device/username
✅ **Backwards compatible** with explicit username selection

## Quick Start

### Automated Setup (Recommended for Setup Scripts)

**Perfect for setup scripts** that need to work on ANY device with ANY username:

```bash
# Automatically detects current user from $USER environment variable
# Use full path - works from any directory
home-manager switch --flake ~/.config/home-manager#default --impure

# Or change directory first
cd ~/.config/home-manager
home-manager switch --flake .#default --impure
```

The `--impure` flag allows Nix to read environment variables, enabling automatic user detection.

### Manual Setup (Reproducible)

For explicit, reproducible configuration that doesn't depend on environment:

1. **Add your username** to `flake.nix` if not already present:

```nix
homeConfigurations = {
  "your-username" = mkHomeConfig {
    username = "your-username";
  };
};
```

2. **Install configuration**:

```bash
home-manager switch --flake ~/.config/home-manager#your-username
```

3. **Done!** Your environment is now configured.

### Adding a New Device

**Option 1: Automatic (No Configuration Needed)**

Just run the setup script or use the dynamic default:

```bash
home-manager switch --flake ~/.config/home-manager#default --impure
```

Works immediately on any device with any username!

**Option 2: Explicit Configuration (Optional)**

If you want a named, reproducible configuration:

1. Edit `flake.nix` and add your new device's username:

```nix
"work-laptop" = mkHomeConfig {
  username = "work-user";
};
```

2. Run on the new device:

```bash
home-manager switch --flake ~/.config/home-manager#work-laptop
```

## Two Modes Explained

### Dynamic Mode (--impure)

**When to use:** Setup scripts, automated deployments, testing on multiple accounts

**Pros:**
- ✅ Works on ANY device/user without modification
- ✅ No configuration needed
- ✅ Perfect for setup scripts
- ✅ Automatically detects current user

**Cons:**
- ⚠️ Requires `--impure` flag (breaks pure evaluation)
- ⚠️ Less reproducible (depends on environment)

**Usage:**
```bash
home-manager switch --flake .#default --impure
```

### Explicit Mode (Pure)

**When to use:** Personal devices, production systems, reproducible configurations

**Pros:**
- ✅ Fully reproducible
- ✅ Pure evaluation (Nix best practice)
- ✅ Named configurations for different contexts
- ✅ Version controlled and explicit

**Cons:**
- ⚠️ Requires adding username to flake.nix
- ⚠️ One entry per device/user

**Usage:**
```bash
home-manager switch --flake .#your-username
```

## Usage Examples

### Setup Script (Automatic)

```bash
# Works on any device, any user, any architecture
home-manager switch --flake ~/.config/home-manager#default --impure
```

### macOS (Manual/Explicit)

```bash
# Explicit configuration (pure evaluation)
home-manager switch --flake ~/.config/home-manager#shaheislam
```

### Linux (Dynamic Mode)

```bash
# Automatic detection - works on any Linux user
home-manager switch --flake ~/.config/home-manager#default --impure

# Note: For Linux, you may need to override homeDirectory in flake.nix
# The default assumes macOS paths (/Users/), so for Linux users:
default = mkHomeConfig {
  username = detectedUser;
  homeDirectory = if builtins.pathExists "/Users"
    then "/Users/${detectedUser}"   # macOS
    else "/home/${detectedUser}";   # Linux
};
```

### Multiple Devices

```nix
homeConfigurations = {
  # Personal MacBook (Apple Silicon)
  "shahe" = mkHomeConfig {
    username = "shahe";
  };

  # Work MacBook (Intel)
  "shaheislam" = mkHomeConfig {
    username = "shaheislam";
  };

  # Work Linux Desktop
  "work-linux" = mkHomeConfig {
    username = "work-user";
    homeDirectory = "/home/work-user";
  };
};
```

## How It Works

### Architecture Detection

The flake automatically detects:
- **aarch64-darwin** (Apple Silicon Mac)
- **x86_64-darwin** (Intel Mac)
- **aarch64-linux** (Linux on ARM)
- **x86_64-linux** (Linux on x86)

### Username Detection

**Two approaches available:**

#### 1. Dynamic Detection (Impure Mode)
Uses `builtins.getEnv "USER"` to read the current username from environment variables.

```nix
dynamicUser = builtins.getEnv "USER";
default = mkHomeConfig {
  username = dynamicUser;  # Automatically uses current user
};
```

**Requires:** `--impure` flag when activating
**Best for:** Setup scripts, automation, testing

#### 2. Explicit Configuration (Pure Mode)
Manually list each username in the flake.

```nix
"shaheislam" = mkHomeConfig {
  username = "shaheislam";  # Explicitly defined
};
```

**Requires:** No special flags
**Best for:** Production, personal devices, reproducibility

### Simplified Function

```nix
mkHomeConfig = { username, homeDirectory ? "/Users/${username}", system ? currentSystem }
```

- `username`: Your username (required)
- `homeDirectory`: Automatically derived from username (override for Linux)
- `system`: Automatically detected architecture

## Testing Your Configuration

### Verify Dynamic Detection Works

```bash
# From any directory, test username detection
nix eval ~/.config/home-manager#homeConfigurations.default.config.home.username --impure

# Test home directory detection
nix eval ~/.config/home-manager#homeConfigurations.default.config.home.homeDirectory --impure

# Or from the config directory
cd ~/.config/home-manager
nix eval .#homeConfigurations.default.config.home.username --impure
```

Expected output:
- Username: `"your-current-username"`
- Home directory: `"/Users/your-current-username"` (macOS) or `"/home/your-current-username"` (Linux)

### Check Available Configurations

```bash
nix eval ~/.config/home-manager#homeConfigurations --apply builtins.attrNames
```

Should show: `["default" "shahe" "shaheislam"]` (plus any you've added)

## Which Mode Should I Use?

### Use Dynamic Mode (--impure) If:
- ✅ Running a setup script that needs to work on multiple devices
- ✅ Testing on different user accounts
- ✅ Automating deployments
- ✅ You want zero-configuration on new devices
- ✅ You don't care about pure reproducibility for this use case

### Use Explicit Mode (Pure) If:
- ✅ Setting up your personal device (one-time configuration)
- ✅ You want fully reproducible builds
- ✅ Following Nix best practices
- ✅ Managing named configurations for different contexts
- ✅ You prefer explicit over implicit configuration

### Hybrid Approach (Recommended)

**For most users:**
1. Use **dynamic mode** for initial setup script automation
2. Optionally add **explicit configuration** for your personal devices
3. Keep both options available in your flake

```bash
# Setup script (automated)
home-manager switch --flake .#default --impure

# Personal use (reproducible)
home-manager switch --flake .#shaheislam
```

## Troubleshooting

### "attribute 'USER' missing" or Empty Username

**Problem:** When using `#default`, username is empty or Nix can't find it.

**Solution:** You forgot the `--impure` flag:
```bash
# Wrong
home-manager switch --flake .#default

# Correct
home-manager switch --flake .#default --impure
```

The `--impure` flag is required for dynamic username detection.

### "do not know how to build this flake output"

**Problem:** Configuration name doesn't exist.

**Solution:** Check available configurations:
```bash
nix eval ~/.config/home-manager#homeConfigurations --apply builtins.attrNames
```

Then use one that exists, or add your username to `flake.nix`.

### "attribute 'username' missing"

Make sure you added your username to the `homeConfigurations` in `flake.nix`.

### Wrong architecture detected

The system architecture is detected automatically. If you need to override it:

```nix
"special-case" = mkHomeConfig {
  username = "user";
  system = "x86_64-darwin";  # Force Intel Mac
};
```

### Linux vs macOS paths

Linux uses `/home/username`, macOS uses `/Users/username`. Override if needed:

```nix
"linux-user" = mkHomeConfig {
  username = "myuser";
  homeDirectory = "/home/myuser";
};
```

## Maintenance

### Update Flake Inputs

```bash
cd ~/.config/home-manager
nix flake update
home-manager switch --flake .#your-username
```

### Check Configuration

```bash
cd ~/.config/home-manager
nix flake check
```

## Migration from Old Setup

If you had hardcoded system/username values before:

1. System architecture is now auto-detected via `builtins.currentSystem`
2. Usernames are explicitly listed in `homeConfigurations`
3. No code changes needed - just add your username if missing
4. Home directory is auto-derived (override for Linux if needed)

## Philosophy

This setup prioritizes:
1. **Reliability** over magic auto-detection
2. **Explicitness** over implicit configuration
3. **Simplicity** over complexity
4. **Portability** across devices and architectures

Adding a one-line entry per device/user is a small price for reliable, portable configuration.
