# Granted Configuration Guide

This directory contains configuration for [Granted](https://granted.dev) - an AWS credential management tool with autocomplete, browser integration, and profile colors/icons.

## What You Should See (UI Changes)

### 1. Terminal Autocomplete ✅
When you type `assume` followed by space and Tab:
```bash
assume <TAB>
```
**Expected:** Shows your AWS profile names from `~/.aws/config`
**Not:** Granted command options or file names

### 2. Firefox Browser Integration 🔥
When you run `assume production` and open AWS console:
- **Firefox opens** (not Chrome/Safari)
- **Colored container tabs** with icons (requires Firefox addon):
  - `production` → **Red briefcase** 🔴💼
  - `development` → **Green tree** 🟢🌳  
  - `staging` → **Yellow cart** 🟡🛒
  - `security` → **Purple fingerprint** 🟣👆

### 3. Profile Ordering
Profiles appear in "frequently-used" order (most recent first)

## Setup Instructions

### Automatic Setup (Recommended)
The dotfiles setup script handles everything:
```bash
./scripts/setup.sh
```

### Manual Setup
1. **Install Granted:**
   ```bash
   brew install granted
   ```

2. **Create symlinks using stow:**
   ```bash
   cd ~/dotfiles
   stow . --adopt
   ```

3. **Install Firefox addon:**
   - Visit: https://addons.mozilla.org/en-US/firefox/addon/granted/
   - Click "Add to Firefox"
   - Enable the addon

4. **Reload Fish completions:**
   ```bash
   fish -c "source ~/.config/fish/completions/granted.fish"
   ```

## Configuration Files

### `config`
Main Granted configuration with:
- **Firefox** as default browser
- **Frequently-used** profile ordering  
- **Caching enabled** for performance
- **Telemetry disabled** for privacy

### `firefox-profiles`
Maps AWS profiles to Firefox colors and icons:
```
production=red:briefcase
development=green:tree
staging=yellow:cart
security=purple:fingerprint
```

## Available Colors & Icons

**Colors:** blue, turquoise, green, yellow, orange, red, pink, purple
**Icons:** fingerprint, briefcase, dollar, cart, circle, gift, vacation, food, fruit, pet, tree, chill

## Usage Examples

```bash
# Basic profile switching
assume production

# Open AWS console in Firefox with red briefcase container
assume production --console

# List available profiles
granted profiles list

# Configure profile colors
./scripts/granted-setup.sh set-profile-color myprofile blue tree

# Test configuration
./scripts/granted-setup.sh test-config
```

## Troubleshooting

### Autocomplete Shows Wrong Items
**Problem:** `assume <TAB>` shows files or Granted commands instead of AWS profiles
**Solution:**
```bash
# Reload Fish completions
fish -c "source ~/.config/fish/completions/granted.fish"
```

### No Colors/Icons in Firefox
**Problem:** Firefox tabs are plain, no colors or icons
**Solution:**
1. Install the Granted Firefox addon: https://addons.mozilla.org/en-US/firefox/addon/granted/
2. Ensure Firefox is set as default browser: `granted browser set firefox`
3. Check profile mappings in `~/.granted/firefox-profiles`

### Wrong Browser Opens
**Problem:** Chrome or Safari opens instead of Firefox
**Solution:**
```bash
granted browser set firefox
```

### Profile Not Found
**Problem:** "Profile not found" errors
**Solution:**
1. Check AWS configuration: `aws configure list-profiles`
2. Verify AWS config file exists: `ls ~/.aws/config`
3. Ensure profile names match exactly

## Helper Scripts

Use `./scripts/granted-setup.sh` for management:
- `setup` - Initial configuration
- `set-profile-color PROFILE COLOR ICON` - Configure colors/icons
- `list-profiles` - Show configured profiles
- `test-config` - Validate setup
- `list-colors` - Show available options

## Links

- **Documentation:** https://docs.commonfate.io/granted/
- **Firefox Addon:** https://addons.mozilla.org/en-US/firefox/addon/granted/
- **GitHub:** https://github.com/common-fate/granted
