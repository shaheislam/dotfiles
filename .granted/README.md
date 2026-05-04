# Granted Configuration Guide

This directory contains configuration for [Granted](https://granted.dev), an AWS credential management tool with autocomplete, browser integration, and Firefox container colors/icons.

## What You Should See

### Terminal Autocomplete

When you type `assume` followed by space and Tab:

```bash
assume <TAB>
```

Expected: AWS profile names from `~/.aws/config`.

Not expected: Granted command options or local file names.

### Firefox Browser Integration

When you open an AWS console through Granted:

- Firefox opens instead of Chrome or Safari.
- Granted opens the console in a Firefox container tab.
- Container colors/icons come from `.granted/firefox-profiles`.

Examples:

```text
production=red:briefcase
development=green:tree
staging=yellow:cart
security=purple:fingerprint
```

## Setup

### Automatic Setup

The dotfiles setup script handles the reproducible pieces:

```bash
./scripts/setup.sh
```

Setup does the following:

- Installs Firefox from `homebrew/Brewfile` and `phase_9_fonts_and_apps`.
- Uses stow to sync `.granted/config` and `.granted/firefox-profiles` into `~/.granted`.
- Applies `scripts/setup/firefox/policies.json` to the Firefox app bundle when writable.
- Installs `scripts/setup/firefox/user.js` into the default local Firefox profile only.
- Installs `scripts/setup/firefox/chrome/userChrome.css` into the default local profile to hide native horizontal tabs, compact the sidebar header, and apply a small minimal theme layer when using Sidebery.
- Installs `scripts/setup/firefox/chrome/userContent.css` into the default local profile to keep blank/internal pages dark.

The `user.js` syncs selected `about:config` preferences without taking ownership of cookies, history, sessions, logins, cache, or the full Firefox profile.

To refresh `user.js` from the current Firefox default profile:

```bash
~/dotfiles/scripts/setup/firefox-setup.sh --capture-current-prefs
```

The capture helper reads `prefs.js`, keeps a conservative allowlist of portable preferences, and excludes profile/session/device-specific values such as local paths, Sync account state, telemetry IDs, cache state, downloads, and extension runtime UUIDs.

### Manual Fallback

If automatic Firefox policy installation is skipped because the app bundle is not writable:

```bash
sudo mkdir -p "/Applications/Firefox.app/Contents/Resources/distribution"
sudo cp ~/dotfiles/scripts/setup/firefox/policies.json "/Applications/Firefox.app/Contents/Resources/distribution/policies.json"
```

If Firefox has not created a profile yet, launch Firefox once and then rerun:

```bash
~/dotfiles/scripts/setup/firefox-setup.sh
```

If the Granted extension is still missing, install it from AMO:

```text
https://addons.mozilla.org/en-US/firefox/addon/granted/
```

Check active Firefox enterprise policies at `about:policies`.

## Configuration Files

### `.granted/config`

Main Granted configuration:

- Sets Firefox as the default Granted browser.
- Points Granted at `/Applications/Firefox.app/Contents/MacOS/firefox`.
- Uses the macOS keychain backend.

### `.granted/firefox-profiles`

Maps AWS profile names to Firefox container colors and icons:

```text
production=red:briefcase
prod=red:briefcase
development=green:tree
dev=green:tree
management=blue:briefcase
security=purple:fingerprint
```

### `scripts/setup/firefox/policies.json`

Machine-level Firefox enterprise policies:

- Force-installs the Granted Firefox extension.
- Disables Firefox studies, telemetry, Pocket, default-browser prompts, and first-run/post-update pages.

### `scripts/setup/firefox/user.js`

Default-profile `about:config` preferences:

- Enables Firefox containers and the container UI.
- Mirrors lightweight telemetry/new-tab defaults.
- Includes a generated block of safe preferences captured from the current local Firefox default profile.
- Does not manage profile databases such as `cookies.sqlite`, `places.sqlite`, `logins.json`, `key4.db`, or session restore files.

### `scripts/setup/firefox/chrome/userChrome.css`

Default-profile Firefox chrome CSS:

- Hides Firefox's native horizontal tab strip so Sidebery is the only tab UI.
- Compacts the native Firefox sidebar header while keeping it visible.
- Adds a small Tokyo Night-inspired URL bar and panel surface treatment.
- Keeps macOS/window-control support from the upstream Firefox CSS hack.
- Requires `toolkit.legacyUserProfileCustomizations.stylesheets=true`, which is set in `user.js`.
- Requires a full Firefox restart after installation.

### `scripts/setup/firefox/chrome/userContent.css`

Default-profile Firefox content CSS:

- Keeps `about:blank`, `about:home`, and `about:newtab` dark to avoid white flashes.
- Does not style normal websites.
- Requires a full Firefox restart after installation.

## Available Colors And Icons

Colors: blue, turquoise, green, yellow, orange, red, pink, purple.

Icons: fingerprint, briefcase, dollar, cart, circle, gift, vacation, food, fruit, pet, tree, chill.

## Usage Examples

```bash
# Basic profile switching
assume production

# Open AWS console in Firefox with the configured container
assume -c production

# List available profiles
granted profiles list

# Configure profile colors in the local Granted config
~/dotfiles/scripts/setup/granted-setup.sh set-profile-color myprofile blue tree

# Test local Granted configuration
~/dotfiles/scripts/setup/granted-setup.sh test-config
```

## Troubleshooting

### Autocomplete Shows Wrong Items

Problem: `assume <TAB>` shows files or Granted commands instead of AWS profiles.

Solution:

```bash
fish -c "source ~/.config/fish/completions/granted.fish"
```

### No Colors Or Icons In Firefox

Problem: Firefox tabs are plain, with no Granted colors or icons.

Solution:

1. Check `about:policies` for the Granted extension policy.
2. Confirm the Granted Firefox addon is installed: `about:addons`.
3. Ensure Firefox is set as Granted's browser: `granted browser set firefox`.
4. Check profile mappings in `~/.granted/firefox-profiles`.

### About:Config Settings Did Not Apply

Problem: Firefox preferences from dotfiles are missing.

Solution:

1. Quit Firefox completely.
2. Run `~/dotfiles/scripts/setup/firefox-setup.sh`.
3. Reopen Firefox.
4. Check that the default profile has `user.js` under `~/Library/Application Support/Firefox/Profiles/<profile>/user.js`.

### Native Top Tabs Still Show With Sidebery

Problem: Sidebery is open, but Firefox still shows the native horizontal tab bar at the top.

Solution:

1. Quit Firefox completely.
2. Run `~/dotfiles/scripts/setup/firefox-setup.sh`.
3. Reopen Firefox.
4. Check that the default profile has `chrome/userChrome.css` under `~/Library/Application Support/Firefox/Profiles/<profile>/chrome/userChrome.css`.
5. Confirm `toolkit.legacyUserProfileCustomizations.stylesheets` is `true` in `about:config`.

### Minimal Theme Changes Did Not Apply

Problem: URL bar/panels still look stock, the sidebar header is not compact, or blank pages still flash white.

Solution:

1. Quit Firefox completely.
2. Run `~/dotfiles/scripts/setup/firefox-setup.sh`.
3. Reopen Firefox.
4. Check that the default profile has both `chrome/userChrome.css` and `chrome/userContent.css`.
5. Confirm `layout.css.backdrop-filter.enabled` and `svg.context-properties.content.enabled` are `true` in `about:config`.

### Wrong Browser Opens

Problem: Chrome or Safari opens instead of Firefox.

Solution:

```bash
granted browser set firefox
```

### Profile Not Found

Problem: Granted reports profile-not-found errors.

Solution:

1. Check AWS configuration: `aws configure list-profiles`.
2. Verify AWS config exists: `ls ~/.aws/config`.
3. Ensure profile names match `.granted/firefox-profiles` exactly.

## Helper Scripts

Use `~/dotfiles/scripts/setup/granted-setup.sh` for Granted config management:

- `setup` installs local Granted config files by copying them from dotfiles.
- `set-profile-color PROFILE COLOR ICON` configures colors/icons.
- `list-profiles` shows configured Firefox profile mappings.
- `test-config` validates local Granted setup.
- `list-colors` shows available options.

Use `~/dotfiles/scripts/setup/firefox-setup.sh` for Firefox policy, `user.js`, Sidebery `userChrome.css`, and minimal `userContent.css` setup. Use `~/dotfiles/scripts/setup/firefox-setup.sh --capture-current-prefs` to refresh the dotfiles-managed `user.js` from the current Firefox default profile.

## Links

- Documentation: https://docs.commonfate.io/granted/
- Firefox Addon: https://addons.mozilla.org/en-US/firefox/addon/granted/
- GitHub: https://github.com/common-fate/granted
